use crate::ewts::{convert, ewts_to_unicode_with, Diagnostic, Options};

mod session;
pub use session::Session;

/// Incremental input state for an IME front end.
///
/// The front end feeds keystrokes with [`Engine::push`], shows
/// [`Engine::preedit`] as the composition string, and takes the text with
/// [`Engine::commit`].
#[derive(Debug, Default, Clone)]
pub struct Engine {
    raw: String,
    options: Options,
}

impl Engine {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn with_options(options: Options) -> Self {
        Self {
            raw: String::new(),
            options,
        }
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
        ewts_to_unicode_with(&self.raw, self.options)
    }

    /// Diagnostics for the raw buffer. Spans are UTF-8 byte offsets into
    /// [`Engine::raw`].
    pub fn diagnostics(&self) -> Vec<Diagnostic> {
        convert(&self.raw, self.options).diagnostics
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

    #[test]
    fn backspace_on_empty_engine_is_a_no_op() {
        let mut e = Engine::new();
        assert!(!e.backspace());
        assert_eq!(e.preedit(), "");
        assert_eq!(e.commit(), "");
    }

    #[test]
    fn cancel_discards_input() {
        let mut e = Engine::new();
        e.push('k');
        e.cancel();
        assert!(e.is_empty());
        assert_eq!(e.commit(), "");
    }

    #[test]
    fn options_apply_to_preedit() {
        let mut e = Engine::with_options(Options { precomposed: true });
        for c in "gha".chars() {
            e.push(c);
        }
        assert_eq!(e.preedit(), "\u{0F43}");
        assert_eq!(Engine::new().preedit(), "");
    }

    #[test]
    fn engine_is_reusable_after_commit() {
        let mut e = Engine::new();
        e.push('k');
        assert_eq!(e.commit(), "ཀ");
        e.push('g');
        assert_eq!(e.commit(), "ག");
    }
}
