//! Long-press accent palette for Latin mode: hold a letter and a strip offers
//! its IAST variants (hold `a` for `ā`).

/// The long-press accent palette state. Pure: the composer decides when to open
/// it; the panel draws it.
#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct AccentPalette {
    /// Variants of the open letter, in the order they are numbered.
    options: Vec<String>,
    /// The highlighted variant; `None` until an arrow key moves onto one, so a
    /// stray Return or Space never picks one by accident.
    selected: Option<usize>,
}

impl AccentPalette {
    /// Variants of each lowercase letter, in the order they are numbered. All are
    /// single precomposed (NFC) code points, so they behave as one letter when edited.
    pub fn lower_table() -> &'static [(&'static str, &'static [&'static str])] {
        &[
            ("a", &["ā"]),
            ("i", &["ī"]),
            ("u", &["ū"]),
            ("r", &["ṛ", "ṝ"]),
            ("l", &["ḷ", "ḹ"]),
            ("m", &["ṃ"]),
            ("h", &["ḥ"]),
            ("n", &["ṅ", "ñ", "ṇ"]),
            ("t", &["ṭ"]),
            ("d", &["ḍ"]),
            ("s", &["ś", "ṣ"]),
        ]
    }

    /// The variants of one typed letter (capitals give capitals); empty when it has none.
    pub fn variants_for(letter: &str) -> Vec<String> {
        let mut chars = letter.chars();
        let Some(c) = chars.next() else {
            return Vec::new();
        };
        if chars.next().is_some() {
            return Vec::new();
        }
        let lower: String = c.to_lowercase().collect();
        for &(k, vs) in Self::lower_table() {
            if k == lower {
                if c.is_uppercase() {
                    return vs
                        .iter()
                        .map(|v| v.chars().flat_map(|ch| ch.to_uppercase()).collect())
                        .collect();
                }
                return vs.iter().map(|s| (*s).to_string()).collect();
            }
        }
        Vec::new()
    }

    pub fn has_variants(letter: &str) -> bool {
        !Self::variants_for(letter).is_empty()
    }

    pub fn options(&self) -> &[String] {
        &self.options
    }

    pub fn selected(&self) -> Option<usize> {
        self.selected
    }

    pub fn is_open(&self) -> bool {
        !self.options.is_empty()
    }

    pub fn open(&mut self, letter: &str) {
        self.options = Self::variants_for(letter);
        self.selected = None;
    }

    pub fn close(&mut self) {
        self.options.clear();
        self.selected = None;
    }

    /// Moves the highlight; from nothing, forward starts at the first and back at the last.
    pub fn move_by(&mut self, delta: isize) {
        if !self.is_open() {
            return;
        }
        let n = self.options.len();
        self.selected = Some(match self.selected {
            Some(s) => (s as isize + delta).clamp(0, (n - 1) as isize) as usize,
            None if delta > 0 => 0,
            None => n - 1,
        });
    }

    /// Moves the highlight forward, from the last back to the first (Tab).
    pub fn cycle(&mut self) {
        if !self.is_open() {
            return;
        }
        let n = self.options.len();
        let next = match self.selected {
            Some(s) => (s + 1) % n,
            None => 0,
        };
        self.selected = Some(next);
    }

    /// The variant shown under a number key (1 is the first).
    pub fn option_number(&self, number: usize) -> Option<&str> {
        if number == 0 {
            return None;
        }
        self.options.get(number - 1).map(|s| s.as_str())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn capitals_give_capitals() {
        assert_eq!(AccentPalette::variants_for("S"), vec!["Ś", "Ṣ"]);
        assert!(AccentPalette::variants_for("k").is_empty());
        assert!(AccentPalette::variants_for("ab").is_empty());
    }

    #[test]
    fn variants_are_single_nfc_scalars() {
        for &(_, vs) in AccentPalette::lower_table() {
            for v in vs {
                let nfc: String = v.chars().collect();
                assert_eq!(nfc.chars().count(), 1, "{v}");
            }
        }
    }

    #[test]
    fn move_and_cycle() {
        let mut p = AccentPalette::default();
        p.open("n");
        assert_eq!(p.options().len(), 3);
        assert_eq!(p.selected(), None);
        p.move_by(1);
        assert_eq!(p.selected(), Some(0));
        p.cycle();
        assert_eq!(p.selected(), Some(1));
        p.cycle();
        p.cycle();
        assert_eq!(p.selected(), Some(0));
        assert_eq!(p.option_number(1), Some("ṅ"));
    }
}
