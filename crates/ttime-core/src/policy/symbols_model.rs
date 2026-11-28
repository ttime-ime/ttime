//! Symbols window state: search, category filter, selected entry.

use crate::symbols::{self, Symbol};

/// One entry of the symbol catalogue (owned, for the model).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SymbolEntry {
    pub id: String,
    pub category: String,
    pub text: String,
    pub ewts: Option<String>,
    pub name: String,
    pub label: String,
    pub note: String,
    pub code_points: String,
}

impl SymbolEntry {
    fn from_symbol(s: &Symbol) -> Self {
        Self {
            id: s.id.clone(),
            category: s.category.clone(),
            text: s.text.clone(),
            ewts: s.ewts.clone(),
            name: s.name.clone(),
            label: s.label.clone(),
            note: s.note.clone(),
            code_points: s.code_points(),
        }
    }

    /// A mark that only exists on a letter gets a dotted circle so it is visible alone.
    pub fn display(&self) -> String {
        let Some(first) = self.text.chars().next() else {
            return self.text.clone();
        };
        if is_mark(first) {
            format!("\u{25CC}{}", self.text)
        } else {
            self.text.clone()
        }
    }
}

/// Whether `c` is a combining mark (general category Mn, Mc or Me): the generic
/// combining blocks and the Tibetan block's marks, which is everything the catalogue
/// can contain. Tibetan ranges are from UnicodeData.txt.
fn is_mark(c: char) -> bool {
    matches!(
        c,
        '\u{0300}'..='\u{036F}'
            | '\u{1AB0}'..='\u{1AFF}'
            | '\u{1DC0}'..='\u{1DFF}'
            | '\u{20D0}'..='\u{20FF}'
            | '\u{FE20}'..='\u{FE2F}'
            | '\u{0F18}'..='\u{0F19}'
            | '\u{0F35}'
            | '\u{0F37}'
            | '\u{0F39}'
            | '\u{0F3E}'..='\u{0F3F}'
            | '\u{0F71}'..='\u{0F84}'
            | '\u{0F86}'..='\u{0F87}'
            | '\u{0F8D}'..='\u{0F97}'
            | '\u{0F99}'..='\u{0FBC}'
            | '\u{0FC6}'
    )
}

/// The symbols window's state and rules, with no UI.
#[derive(Debug, Clone)]
pub struct SymbolsModel {
    categories: Vec<String>,
    query: String,
    category: Option<String>,
    results: Vec<SymbolEntry>,
    selected: usize,
    hint: String,
}

impl SymbolsModel {
    pub fn new() -> Self {
        let categories = symbols::categories()
            .into_iter()
            .map(|s| s.to_string())
            .collect();
        let mut m = Self {
            categories,
            query: String::new(),
            category: None,
            results: Vec::new(),
            selected: 0,
            hint: String::new(),
        };
        m.refresh();
        m
    }

    pub fn categories(&self) -> &[String] {
        &self.categories
    }
    pub fn query(&self) -> &str {
        &self.query
    }
    pub fn category(&self) -> Option<&str> {
        self.category.as_deref()
    }
    pub fn results(&self) -> &[SymbolEntry] {
        &self.results
    }
    pub fn selected(&self) -> usize {
        self.selected
    }
    pub fn hint(&self) -> &str {
        &self.hint
    }

    pub fn selected_entry(&self) -> Option<&SymbolEntry> {
        self.results.get(self.selected)
    }

    pub fn type_text(&mut self, s: &str) {
        self.query.push_str(s);
        self.refresh();
    }

    pub fn backspace(&mut self) -> bool {
        if self.query.is_empty() {
            return false;
        }
        self.query.pop();
        self.refresh();
        true
    }

    pub fn clear_query(&mut self) {
        self.query.clear();
        self.refresh();
    }

    pub fn set_category(&mut self, c: Option<&str>) {
        self.category = c.map(|s| s.to_string());
        self.refresh();
    }

    pub fn next_category(&mut self) {
        if self.categories.is_empty() {
            return;
        }
        self.category = match &self.category {
            Some(c) => match self.categories.iter().position(|x| x == c) {
                Some(i) if i + 1 < self.categories.len() => Some(self.categories[i + 1].clone()),
                _ => None,
            },
            None => Some(self.categories[0].clone()),
        };
        self.refresh();
    }

    pub fn move_by(&mut self, delta: isize) {
        if self.results.is_empty() {
            return;
        }
        let n = self.results.len();
        self.selected = (self.selected as isize + delta).clamp(0, (n - 1) as isize) as usize;
    }

    pub fn select(&mut self, i: usize) {
        if i < self.results.len() {
            self.selected = i;
        }
    }

    pub fn set_hint(&mut self, s: &str) {
        self.hint = s.to_string();
    }

    fn refresh(&mut self) {
        self.hint.clear();
        self.selected = 0;
        self.results = symbols::search(&self.query)
            .into_iter()
            .filter(|s| {
                self.category
                    .as_ref()
                    .map(|c| c == &s.category)
                    .unwrap_or(true)
            })
            .map(SymbolEntry::from_symbol)
            .collect();
    }

    pub fn state_json(&self) -> String {
        use crate::json::string;
        let cats: Vec<String> = self.categories.iter().map(|c| string(c)).collect();
        let results: Vec<String> = self
            .results
            .iter()
            .map(|e| {
                format!(
                    "{{\"id\":{},\"category\":{},\"text\":{},\"ewts\":{},\"name\":{},\"label\":{},\"note\":{},\"codePoints\":{},\"display\":{}}}",
                    string(&e.id),
                    string(&e.category),
                    string(&e.text),
                    e.ewts.as_deref().map_or("null".to_string(), string),
                    string(&e.name),
                    string(&e.label),
                    string(&e.note),
                    string(&e.code_points),
                    string(&e.display())
                )
            })
            .collect();
        format!(
            "{{\"categories\":[{}],\"query\":{},\"category\":{},\"results\":[{}],\"selected\":{},\"hint\":{}}}",
            cats.join(","),
            string(&self.query),
            self.category
                .as_deref()
                .map_or("null".to_string(), string),
            results.join(","),
            self.selected,
            string(&self.hint)
        )
    }
}

impl Default for SymbolsModel {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn catalogue_search_and_filter() {
        let mut m = SymbolsModel::new();
        assert!(m.results().len() >= 50);
        assert!(m.categories().len() >= 5);
        m.type_text("shad");
        assert!(m.results().iter().any(|e| e.id == "shad" && e.text == "།"));
        m.clear_query();
        m.set_category(Some("punctuation"));
        assert!(!m.results().is_empty());
        assert!(m.results().iter().all(|e| e.category == "punctuation"));
        m.set_category(None);
        for _ in 0..=m.categories().len() {
            m.next_category();
        }
        assert!(m.category().is_none());
        m.move_by(2);
        assert_eq!(m.selected(), 2);
        m.move_by(-9);
        assert_eq!(m.selected(), 0);
        m.type_text("zzzzzz");
        assert!(m.results().is_empty());
        assert!(m.selected_entry().is_none());
        assert!(m.backspace());
        m.clear_query();
        assert!(!m.backspace());
        let mark = SymbolEntry {
            id: "x".into(),
            category: "marks".into(),
            text: "\u{0F7E}".into(),
            ewts: Some("M".into()),
            name: String::new(),
            label: String::new(),
            note: String::new(),
            code_points: String::new(),
        };
        assert_eq!(mark.display(), "\u{25CC}\u{0F7E}");
    }

    #[test]
    fn only_real_marks_get_a_dotted_circle() {
        for c in [
            '\u{0F7E}', '\u{0F7F}', '\u{0F35}', '\u{0F39}', '\u{0F84}', '\u{0F3E}', '\u{0FB1}',
        ] {
            assert!(is_mark(c), "{:04X}", c as u32);
        }
        // Paluta is punctuation; 0F36 and 0F38 are symbols; 0F88 is a letter.
        for c in [
            '\u{0F85}', '\u{0F36}', '\u{0F38}', '\u{0F88}', '\u{0F98}', '\u{0F40}', '\u{0F0B}',
        ] {
            assert!(!is_mark(c), "{:04X}", c as u32);
        }
        let m = SymbolsModel::new();
        let paluta = m
            .results()
            .iter()
            .find(|e| e.id == "paluta")
            .expect("paluta");
        assert_eq!(paluta.display(), paluta.text);
    }
}
