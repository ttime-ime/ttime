//! The symbol catalogue: Tibetan punctuation, marks and Sanskrit letters with
//! the EWTS that produces each. The data lives in `data/symbols.tsv` and is
//! embedded here, so every front end (web palette, macOS panel) shows the same
//! entries and the same search results.
//!
//! The catalogue is a draft. Tests check that each entry's EWTS converts to
//! exactly its code points, but labels and notes have not been reviewed by a
//! Tibetologist.

use std::sync::OnceLock;

const DATA: &str = include_str!("../data/symbols.tsv");

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Symbol {
    /// Stable identifier, for example `"shad"`.
    pub id: String,
    pub category: String,
    /// The Tibetan text this entry inserts (one or more code points).
    pub text: String,
    /// The EWTS that produces `text`, when the engine has one.
    pub ewts: Option<String>,
    /// Unicode character name(s), without the "TIBETAN " prefix.
    pub name: String,
    pub label: String,
    pub note: String,
    /// The fixture file that lists the same EWTS to Unicode pair, or `engine`.
    pub evidence: String,
}

impl Symbol {
    /// Code points as `U+0F0B`-style hex, space separated.
    pub fn code_points(&self) -> String {
        self.text
            .chars()
            .map(|c| format!("U+{:04X}", c as u32))
            .collect::<Vec<_>>()
            .join(" ")
    }
}

/// Parses catalogue text. Returns the first malformed line as an error.
pub fn parse(data: &str) -> Result<Vec<Symbol>, String> {
    let mut out = Vec::new();
    for (n, line) in data.lines().enumerate() {
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        let f: Vec<&str> = line.split('\t').collect();
        if f.len() != 8 {
            return Err(format!(
                "line {}: expected 8 fields, found {}",
                n + 1,
                f.len()
            ));
        }
        let mut text = String::new();
        for hex in f[2].split_whitespace() {
            let cp = u32::from_str_radix(hex, 16)
                .ok()
                .and_then(char::from_u32)
                .ok_or_else(|| format!("line {}: bad code point {hex:?}", n + 1))?;
            text.push(cp);
        }
        if text.is_empty() {
            return Err(format!("line {}: no code points", n + 1));
        }
        let ewts = match f[3] {
            "" => None,
            "\\s" => Some(" ".to_string()),
            e => Some(e.to_string()),
        };
        out.push(Symbol {
            id: f[0].to_string(),
            category: f[1].to_string(),
            text,
            ewts,
            name: f[4].to_string(),
            label: f[5].to_string(),
            note: f[6].to_string(),
            evidence: f[7].to_string(),
        });
    }
    Ok(out)
}

/// All catalogue entries, in file order.
pub fn catalogue() -> &'static [Symbol] {
    static CATALOGUE: OnceLock<Vec<Symbol>> = OnceLock::new();
    CATALOGUE.get_or_init(|| parse(DATA).expect("data/symbols.tsv is malformed (see tests)"))
}

/// Category names in order of first appearance.
pub fn categories() -> Vec<&'static str> {
    let mut seen: Vec<&'static str> = Vec::new();
    for s in catalogue() {
        if !seen.contains(&s.category.as_str()) {
            seen.push(&s.category);
        }
    }
    seen
}

/// Entries matching `query`. Every whitespace-separated word must appear
/// somewhere in the entry's id, category, label, Unicode name, note, EWTS,
/// code points (`0F0B` or `U+0F0B`) or text, ignoring case. An empty query
/// returns everything. An exact, case-sensitive EWTS match (EWTS distinguishes
/// `Ta` from `ta`) is listed first; otherwise the catalogue order is kept.
pub fn search(query: &str) -> Vec<&'static Symbol> {
    let q = query.trim();
    let words: Vec<String> = q
        .split_whitespace()
        .map(|w| w.to_lowercase().trim_start_matches("u+").to_string())
        .collect();
    let mut hits: Vec<&'static Symbol> = catalogue()
        .iter()
        .filter(|s| {
            let hay = format!(
                "{} {} {} {} {} {} {} {}",
                s.id,
                s.category,
                s.label,
                s.name,
                s.note,
                s.ewts.as_deref().unwrap_or(""),
                s.code_points(),
                s.text
            )
            .to_lowercase();
            words.iter().all(|w| hay.contains(w.as_str()))
        })
        .collect();
    if !q.is_empty() {
        hits.sort_by_key(|s| if s.ewts.as_deref() == Some(q) { 0 } else { 1 });
    }
    hits
}
