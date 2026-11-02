//! Unicode to EWTS. A round trip is `forward(reverse(u))`, measured with
//! default options. Exact means equal to `u`; canonical means equal after
//! canonical normalisation (precomposed characters decomposed, marks ordered).

use std::fs;
use std::path::Path;

use ttime_core::{convert, ewts_to_unicode, unicode_to_ewts, Code, Fidelity, Options};

fn unescape(s: &str) -> String {
    let mut out = String::new();
    let mut rest = s;
    while let Some(pos) = rest.find("\\u") {
        out.push_str(&rest[..pos]);
        let cp = u32::from_str_radix(&rest[pos + 2..pos + 6], 16).unwrap();
        out.push(char::from_u32(cp).unwrap());
        rest = &rest[pos + 6..];
    }
    out.push_str(rest);
    out
}

fn fixture(file: &str) -> Vec<(String, String)> {
    let path = Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("tests/fixtures")
        .join(file);
    fs::read_to_string(path)
        .unwrap()
        .lines()
        .filter(|l| !l.is_empty() && !l.starts_with('#'))
        .map(|l| {
            let (a, b) = l.split_once('\t').unwrap();
            (a.to_string(), unescape(b))
        })
        .collect()
}

fn round_trip(unicode: &str) -> (String, Fidelity, String) {
    let r = unicode_to_ewts(unicode);
    let back = ewts_to_unicode(&r.text);
    (r.text, r.fidelity, back)
}

#[test]
fn every_default_mode_fixture_round_trips_exactly() {
    let mut failures = Vec::new();
    let mut n = 0;
    for file in [
        "words.tsv",
        "alphabet.tsv",
        "stacks.tsv",
        "syllables.tsv",
        "sanskrit.tsv",
        "punctuation.tsv",
    ] {
        for (ewts, unicode) in fixture(file) {
            n += 1;
            let (text, fidelity, back) = round_trip(&unicode);
            if back != unicode || fidelity != Fidelity::Exact {
                failures.push(format!(
                    "{file}: {ewts:?} -> {unicode:?} -> {text:?} -> {back:?} ({fidelity:?})"
                ));
            }
        }
    }
    assert!(n > 300);
    assert!(
        failures.is_empty(),
        "{} of {n} failed:\n{}",
        failures.len(),
        failures.join("\n")
    );
}

#[test]
fn ordinary_words_come_back_as_the_ewts_they_came_from() {
    let mut failures = Vec::new();
    let words = fixture("words.tsv");
    for (ewts, unicode) in &words {
        let got = unicode_to_ewts(unicode).text;
        if &got != ewts {
            failures.push(format!("{unicode} should be {ewts:?}, got {got:?}"));
        }
    }
    assert!(failures.is_empty(), "{}", failures.join("\n"));
}

#[test]
fn stacks_use_plus_only_when_needed() {
    assert_eq!(unicode_to_ewts("རྒྱ").text, "rgya");
    assert_eq!(unicode_to_ewts("ཀྵ").text, "k+Sha");
    assert_eq!(unicode_to_ewts("ཀྲྀ").text, "kr-i");
    assert_eq!(unicode_to_ewts("པདྨ").text, "pad+ma");
}

#[test]
fn prefix_before_a_stack_that_would_merge_gets_a_dot() {
    // Unicode "g" + "ya" (two letters, no stack) must not become "gya".
    let r = unicode_to_ewts("གཡ");
    assert_eq!(r.text, "g.ya");
    assert_eq!(r.fidelity, Fidelity::Exact);
}

#[test]
fn punctuation_digits_and_spaces() {
    assert_eq!(unicode_to_ewts("བོད་།").text, "bod /");
    assert_eq!(unicode_to_ewts("༎").text, "//");
    assert_eq!(unicode_to_ewts("༠༡༢").text, "012");
    assert_eq!(unicode_to_ewts("༪༳").text, "-1-0");
    assert_eq!(unicode_to_ewts("ཀ ཀ").text, "ka_ka");
    assert_eq!(unicode_to_ewts("ཀ\nཀ").text, "ka\nka");
    assert_eq!(unicode_to_ewts("\u{0F00}").text, "oM");
}

#[test]
fn marks_round_trip() {
    for ewts in [
        "kM", "kH", "k~M", "k~M`", "kX", "k~X", "k^", "k?", "k&", "kA?", "ki~M", "kuoM",
    ] {
        let unicode = ewts_to_unicode(ewts);
        let (text, fidelity, back) = round_trip(&unicode);
        assert_eq!(
            (back.as_str(), fidelity),
            (unicode.as_str(), Fidelity::Exact),
            "{ewts:?} -> {text:?}"
        );
    }
}

#[test]
fn f_and_v_and_aspirates() {
    assert_eq!(unicode_to_ewts("\u{0F55}\u{0F39}").text, "fa");
    assert_eq!(unicode_to_ewts("\u{0F56}\u{0F39}").text, "va");
    assert_eq!(unicode_to_ewts("\u{0F42}\u{0FB7}").text, "gha");
    assert_eq!(unicode_to_ewts("\u{0F5B}\u{0FB7}").text, "dzha");
    assert_eq!(unicode_to_ewts("\u{0F40}\u{0FBC}").text, "k+Ra");
}

#[test]
fn non_tibetan_text_is_kept_literally() {
    let r = unicode_to_ewts("abc བོད");
    assert_eq!(r.text, "[abc]_bod");
    assert_eq!(r.fidelity, Fidelity::Exact);

    let r = unicode_to_ewts("a]b");
    assert_eq!(r.text, "[a]\\u005D[b]");
    assert_eq!(r.fidelity, Fidelity::Exact);

    let r = unicode_to_ewts("é中😀 123");
    assert_eq!(ewts_to_unicode(&r.text), "é中😀 123");
}

#[test]
fn characters_without_an_ewts_spelling_become_escapes() {
    // U+0F01 (gter yig mgo) has no EWTS spelling.
    let r = unicode_to_ewts("\u{0F01}ཀ");
    assert_eq!(r.text, "\\u0F01ka");
    assert_eq!(r.fidelity, Fidelity::Exact);
    assert_eq!(r.diagnostics.len(), 1);
    assert_eq!(r.diagnostics[0].code, Code::ReverseUnsupportedCodePoint);
    assert_eq!(r.diagnostics[0].span, 0..3);

    // A subjoined letter or vowel sign with no base cannot be spelled.
    let r = unicode_to_ewts("\u{0F72}");
    assert_eq!(r.text, "\\u0F72");
    assert_eq!(r.fidelity, Fidelity::Exact);
    assert_eq!(r.diagnostics[0].code, Code::ReverseUnsupportedCodePoint);
}

#[test]
fn canonically_equivalent_input_gives_canonical_fidelity() {
    // Precomposed gha (U+0F43) is not NFC.
    let r = unicode_to_ewts("\u{0F43}");
    assert_eq!(r.text, "gha");
    assert_eq!(r.fidelity, Fidelity::Canonical);
    assert_eq!(r.diagnostics.len(), 1);
    assert_eq!(r.diagnostics[0].code, Code::ReverseNonCanonicalInput);

    // Same text, decomposed: exact.
    let r = unicode_to_ewts("\u{0F42}\u{0FB7}");
    assert_eq!(r.fidelity, Fidelity::Exact);
    assert!(r.diagnostics.is_empty());

    // Vocalic r (U+0F76) after ka.
    let r = unicode_to_ewts("\u{0F40}\u{0F76}");
    assert_eq!(r.text, "kr-i");
    assert_eq!(r.fidelity, Fidelity::Canonical);

    // Marks out of canonical order.
    let r = unicode_to_ewts("\u{0F40}\u{0F71}\u{0F84}");
    assert_eq!(r.fidelity, Fidelity::Canonical);
    assert!(r
        .diagnostics
        .iter()
        .any(|d| d.code == Code::ReverseNonCanonicalInput));
}

#[test]
fn guessed_roots_are_reported() {
    // No vowel sign says which of d and g is the root.
    let r = unicode_to_ewts("དག");
    assert_eq!(r.text, "dag");
    let d = r
        .diagnostics
        .iter()
        .find(|d| d.code == Code::ReverseAmbiguousRoot)
        .expect("ambiguous root");
    assert_eq!(d.span, 0..6);
    assert_eq!(r.fidelity, Fidelity::Exact);

    // With a vowel sign or a standard stack there is nothing to guess.
    for unicode in ["བོད", "སྐད", "བརྒྱད", "གསུམ"] {
        assert!(
            unicode_to_ewts(unicode)
                .diagnostics
                .iter()
                .all(|d| d.code != Code::ReverseAmbiguousRoot),
            "{unicode}"
        );
    }
}

#[test]
fn spans_are_utf8_byte_offsets_into_the_input() {
    let input = "é\u{0F01}";
    let r = unicode_to_ewts(input);
    assert_eq!(r.diagnostics[0].span, 2..5);
    assert_eq!(&input[r.diagnostics[0].span.clone()], "\u{0F01}");
}

#[test]
fn empty_input() {
    let r = unicode_to_ewts("");
    assert_eq!((r.text.as_str(), r.fidelity), ("", Fidelity::Exact));
    assert!(r.diagnostics.is_empty());
}

#[test]
fn reverse_output_converts_without_warnings() {
    for unicode in ["བོད་སྐད་", "བཀྲ་ཤིས་བདེ་ལེགས།", "ཀྵ", "\u{0F01}"]
    {
        let r = unicode_to_ewts(unicode);
        let c = convert(&r.text, Options::default());
        assert!(
            c.diagnostics
                .iter()
                .all(|d| d.severity == ttime_core::Severity::Info),
            "{unicode} -> {} -> {:?}",
            r.text,
            c.diagnostics
        );
    }
}
