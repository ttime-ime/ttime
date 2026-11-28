//! Policy for the left Shift tap and the mode a field starts in: a single tap flips
//! Tibetan/Latin, and the mode is remembered when focus moves to another field or app;
//! a double tap locks the mode you were already in.

use super::shift_tap::ShiftTapKind;

/// Pure mode-lock state, shared across every client so controllers cannot disagree.
#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct ModeLock {
    /// `None`: unlocked. `Some(true)`: locked in Latin. `Some(false)`: locked in Tibetan.
    pub locked_latin: Option<bool>,
    /// The mode last chosen (by a tap or the toolbar), carried to the next field;
    /// `None` until the first choice.
    pub last_latin: Option<bool>,
    /// The mode before any choice (a setting): false is Tibetan.
    pub start_latin: bool,
}

impl ModeLock {
    /// Returns the Latin setting the composer should switch to, or `None` to leave
    /// it alone. `is_latin` is the composer's mode *now*, after any earlier tap.
    pub fn left_tap(&mut self, kind: ShiftTapKind, is_latin: bool) -> Option<bool> {
        let mode = self.tap_mode(kind, is_latin);
        if mode.is_some() {
            self.last_latin = mode;
        }
        mode
    }

    fn tap_mode(&mut self, kind: ShiftTapKind, is_latin: bool) -> Option<bool> {
        match kind {
            ShiftTapKind::Single => {
                if self.locked_latin.is_none() {
                    Some(!is_latin)
                } else {
                    None
                }
            }
            ShiftTapKind::Double => {
                if self.locked_latin.is_some() {
                    self.locked_latin = None;
                    None
                } else {
                    // The first tap of the pair already flipped the mode: flip it back
                    // and lock the mode the user was in.
                    let original = !is_latin;
                    self.locked_latin = Some(original);
                    Some(original)
                }
            }
        }
    }

    /// A click on a mode in the toolbar: always allowed. While locked, the lock
    /// follows the mode you chose.
    pub fn choose(&mut self, latin: bool) -> bool {
        if self.locked_latin.is_some() {
            self.locked_latin = Some(latin);
        }
        self.last_latin = Some(latin);
        latin
    }

    /// The toolbar's lock button: locks the current mode, or unlocks.
    pub fn toggle_lock(&mut self, is_latin: bool) {
        self.locked_latin = if self.locked_latin.is_none() {
            Some(is_latin)
        } else {
            None
        };
    }

    /// The mode a client starts in when it gains focus: the locked mode, else the
    /// mode last chosen, else the start mode.
    pub fn mode_on_focus(&self) -> bool {
        self.locked_latin
            .or(self.last_latin)
            .unwrap_or(self.start_latin)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn single_tap_flips_when_unlocked() {
        let mut m = ModeLock::default();
        assert_eq!(m.left_tap(ShiftTapKind::Single, false), Some(true));
        assert_eq!(m.left_tap(ShiftTapKind::Single, true), Some(false));
    }

    #[test]
    fn double_tap_locks_and_unlocks() {
        let mut m = ModeLock::default();
        // First tap flipped Tibetan to Latin; the second tap of the pair arrives.
        assert_eq!(m.left_tap(ShiftTapKind::Double, true), Some(false));
        assert_eq!(m.locked_latin, Some(false));
        assert_eq!(m.left_tap(ShiftTapKind::Single, false), None);
        assert!(!m.mode_on_focus());
        assert_eq!(m.left_tap(ShiftTapKind::Double, false), None);
        assert_eq!(m.locked_latin, None);
    }

    #[test]
    fn double_tap_from_latin_locks_latin() {
        let mut m = ModeLock::default();
        // Latin, then a pair: the first tap flipped Latin to Tibetan.
        assert_eq!(m.left_tap(ShiftTapKind::Double, false), Some(true));
        assert_eq!(m.locked_latin, Some(true));
        assert!(m.mode_on_focus(), "locked Latin survives focus");
    }

    #[test]
    fn the_mode_carries_over_to_the_next_field() {
        let mut m = ModeLock::default();
        assert!(!m.mode_on_focus(), "Tibetan before any choice");
        m.start_latin = true;
        assert!(
            m.mode_on_focus(),
            "the start setting applies until a choice"
        );
        assert_eq!(m.left_tap(ShiftTapKind::Single, true), Some(false));
        assert!(!m.mode_on_focus(), "a tap is remembered");
        m.choose(true);
        assert!(m.mode_on_focus(), "so is a toolbar click");
        // A double tap undoes its first tap and locks; unlocking keeps the last mode.
        assert_eq!(m.left_tap(ShiftTapKind::Single, true), Some(false));
        assert_eq!(m.left_tap(ShiftTapKind::Double, false), Some(true));
        assert_eq!(m.last_latin, Some(true));
        m.toggle_lock(true);
        assert!(m.mode_on_focus());
        // A lock wins over the last mode.
        m.locked_latin = Some(false);
        assert!(!m.mode_on_focus());
    }

    #[test]
    fn toolbar_choose_and_lock() {
        let mut m = ModeLock::default();
        assert!(m.choose(true));
        assert!(!m.choose(false));
        m.toggle_lock(true);
        assert_eq!(m.locked_latin, Some(true));
        assert!(!m.choose(false));
        assert_eq!(m.locked_latin, Some(false));
        assert_eq!(m.left_tap(ShiftTapKind::Single, false), None);
        m.toggle_lock(false);
        assert!(m.choose(true));
        assert_eq!(m.locked_latin, None);
        m.toggle_lock(true);
        m.toggle_lock(true);
        assert_eq!(m.locked_latin, None);
        assert!(!ModeLock::default().mode_on_focus());
    }
}
