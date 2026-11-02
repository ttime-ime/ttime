use super::Engine;
use crate::ewts::{Diagnostic, Options};

/// A typing session: committed text plus one provisional run.
///
/// Commit policy: input is *provisional* until a space or newline is typed.
/// That keystroke converts the provisional text, appends it to the
/// *committed* text and starts a new provisional run. Committed text is never
/// rewritten. Backspace edits provisional text only; at an empty provisional
/// run it does nothing and the host's ordinary text editing takes over.
///
/// Every front end (browser, macOS) uses this type, so the policy cannot
/// differ between platforms.
#[derive(Debug, Clone)]
pub struct Session {
    committed: String,
    engine: Engine,
    precomposed: bool,
    diplomatic: bool,
    latin: bool,
}

impl Session {
    pub fn new(precomposed: bool) -> Self {
        Self::with_options(Options {
            precomposed,
            diplomatic: false,
        })
    }

    pub fn with_options(options: Options) -> Self {
        Self {
            committed: String::new(),
            engine: Engine::with_options(options),
            precomposed: options.precomposed,
            diplomatic: options.diplomatic,
            latin: false,
        }
    }

    /// Latin mode passes typed text through unchanged: no EWTS is read, and a
    /// space is a space. Switching to it first fixes the provisional run, so no
    /// typed text is lost or rewritten; switching back starts a fresh run.
    pub fn set_latin(&mut self, on: bool) {
        if on == self.latin {
            return;
        }
        let out = self.engine.commit();
        self.committed.push_str(&out);
        self.latin = on;
    }

    pub fn latin(&self) -> bool {
        self.latin
    }

    pub fn diplomatic(&self) -> bool {
        self.diplomatic
    }

    /// Feeds typed characters one at a time, committing at spaces and newlines.
    /// In Latin mode the text is appended as it is.
    pub fn insert_text(&mut self, text: &str) {
        if self.latin {
            self.committed.push_str(text);
            return;
        }
        for c in text.chars() {
            self.engine.push(c);
            if (c == ' ' || c == '\n') && !self.holds_open_construct() {
                let out = self.engine.commit();
                self.committed.push_str(&out);
            }
        }
    }

    /// A space inside `[literal text]` or right after a backslash belongs to
    /// that construct, so it must not end the provisional run.
    fn holds_open_construct(&self) -> bool {
        let raw = self.engine.raw();
        let body = &raw[..raw.len() - 1]; // without the space just pushed
        let mut depth = 0usize;
        let mut escaped = false;
        for c in body.chars() {
            if escaped {
                escaped = false;
            } else if c == '\\' {
                escaped = true;
            } else if c == '[' {
                depth += 1;
            } else if c == ']' {
                depth = depth.saturating_sub(1);
            }
        }
        depth > 0 || escaped
    }

    /// Removes the last provisional keystroke. Returns false, changing nothing,
    /// when there is no provisional text.
    pub fn backspace(&mut self) -> bool {
        !self.latin && self.engine.backspace()
    }

    /// Drops the provisional run, keeping committed text.
    pub fn cancel(&mut self) {
        self.engine.cancel();
    }

    /// Commits whatever is provisional and returns the whole text.
    pub fn finish(&mut self) -> String {
        let out = self.engine.commit();
        self.committed.push_str(&out);
        self.committed.clone()
    }

    /// Replaces the committed text (after the host edited it directly) and
    /// clears the provisional run.
    pub fn set_committed(&mut self, text: &str) {
        self.committed = text.to_string();
        self.engine.cancel();
    }

    pub fn reset(&mut self) {
        self.committed.clear();
        self.engine.cancel();
    }

    /// Returns the committed text and empties it, for hosts (such as an input
    /// method) that insert text into a document as it is committed instead of
    /// keeping the whole text.
    pub fn take_committed(&mut self) -> String {
        std::mem::take(&mut self.committed)
    }

    pub fn committed(&self) -> &str {
        &self.committed
    }

    pub fn provisional(&self) -> String {
        self.engine.preedit()
    }

    /// The EWTS typed since the last commit.
    pub fn raw(&self) -> &str {
        self.engine.raw()
    }

    /// Diagnostics for the provisional run only; spans are UTF-8 byte offsets
    /// into [`Session::raw`].
    pub fn diagnostics(&self) -> Vec<Diagnostic> {
        self.engine.diagnostics()
    }

    pub fn precomposed(&self) -> bool {
        self.precomposed
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::ewts_to_unicode_with;

    fn rng(seed: &mut u64) -> u64 {
        *seed ^= *seed << 13;
        *seed ^= *seed >> 7;
        *seed ^= *seed << 17;
        *seed
    }

    #[test]
    fn committing_at_spaces_equals_whole_string_conversion() {
        let alphabet: Vec<char> = "kgyrlsabdmn'+.~[]\\ _/MHiueo -0123uU\n".chars().collect();
        let mut seed = 0x9E3779B97F4A7C15u64;
        for round in 0..20_000 {
            let len = (rng(&mut seed) % 24) as usize;
            let text: String = (0..len)
                .map(|_| alphabet[(rng(&mut seed) % alphabet.len() as u64) as usize])
                .collect();
            for precomposed in [false, true] {
                let mut s = Session::new(precomposed);
                s.insert_text(&text);
                let want = ewts_to_unicode_with(&text, Options { precomposed, diplomatic: false });
                assert_eq!(s.finish(), want, "round {round}: {text:?}");
            }
        }
    }

    #[test]
    fn provisional_changes_but_committed_does_not() {
        let mut s = Session::new(false);
        s.insert_text("gya");
        assert_eq!(s.provisional(), "གྱ");
        assert_eq!(s.committed(), "");
        s.insert_text(" ");
        assert_eq!(s.committed(), "གྱ་");
        assert_eq!(s.provisional(), "");
    }

    #[test]
    fn space_inside_brackets_or_after_backslash_does_not_commit() {
        let mut s = Session::new(false);
        s.insert_text("[a b");
        assert_eq!(s.committed(), "");
        s.insert_text("] ");
        assert_ne!(s.committed(), "");
        let mut t = Session::new(false);
        t.insert_text("\\ ");
        assert_eq!(t.committed(), "");
    }

    #[test]
    fn take_committed_empties_it_and_keeps_provisional() {
        let mut s = Session::new(false);
        s.insert_text("ka kh");
        assert_eq!(s.take_committed(), "ཀ་");
        assert_eq!(s.committed(), "");
        assert_eq!(s.provisional(), "ཁ");
    }

    #[test]
    fn backspace_edits_only_provisional_text() {
        let mut s = Session::new(false);
        s.insert_text("ka ");
        assert!(!s.backspace());
        assert_eq!(s.committed(), "ཀ་");
        s.insert_text("kh");
        assert!(s.backspace());
        assert_eq!(s.provisional(), "ཀ");
    }

    #[test]
    fn latin_text_passes_through_unchanged() {
        let mut s = Session::new(false);
        s.set_latin(true);
        let text = "Bod skad [x] \\u0F40 kha+ya, oM; ka\n";
        s.insert_text(text);
        assert_eq!(s.committed(), text);
        assert_eq!(s.provisional(), "");
        assert_eq!(s.raw(), "");
    }

    #[test]
    fn switching_to_latin_fixes_the_pending_run_and_back_resumes() {
        let mut s = Session::new(false);
        s.insert_text("bkra shis");
        assert_eq!(s.provisional(), "ཤིས");
        s.set_latin(true);
        assert_eq!(s.committed(), "བཀྲ་ཤིས");
        assert_eq!(s.provisional(), "");
        s.insert_text(" (Tashi)");
        s.set_latin(false);
        s.insert_text(" bde");
        assert_eq!(s.committed(), "བཀྲ་ཤིས (Tashi)་");
        assert_eq!(s.provisional(), "བདེ");
        s.set_latin(true);
        assert_eq!(s.committed(), "བཀྲ་ཤིས (Tashi)་བདེ");
    }

    #[test]
    fn latin_mode_leaves_backspace_to_the_host() {
        let mut s = Session::new(false);
        s.set_latin(true);
        s.insert_text("ab");
        assert!(!s.backspace());
        assert_eq!(s.committed(), "ab");
    }

    /// Whatever mix of modes, Latin stretches come out exactly as typed and
    /// Tibetan stretches as the whole-string conversion would give them.
    #[test]
    fn mixed_modes_keep_each_stretch_intact() {
        let tibetan: Vec<char> = "kgyrlsabdmn'+.~[]\\ _/MHiueo -0123uU".chars().collect();
        let latin: Vec<char> = "abcXYZ kgy+.[]\\~'\n,;0123 ".chars().collect();
        let mut seed = 0xA24BAED4963EE407u64;
        for round in 0..5_000 {
            let mut s = Session::new(false);
            let mut want = String::new();
            let mut tib = String::new();
            for k in 0..(1 + rng(&mut seed) % 5) {
                let is_latin = k % 2 == 1;
                let pool = if is_latin { &latin } else { &tibetan };
                let part: String = (0..rng(&mut seed) % 10)
                    .map(|_| pool[(rng(&mut seed) % pool.len() as u64) as usize])
                    .collect();
                s.set_latin(is_latin);
                s.insert_text(&part);
                if is_latin {
                    want.push_str(&ewts_to_unicode_with(&tib, Options::default()));
                    tib.clear();
                    want.push_str(&part);
                } else {
                    tib.push_str(&part);
                }
            }
            s.set_latin(true);
            want.push_str(&ewts_to_unicode_with(&tib, Options::default()));
            assert_eq!(s.committed(), want, "round {round}");
        }
    }
}
