//! Sanskrit (IAST) suggestions: accented words searched by what the user types
//! without diacritics. See `docs/reference/sanskrit-spike.md`.

use std::cmp::Ordering;
use std::sync::Arc;

#[derive(Debug, Clone)]
struct Entry {
    word: String,
    key: String,
    count: i32,
    buddhist: bool,
    length: usize,
}

/// The word list behind the Sanskrit suggestions.
#[derive(Debug, Clone)]
pub struct SanskritLexicon {
    entries: Vec<Entry>,
    /// Position of each entry in the ranking, best first (indexes `entries`).
    rank: Vec<i32>,
}

impl SanskritLexicon {
    /// What the user types: the word without diacritics, lowercase. Combining marks
    /// (decomposed input) and the apostrophe U+2019 are dropped.
    pub fn fold(s: &str) -> String {
        let mut out = String::new();
        for c in s.chars() {
            if c == '\u{2019}' || is_combining_mark(c) {
                continue;
            }
            for l in c.to_lowercase() {
                out.push(plain_of(l).unwrap_or(l));
            }
        }
        out
    }

    /// Parses `word<TAB>count<TAB>flag` lines.
    pub fn from_tsv(tsv: &str) -> Self {
        Self::from_bytes(tsv.as_bytes())
    }

    pub fn from_bytes(data: &[u8]) -> Self {
        let mut list: Vec<Entry> = Vec::new();
        let mut i = 0;
        let n = data.len();
        while i < n {
            let mut tab1 = i;
            while tab1 < n && data[tab1] != b'\t' && data[tab1] != b'\n' {
                tab1 += 1;
            }
            if tab1 >= n || data[tab1] != b'\t' {
                while i < n && data[i] != b'\n' {
                    i += 1;
                }
                i += 1;
                continue;
            }
            let mut tab2 = tab1 + 1;
            while tab2 < n && data[tab2] != b'\t' && data[tab2] != b'\n' {
                tab2 += 1;
            }
            let mut end = tab2 + 1;
            while end < n && data[end] != b'\n' {
                end += 1;
            }
            let mut count = 0i32;
            for &b in &data[tab1 + 1..tab2] {
                count = count * 10 + (b.wrapping_sub(b'0') as i32);
            }
            let flag = if tab2 + 1 < end { data[tab2 + 1] } else { b'-' };
            let word = String::from_utf8_lossy(&data[i..tab1]).into_owned();
            let key = Self::fold(&word);
            let length = word.chars().count();
            list.push(Entry {
                word,
                key,
                count,
                buddhist: flag == b'b',
                length,
            });
            i = end + 1;
        }

        // Better first: more occurrences, then Buddhist, then shorter, then alphabetical.
        let better_ord = |a: &Entry, b: &Entry| -> Ordering {
            match b.count.cmp(&a.count) {
                Ordering::Equal => {}
                o => return o,
            }
            match (a.buddhist, b.buddhist) {
                (true, false) => return Ordering::Less,
                (false, true) => return Ordering::Greater,
                _ => {}
            }
            match a.length.cmp(&b.length) {
                Ordering::Equal => {}
                o => return o,
            }
            a.word.as_bytes().cmp(b.word.as_bytes())
        };

        list.sort_by(|a, b| {
            if a.key != b.key {
                a.key.as_bytes().cmp(b.key.as_bytes())
            } else {
                better_ord(a, b)
            }
        });
        let mut order: Vec<usize> = (0..list.len()).collect();
        order.sort_by(|&i, &j| better_ord(&list[i], &list[j]));
        let mut rank = vec![0i32; list.len()];
        for (r, &i) in order.iter().enumerate() {
            rank[i] = r as i32;
        }
        Self {
            entries: list,
            rank,
        }
    }

    pub fn len(&self) -> usize {
        self.entries.len()
    }

    pub fn is_empty(&self) -> bool {
        self.entries.is_empty()
    }

    /// The best `limit` words whose accent-free spelling starts with `typed`.
    pub fn suggest(&self, typed: &str, limit: usize) -> Vec<String> {
        let key = Self::fold(typed);
        if key.is_empty() {
            return Vec::new();
        }
        let start = self
            .entries
            .partition_point(|e| e.key.as_bytes() < key.as_bytes());
        let mut end = start;
        while end < self.entries.len() && self.entries[end].key.starts_with(&key) {
            end += 1;
        }
        if end <= start {
            return Vec::new();
        }
        let mut best: Vec<usize> = Vec::new();
        for i in start..end {
            if best.len() < limit {
                best.push(i);
            } else if let Some((wi, &worst)) = best
                .iter()
                .enumerate()
                .max_by_key(|(_, &idx)| self.rank[idx])
            {
                if self.rank[i] < self.rank[worst] {
                    best[wi] = i;
                }
            }
        }
        best.sort_by_key(|&i| self.rank[i]);
        best.into_iter()
            .map(|i| self.entries[i].word.clone())
            .collect()
    }
}

/// The plain letter a lowercase accented letter is typed as. Covers IAST and its
/// common variants (ṁ, ṉ, ṟ, ẖ) and the accented Latin vowels and consonants a
/// headword may carry, so every key in the bundled list is ASCII (tested).
fn plain_of(c: char) -> Option<char> {
    Some(match c {
        'ā' | 'á' | 'à' | 'â' | 'ä' | 'ã' | 'å' => 'a',
        'ī' | 'í' | 'ì' | 'î' | 'ï' => 'i',
        'ū' | 'ú' | 'ù' | 'û' | 'ü' => 'u',
        'ē' | 'é' | 'è' | 'ê' | 'ë' => 'e',
        'ō' | 'ó' | 'ò' | 'ô' | 'ö' | 'õ' => 'o',
        'ṛ' | 'ṝ' | 'ṟ' => 'r',
        'ḷ' | 'ḹ' | 'ḻ' => 'l',
        'ṃ' | 'ṁ' => 'm',
        'ḥ' | 'ẖ' => 'h',
        'ṅ' | 'ñ' | 'ṇ' | 'ṉ' => 'n',
        'ṭ' => 't',
        'ḍ' => 'd',
        'ś' | 'ṣ' | 'š' => 's',
        'ç' => 'c',
        'ý' | 'ÿ' => 'y',
        _ => return None,
    })
}

fn is_combining_mark(c: char) -> bool {
    matches!(
        c,
        '\u{0300}'..='\u{036F}'
            | '\u{1AB0}'..='\u{1AFF}'
            | '\u{1DC0}'..='\u{1DFF}'
            | '\u{20D0}'..='\u{20FF}'
            | '\u{FE20}'..='\u{FE2F}'
    )
}

/// The word being typed in Latin mode, and the suggestions for it.
#[derive(Debug, Clone)]
pub struct SanskritSuggester {
    /// Shared: one parsed list serves every composer (parsing takes ~90 ms).
    lexicon: Arc<SanskritLexicon>,
    buffer: String,
    suggestions: Vec<String>,
    selected: usize,
}

impl SanskritSuggester {
    pub const MINIMUM_LETTERS: usize = 3;

    pub fn new(lexicon: Arc<SanskritLexicon>) -> Self {
        Self {
            lexicon,
            buffer: String::new(),
            suggestions: Vec::new(),
            selected: 0,
        }
    }

    pub fn buffer(&self) -> &str {
        &self.buffer
    }

    pub fn suggestions(&self) -> &[String] {
        &self.suggestions
    }

    pub fn selected(&self) -> usize {
        self.selected
    }

    pub fn is_empty(&self) -> bool {
        self.buffer.is_empty()
    }

    /// Whether a typed character belongs to a word (an ASCII letter).
    pub fn is_letter(s: &str) -> bool {
        let mut chars = s.chars();
        match (chars.next(), chars.next()) {
            (Some(c), None) => c.is_ascii_alphabetic(),
            _ => false,
        }
    }

    pub fn type_letter(&mut self, letter: &str) {
        self.buffer.push_str(letter);
        self.refresh();
    }

    /// Deletes the last letter. False if the buffer was empty.
    pub fn backspace(&mut self) -> bool {
        if self.buffer.is_empty() {
            return false;
        }
        self.buffer.pop();
        self.refresh();
        true
    }

    pub fn move_by(&mut self, delta: isize) {
        if self.suggestions.is_empty() {
            return;
        }
        let n = self.suggestions.len();
        self.selected = (self.selected as isize + delta).clamp(0, (n - 1) as isize) as usize;
    }

    pub fn select(&mut self, index: usize) -> bool {
        if index < self.suggestions.len() {
            self.selected = index;
            true
        } else {
            false
        }
    }

    pub fn replace_last(&mut self, letter: &str) {
        if self.buffer.is_empty() {
            return;
        }
        self.buffer.pop();
        self.buffer.push_str(letter);
        self.refresh();
    }

    pub fn flush(&mut self) -> String {
        let b = std::mem::take(&mut self.buffer);
        self.clear();
        b
    }

    /// The selected suggestion, capitalised like the typed text. `None` when nothing to accept.
    pub fn accept(&mut self) -> Option<String> {
        let word = self.suggestions.get(self.selected)?.clone();
        let word = if self
            .buffer
            .chars()
            .next()
            .map(|c| c.is_uppercase())
            .unwrap_or(false)
        {
            let mut chars = word.chars();
            let first = chars.next()?.to_uppercase().collect::<String>();
            first + chars.as_str()
        } else {
            word
        };
        self.clear();
        Some(word)
    }

    pub fn clear(&mut self) {
        self.buffer.clear();
        self.suggestions.clear();
        self.selected = 0;
    }

    /// Suggestions as they would be shown (capitalised like the typed text).
    pub fn shown(&self) -> Vec<String> {
        let capitalize = self
            .buffer
            .chars()
            .next()
            .map(|c| c.is_uppercase())
            .unwrap_or(false);
        if !capitalize {
            return self.suggestions.clone();
        }
        self.suggestions
            .iter()
            .map(|w| {
                let mut chars = w.chars();
                match chars.next() {
                    Some(c) => c.to_uppercase().collect::<String>() + chars.as_str(),
                    None => String::new(),
                }
            })
            .collect()
    }

    fn refresh(&mut self) {
        self.selected = 0;
        self.suggestions = if self.buffer.chars().count() >= Self::MINIMUM_LETTERS {
            self.lexicon.suggest(&self.buffer, 5)
        } else {
            Vec::new()
        };
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample() -> SanskritLexicon {
        SanskritLexicon::from_tsv(
            "prajñā\t100\tb\nprajña\t10\t-\nprājña\t5\t-\npratītyasamutpāda\t20\tb\npratyaya\t50\tb\nśiva\t80\t-\nśivā\t3\t-\nsiva\t1\t-\nśūnyatā\t40\tb\n",
        )
    }

    #[test]
    fn fold_and_suggest() {
        assert_eq!(SanskritLexicon::fold("śūnyatā"), "sunyata");
        let lex = sample();
        assert_eq!(lex.suggest("praj", 5), vec!["prajñā", "prajña", "prājña"]);
        assert_eq!(lex.suggest("siva", 5), vec!["śiva", "śivā", "siva"]);
        assert_eq!(
            lex.suggest("pra", 5).first().map(|s| s.as_str()),
            Some("prajñā")
        );
        assert_eq!(lex.suggest("pra", 5).len(), 5);
        assert!(lex.suggest("zzz", 5).is_empty());
        assert_eq!(lex.suggest("Sunya", 5), vec!["śūnyatā"]);
    }

    #[test]
    fn fold_handles_capitals_decomposed_and_variants() {
        assert_eq!(SanskritLexicon::fold("Ṝṣi"), "rsi");
        assert_eq!(SanskritLexicon::fold("Ḹ"), "l");
        assert_eq!(SanskritLexicon::fold("sa\u{0304}ṁkhya"), "samkhya");
        assert_eq!(SanskritLexicon::fold("bhagavat\u{2019}"), "bhagavat");
    }

    #[test]
    fn every_bundled_key_is_ascii() {
        let path = concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/../../data/sanskrit/iast-lexicon.tsv"
        );
        let data = std::fs::read(path).expect("bundled lexicon");
        let lex = SanskritLexicon::from_bytes(&data);
        assert!(lex.len() > 100_000);
        let bad: Vec<&str> = lex
            .entries
            .iter()
            .filter(|e| !e.key.is_ascii())
            .map(|e| e.word.as_str())
            .take(10)
            .collect();
        assert!(bad.is_empty(), "keys that cannot be typed: {bad:?}");
    }
}
