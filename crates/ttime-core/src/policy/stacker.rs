//! Stacker state and rules: chosen letters, typing, and the engine's answer.

use crate::ewts::{build_stack, stack_alphabet, Alphabet, Letter, Options, Stack};

/// One selectable letter, vowel or mark.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct StackLetter {
    pub key: String,
    pub example: String,
}

impl From<&Letter> for StackLetter {
    fn from(l: &Letter) -> Self {
        Self {
            key: l.key.to_string(),
            example: l.example.clone(),
        }
    }
}

/// A finished stack, as the engine reports it.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BuiltStack {
    pub text: String,
    pub canonical: String,
    pub shortest: String,
    pub code_points: String,
    pub notes: Vec<String>,
}

impl From<&Stack> for BuiltStack {
    fn from(s: &Stack) -> Self {
        Self {
            text: s.text.clone(),
            canonical: s.canonical.clone(),
            shortest: s.shortest.clone(),
            code_points: s.code_points(),
            notes: s.diagnostics.iter().map(|d| d.message.clone()).collect(),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum StackResult {
    Empty,
    Built(BuiltStack),
    Failed(String),
}

/// The stacker's state and rules, with no UI.
#[derive(Debug, Clone)]
pub struct StackerModel {
    pub consonants: Vec<StackLetter>,
    pub subjoined_only: Vec<StackLetter>,
    pub vowels: Vec<StackLetter>,
    pub marks: Vec<StackLetter>,
    pub precomposed: bool,
    layers: Vec<String>,
    vowel: String,
    mark_keys: Vec<String>,
    typed: String,
    hint: String,
    result: StackResult,
}

impl StackerModel {
    /// Starting points. Each is built by the engine like any other stack.
    pub const PRESETS: &'static [(&'static str, &'static [&'static str])] = &[
        ("kṣa", &["k", "Sh"]),
        ("jña", &["j", "ny"]),
        ("ṣṭha", &["Sh", "Th"]),
        ("stra", &["s", "t", "r"]),
        ("ddhya", &["d", "dh", "y"]),
        ("kṣma", &["k", "Sh", "m"]),
        ("rgya", &["r", "g", "y"]),
        ("bsgrub", &["b", "s", "g", "r"]),
    ];

    pub fn new(precomposed: bool) -> Self {
        let a = stack_alphabet();
        Self::from_alphabet(&a, precomposed)
    }

    pub fn from_alphabet(a: &Alphabet, precomposed: bool) -> Self {
        let mut m = Self {
            consonants: a.consonants.iter().map(StackLetter::from).collect(),
            subjoined_only: a.subjoined_only.iter().map(StackLetter::from).collect(),
            vowels: a.vowels.iter().map(StackLetter::from).collect(),
            marks: a.marks.iter().map(StackLetter::from).collect(),
            precomposed,
            layers: Vec::new(),
            vowel: String::new(),
            mark_keys: Vec::new(),
            typed: String::new(),
            hint: String::new(),
            result: StackResult::Empty,
        };
        m.rebuild();
        m
    }

    /// Switches the output form and rebuilds the current stack in it.
    pub fn set_precomposed(&mut self, on: bool) {
        if self.precomposed != on {
            self.precomposed = on;
            self.rebuild();
        }
    }

    pub fn layers(&self) -> &[String] {
        &self.layers
    }
    pub fn vowel(&self) -> &str {
        &self.vowel
    }
    pub fn marks(&self) -> &[String] {
        &self.mark_keys
    }
    pub fn typed(&self) -> &str {
        &self.typed
    }
    pub fn hint(&self) -> &str {
        &self.hint
    }
    pub fn result(&self) -> &StackResult {
        &self.result
    }

    pub fn built(&self) -> Option<&BuiltStack> {
        match &self.result {
            StackResult::Built(b) => Some(b),
            _ => None,
        }
    }

    fn subjoined_only_keys(&self) -> impl Iterator<Item = &str> {
        self.subjoined_only.iter().map(|l| l.key.as_str())
    }

    fn addable_keys(&self) -> Vec<&str> {
        self.consonants
            .iter()
            .map(|l| l.key.as_str())
            .chain(self.subjoined_only.iter().map(|l| l.key.as_str()))
            .collect()
    }

    /// Letters whose keys start with what has been typed.
    pub fn matches(&self, key: &str) -> bool {
        self.typed.is_empty() || key.starts_with(&self.typed)
    }

    /// The key that what is typed stands for: an exact match, else the only candidate.
    pub fn typed_key(&self) -> Option<&str> {
        if self.typed.is_empty() {
            return None;
        }
        let all = self.addable_keys();
        if all.contains(&self.typed.as_str()) {
            return Some(self.typed.as_str());
        }
        let candidates: Vec<&str> = all
            .into_iter()
            .filter(|k| k.starts_with(&self.typed))
            .collect();
        if candidates.len() == 1 {
            Some(candidates[0])
        } else {
            None
        }
    }

    pub fn add_layer(&mut self, key: &str) -> bool {
        self.typed.clear();
        if self.subjoined_only_keys().any(|k| k == key) && self.layers.is_empty() {
            self.hint = format!("{key} only exists under another letter. Add a letter first.");
            return false;
        }
        self.layers.push(key.to_string());
        self.changed();
        true
    }

    pub fn remove_layer(&mut self, i: usize) {
        if i < self.layers.len() {
            self.layers.remove(i);
            self.changed();
        }
    }

    pub fn set_vowel(&mut self, v: &str) {
        if self.vowel == v {
            self.vowel.clear();
        } else {
            self.vowel = v.to_string();
        }
        self.changed();
    }

    pub fn toggle_mark(&mut self, m: &str) {
        if let Some(i) = self.mark_keys.iter().position(|x| x == m) {
            self.mark_keys.remove(i);
        } else {
            self.mark_keys.push(m.to_string());
        }
        self.changed();
    }

    pub fn use_preset(&mut self, letters: &[&str]) {
        self.layers = letters.iter().map(|s| (*s).to_string()).collect();
        self.vowel.clear();
        self.mark_keys.clear();
        self.typed.clear();
        self.changed();
    }

    pub fn clear(&mut self) {
        self.layers.clear();
        self.vowel.clear();
        self.mark_keys.clear();
        self.typed.clear();
        self.changed();
    }

    pub fn set_hint(&mut self, s: &str) {
        self.hint = s.to_string();
    }

    pub fn type_text(&mut self, s: &str) {
        self.typed.push_str(s);
        self.hint.clear();
    }

    pub fn confirm_typed(&mut self) -> bool {
        let key = match self.typed_key() {
            Some(k) => k.to_string(),
            None => {
                if !self.typed.is_empty() {
                    self.hint = format!("{} is not a letter the stacker knows.", self.typed);
                }
                return false;
            }
        };
        self.add_layer(&key)
    }

    pub fn backspace(&mut self) -> bool {
        if !self.typed.is_empty() {
            self.typed.pop();
            self.hint.clear();
            return true;
        }
        if self.layers.is_empty() {
            return false;
        }
        self.layers.pop();
        self.changed();
        true
    }

    /// Takes the finished stack to insert it, and starts the next one.
    pub fn consume(&mut self) -> Option<BuiltStack> {
        let b = match &self.result {
            StackResult::Built(b) => b.clone(),
            _ => return None,
        };
        self.layers.clear();
        self.vowel.clear();
        self.mark_keys.clear();
        self.typed.clear();
        self.rebuild();
        self.hint = format!("Inserted {}. Next time, type {}.", b.text, b.shortest);
        Some(b)
    }

    fn changed(&mut self) {
        self.hint.clear();
        self.rebuild();
    }

    fn rebuild(&mut self) {
        if self.layers.is_empty() {
            self.result = StackResult::Empty;
            return;
        }
        let layers: Vec<&str> = self.layers.iter().map(|s| s.as_str()).collect();
        let marks: Vec<&str> = self.mark_keys.iter().map(|s| s.as_str()).collect();
        let options = Options {
            precomposed: self.precomposed,
            diplomatic: false,
        };
        match build_stack(&layers, Some(&self.vowel), &marks, options) {
            Ok(s) => self.result = StackResult::Built(BuiltStack::from(&s)),
            Err(e) => self.result = StackResult::Failed(e.to_string()),
        }
    }

    /// Snapshot for FFI / UI: JSON with layers, vowel, marks, typed, typedKey, hint,
    /// result and precomposed. The alphabet does not change; read it once from
    /// [`crate::stack_alphabet_json`].
    pub fn state_json(&self) -> String {
        use crate::json::string;
        let layers: Vec<String> = self.layers.iter().map(|s| string(s)).collect();
        let marks: Vec<String> = self.mark_keys.iter().map(|s| string(s)).collect();
        let result = match &self.result {
            StackResult::Empty => "{\"kind\":\"empty\"}".to_string(),
            StackResult::Failed(e) => format!("{{\"kind\":\"failed\",\"error\":{}}}", string(e)),
            StackResult::Built(b) => {
                let notes: Vec<String> = b.notes.iter().map(|n| string(n)).collect();
                format!(
                    "{{\"kind\":\"built\",\"text\":{},\"canonical\":{},\"shortest\":{},\"codePoints\":{},\"notes\":[{}]}}",
                    string(&b.text),
                    string(&b.canonical),
                    string(&b.shortest),
                    string(&b.code_points),
                    notes.join(",")
                )
            }
        };
        let typed_key = self.typed_key().map_or("null".to_string(), string);
        format!(
            "{{\"layers\":[{}],\"vowel\":{},\"marks\":[{}],\"typed\":{},\"typedKey\":{},\"hint\":{},\"result\":{},\"precomposed\":{}}}",
            layers.join(","),
            string(&self.vowel),
            marks.join(","),
            string(&self.typed),
            typed_key,
            string(&self.hint),
            result,
            if self.precomposed { "true" } else { "false" }
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn builds_rgya_and_edits() {
        let mut m = StackerModel::new(false);
        assert_eq!(m.result(), &StackResult::Empty);
        for k in ["r", "g", "y"] {
            assert!(m.add_layer(k));
        }
        let b = m.built().expect("rgya");
        assert_eq!(b.text, "རྒྱ");
        assert_eq!(b.shortest, "rgya");
        assert_eq!(b.canonical, "r+g+ya");
        assert_eq!(b.code_points, "0F62 0F92 0FB1");
        m.set_vowel("i");
        assert_eq!(m.built().unwrap().shortest, "rgyi");
        m.set_vowel("i");
        assert_eq!(m.built().unwrap().shortest, "rgya");
        m.toggle_mark("M");
        assert!(m.built().unwrap().shortest.ends_with('M'));
        m.backspace();
        assert_eq!(m.layers(), &["r".to_string(), "g".to_string()]);
        let inserted = m.consume();
        assert!(inserted.is_some());
        assert!(m.layers().is_empty());
        assert!(m.hint().starts_with("Inserted"));
    }

    #[test]
    fn typing_and_presets() {
        let mut m = StackerModel::new(false);
        m.type_text("k");
        assert_eq!(m.typed_key(), Some("k"));
        assert!(m.matches("kh"));
        assert!(!m.matches("g"));
        m.type_text("h");
        assert_eq!(m.typed_key(), Some("kh"));
        assert!(!m.matches("k"));
        assert!(m.confirm_typed());
        assert_eq!(m.layers(), &["kh".to_string()]);
        m.type_text("q");
        assert!(!m.confirm_typed());
        assert!(!m.hint().is_empty());
        m.backspace();
        m.backspace();
        assert!(m.layers().is_empty());
        assert!(!m.add_layer("W"));
        assert!(!m.backspace());
        m.use_preset(&["W", "k"]);
        assert!(matches!(m.result(), StackResult::Failed(_)));
        m.use_preset(&["k", "Sh"]);
        assert_eq!(m.built().unwrap().text, "ཀྵ");
        assert!(m.consonants.len() >= 30);
        assert!(!m.vowels.is_empty());
        assert!(!m.marks.is_empty());
    }

    #[test]
    fn state_json_snapshot() {
        let mut m = StackerModel::new(false);
        m.type_text("k");
        let j = m.state_json();
        assert!(j.contains("\"typed\":\"k\",\"typedKey\":\"k\""), "{j}");
        assert!(j.contains("\"result\":{\"kind\":\"empty\"}"), "{j}");
        assert!(!j.contains("consonants"), "alphabet is not repeated: {j}");
        m.use_preset(&["r", "g", "y"]);
        assert!(m.state_json().contains("\"shortest\":\"rgya\""));
    }
}
