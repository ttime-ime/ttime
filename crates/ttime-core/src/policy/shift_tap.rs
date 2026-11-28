//! Recognises a lone Shift tap: pressed and released with nothing else in between.
//!
//! Platform-neutral: the shell decodes OS events into [`ShiftSide`] press/release
//! calls with timing and chord flags. macOS key codes and modifier bits stay in the shell.

/// Which Shift key was tapped.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ShiftSide {
    Left,
    Right,
}

/// A tap is [`ShiftTapKind::Single`], or [`ShiftTapKind::Double`] when it is the
/// second of a pair. The first tap of a pair is reported at once as Single.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ShiftTapKind {
    Single,
    Double,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ShiftTapEvent {
    pub side: ShiftSide,
    pub kind: ShiftTapKind,
}

#[derive(Debug, Clone)]
struct Held {
    since: f64,
    spoiled: bool,
}

/// Pure state machine. Feed every Shift press/release and every other key press.
#[derive(Debug, Clone, Default)]
pub struct ShiftTap {
    left: Option<Held>,
    right: Option<Held>,
    last_left_tap: Option<f64>,
    last_right_tap: Option<f64>,
}

impl ShiftTap {
    /// A press held longer than this is not a tap.
    pub const MAX_TAP_DURATION: f64 = 0.35;
    /// Two taps of the same Shift this close together are a double tap.
    pub const DOUBLE_TAP_WINDOW: f64 = 0.5;

    /// A key (not a modifier) was pressed: any Shift held now is a chord, and
    /// no pending first tap can pair with a later one.
    pub fn key_down(&mut self) {
        if let Some(h) = &mut self.left {
            h.spoiled = true;
        }
        if let Some(h) = &mut self.right {
            h.spoiled = true;
        }
        self.last_left_tap = None;
        self.last_right_tap = None;
    }

    /// Forgets everything (activate/deactivate), so a missed release cannot leave a stale press.
    pub fn reset(&mut self) {
        self.left = None;
        self.right = None;
        self.last_left_tap = None;
        self.last_right_tap = None;
    }

    /// Shift pressed. `chord` is true when Control/Option/Command (or equivalent) is held.
    /// `other_held` is true when the other Shift is already down.
    pub fn press(&mut self, side: ShiftSide, time: f64, chord: bool, other_held: bool) {
        if other_held {
            self.key_down();
        }
        let held = Held {
            since: time,
            spoiled: chord || other_held,
        };
        match side {
            ShiftSide::Left => self.left = Some(held),
            ShiftSide::Right => self.right = Some(held),
        }
    }

    /// Shift released. Returns the tap when one just completed.
    pub fn release(&mut self, side: ShiftSide, time: f64, chord: bool) -> Option<ShiftTapEvent> {
        let held = match side {
            ShiftSide::Left => self.left.take(),
            ShiftSide::Right => self.right.take(),
        }?;
        let clean = !held.spoiled && !chord && time - held.since <= Self::MAX_TAP_DURATION;
        if !clean {
            match side {
                ShiftSide::Left => self.last_left_tap = None,
                ShiftSide::Right => self.last_right_tap = None,
            }
            return None;
        }
        let previous = match side {
            ShiftSide::Left => self.last_left_tap,
            ShiftSide::Right => self.last_right_tap,
        };
        if let Some(prev) = previous {
            if time - prev <= Self::DOUBLE_TAP_WINDOW {
                match side {
                    ShiftSide::Left => self.last_left_tap = None,
                    ShiftSide::Right => self.last_right_tap = None,
                }
                return Some(ShiftTapEvent {
                    side,
                    kind: ShiftTapKind::Double,
                });
            }
        }
        match side {
            ShiftSide::Left => self.last_left_tap = Some(time),
            ShiftSide::Right => self.last_right_tap = Some(time),
        }
        Some(ShiftTapEvent {
            side,
            kind: ShiftTapKind::Single,
        })
    }

    pub fn left_held(&self) -> bool {
        self.left.is_some()
    }

    pub fn right_held(&self) -> bool {
        self.right.is_some()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn tap(t: &mut ShiftTap, side: ShiftSide, at: f64, hold: f64) -> Option<ShiftTapEvent> {
        t.press(side, at, false, false);
        t.release(side, at + hold, false)
    }

    #[test]
    fn left_and_right_taps() {
        let mut t = ShiftTap::default();
        assert_eq!(
            tap(&mut t, ShiftSide::Left, 0.0, 0.1),
            Some(ShiftTapEvent {
                side: ShiftSide::Left,
                kind: ShiftTapKind::Single
            })
        );
        assert_eq!(
            tap(&mut t, ShiftSide::Right, 5.0, 0.1),
            Some(ShiftTapEvent {
                side: ShiftSide::Right,
                kind: ShiftTapKind::Single
            })
        );
    }

    #[test]
    fn chord_and_long_press_are_not_taps() {
        let mut t = ShiftTap::default();
        t.press(ShiftSide::Left, 0.0, false, false);
        t.key_down();
        assert!(t.release(ShiftSide::Left, 0.1, false).is_none());
        assert_eq!(
            tap(&mut t, ShiftSide::Left, 1.0, 0.1).map(|e| e.kind),
            Some(ShiftTapKind::Single)
        );

        let mut t = ShiftTap::default();
        t.press(ShiftSide::Left, 0.0, true, false);
        assert!(t.release(ShiftSide::Left, 0.1, false).is_none());

        let mut t = ShiftTap::default();
        assert!(tap(&mut t, ShiftSide::Left, 0.0, 0.6).is_none());
    }

    #[test]
    fn double_tap_pairing() {
        let mut t = ShiftTap::default();
        assert_eq!(
            tap(&mut t, ShiftSide::Left, 0.0, 0.1).map(|e| e.kind),
            Some(ShiftTapKind::Single)
        );
        assert_eq!(
            tap(&mut t, ShiftSide::Left, 0.3, 0.1).map(|e| e.kind),
            Some(ShiftTapKind::Double)
        );
        assert_eq!(
            tap(&mut t, ShiftSide::Left, 0.6, 0.1).map(|e| e.kind),
            Some(ShiftTapKind::Single)
        );

        let mut t = ShiftTap::default();
        let _ = tap(&mut t, ShiftSide::Left, 0.0, 0.1);
        assert_eq!(
            tap(&mut t, ShiftSide::Left, 0.9, 0.1).map(|e| e.kind),
            Some(ShiftTapKind::Single)
        );
    }

    #[test]
    fn pairing_is_per_side_and_broken_by_a_key() {
        let mut t = ShiftTap::default();
        let _ = tap(&mut t, ShiftSide::Right, 0.0, 0.1);
        assert_eq!(
            tap(&mut t, ShiftSide::Left, 0.2, 0.1).map(|e| e.kind),
            Some(ShiftTapKind::Single),
            "left does not pair with right"
        );
        assert_eq!(
            tap(&mut t, ShiftSide::Right, 0.4, 0.1).map(|e| e.kind),
            Some(ShiftTapKind::Double),
            "pairing is per side"
        );

        let mut t = ShiftTap::default();
        let _ = tap(&mut t, ShiftSide::Left, 0.0, 0.1);
        t.key_down();
        assert_eq!(
            tap(&mut t, ShiftSide::Left, 0.3, 0.1).map(|e| e.kind),
            Some(ShiftTapKind::Single),
            "a key between taps breaks the pair"
        );
    }

    #[test]
    fn chord_at_release_spoils() {
        let mut t = ShiftTap::default();
        t.press(ShiftSide::Left, 0.0, false, false);
        assert!(t.release(ShiftSide::Left, 0.1, true).is_none());
        assert!(
            t.release(ShiftSide::Left, 0.2, false).is_none(),
            "no stale press"
        );
    }

    #[test]
    fn both_shifts_spoil() {
        let mut t = ShiftTap::default();
        t.press(ShiftSide::Left, 0.0, false, false);
        t.press(ShiftSide::Right, 0.05, false, true);
        assert!(t.release(ShiftSide::Left, 0.1, false).is_none());
        assert!(t.release(ShiftSide::Right, 0.12, false).is_none());
    }

    #[test]
    fn reset_forgets_held() {
        let mut t = ShiftTap::default();
        t.press(ShiftSide::Left, 0.0, false, false);
        t.reset();
        assert!(t.release(ShiftSide::Left, 0.1, false).is_none());
    }
}
