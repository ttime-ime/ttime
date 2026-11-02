use crate::ewts::ewts_to_unicode;

/// Incremental input state for an IME front end.
///
/// The front end feeds keystrokes with [`Engine::push`], shows
/// [`Engine::preedit`] as the composition string, and takes the text with
/// [`Engine::commit`].
#[derive(Debug, Default, Clone)]
pub struct Engine {
    raw: String,
}

impl Engine {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn push(&mut self, c: char) {
        self.raw.push(c);
    }

    /// Removes the last keystroke. Returns false if there was nothing to remove.
    pub fn backspace(&mut self) -> bool {
        self.raw.pop().is_some()
    }

    pub fn raw(&self) -> &str {
        &self.raw
    }

    pub fn is_empty(&self) -> bool {
        self.raw.is_empty()
    }

    pub fn preedit(&self) -> String {
        ewts_to_unicode(&self.raw)
    }

    pub fn commit(&mut self) -> String {
        let out = self.preedit();
        self.raw.clear();
        out
    }

    pub fn cancel(&mut self) {
        self.raw.clear();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn preedit_tracks_keystrokes() {
        let mut e = Engine::new();
        for c in "bod".chars() {
            e.push(c);
        }
        assert_eq!(e.preedit(), "བོད");
        assert!(e.backspace());
        assert_eq!(e.preedit(), "བོ");
        assert_eq!(e.commit(), "བོ");
        assert!(e.is_empty());
    }
}
