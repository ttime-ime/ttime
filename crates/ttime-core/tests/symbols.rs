//! The catalogue must agree with the engine and with the fixtures it cites.

use std::collections::HashSet;
use ttime_core::ewts_to_unicode;
use ttime_core::symbols::{catalogue, categories, parse, search};

fn unescape(s: &str) -> String {
    let mut out = String::new();
    let mut it = s.chars().peekable();
    while let Some(c) = it.next() {
        if c == '\\' {
            let n = match it.peek() {
                Some('u') => 4,
                Some('U') => 8,
                _ => 0,
            };
            if n > 0 {
                it.next();
                let hex: String = (0..n).filter_map(|_| it.next()).collect();
                if let Some(ch) = u32::from_str_radix(&hex, 16).ok().and_then(char::from_u32) {
                    out.push(ch);
                    continue;
                }
            }
        }
        out.push(c);
    }
    out
}

#[test]
fn data_parses_and_ids_are_unique() {
    let all = parse(include_str!("../data/symbols.tsv")).expect("malformed catalogue");
    assert!(
        all.len() >= 40,
        "draft catalogue should have about 40 entries or more"
    );
    let ids: HashSet<&str> = all.iter().map(|s| s.id.as_str()).collect();
    assert_eq!(ids.len(), all.len(), "duplicate id");
    for s in &all {
        assert!(
            !s.category.is_empty() && !s.label.is_empty() && !s.name.is_empty(),
            "{}",
            s.id
        );
        assert!(!s.evidence.is_empty(), "{}", s.id);
    }
}

#[test]
fn everything_is_in_the_tibetan_block() {
    for s in catalogue() {
        for c in s.text.chars() {
            assert!(('\u{0F00}'..='\u{0FFF}').contains(&c), "{}: {c:?}", s.id);
        }
    }
}

#[test]
fn each_ewts_converts_to_exactly_the_entry_text() {
    for s in catalogue() {
        if let Some(e) = &s.ewts {
            assert_eq!(ewts_to_unicode(e), s.text, "{} ({e:?})", s.id);
        }
    }
}

#[test]
fn cited_fixtures_contain_the_same_pair() {
    for s in catalogue() {
        if s.evidence == "engine" {
            continue;
        }
        let ewts = s
            .ewts
            .as_deref()
            .unwrap_or_else(|| panic!("{} cites a fixture but has no EWTS", s.id));
        let path = format!(
            "{}/tests/fixtures/{}",
            env!("CARGO_MANIFEST_DIR"),
            s.evidence
        );
        let file = std::fs::read_to_string(&path).unwrap_or_else(|e| panic!("{path}: {e}"));
        let found = file.lines().any(|l| {
            l.split_once('\t')
                .is_some_and(|(a, b)| unescape(a) == ewts && unescape(b) == s.text)
        });
        assert!(found, "{}: {ewts:?} is not listed in {}", s.id, s.evidence);
    }
}

#[test]
fn categories_are_listed_once_in_order() {
    let c = categories();
    assert_eq!(c.iter().collect::<HashSet<_>>().len(), c.len());
    assert_eq!(c[0], "punctuation");
}

#[test]
fn empty_query_returns_everything() {
    assert_eq!(search("").len(), catalogue().len());
    assert_eq!(search("   ").len(), catalogue().len());
}

#[test]
fn search_by_name_label_codepoint_and_character() {
    let ids = |q: &str| search(q).iter().map(|s| s.id.clone()).collect::<Vec<_>>();
    assert!(ids("double shad").contains(&"nyis-shad".to_string()));
    assert!(ids("0F0D").contains(&"shad".to_string()));
    assert!(ids("u+0f0d").contains(&"shad".to_string()));
    assert!(ids("།").contains(&"shad".to_string()));
    assert!(ids("retroflex na").contains(&"retroflex-na".to_string()));
    assert!(!ids("retroflex na").contains(&"retroflex-ta".to_string()));
    assert!(ids("zzzzqq").is_empty());
}

#[test]
fn exact_ewts_match_comes_first_and_is_case_sensitive() {
    assert_eq!(search("Ta")[0].id, "retroflex-ta");
    assert_eq!(search("/")[0].id, "shad");
    assert_eq!(search("//")[0].id, "nyis-shad");
}
