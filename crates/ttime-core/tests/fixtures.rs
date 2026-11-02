//! Data-driven tests: every `tests/fixtures/*.tsv` line is `EWTS<TAB>expected`.
//! Expected text may contain `\uXXXX` escapes. Lines starting with `#` and
//! blank lines are ignored.

use std::fs;
use std::path::Path;

use ttime_core::{ewts_to_unicode_with, Options};

fn unescape(s: &str) -> String {
    let mut out = String::new();
    let mut rest = s;
    while let Some(pos) = rest.find("\\u") {
        out.push_str(&rest[..pos]);
        let hex = &rest[pos + 2..pos + 6];
        let cp = u32::from_str_radix(hex, 16).expect("bad \\u escape in fixture");
        out.push(char::from_u32(cp).expect("bad code point in fixture"));
        rest = &rest[pos + 6..];
    }
    out.push_str(rest);
    out
}

fn show(s: &str) -> String {
    s.chars()
        .map(|c| format!("U+{:04X}", c as u32))
        .collect::<Vec<_>>()
        .join(" ")
}

fn run(file: &str, options: Options) -> usize {
    let path = Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("tests/fixtures")
        .join(file);
    let text = fs::read_to_string(&path).unwrap_or_else(|e| panic!("{}: {e}", path.display()));
    let mut failures = Vec::new();
    let mut checked = 0;

    for (n, line) in text.lines().enumerate() {
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        let (input, expected) = line
            .split_once('\t')
            .unwrap_or_else(|| panic!("{file}:{}: missing tab", n + 1));
        let expected = unescape(expected);
        let got = ewts_to_unicode_with(input, options);
        checked += 1;
        if got != expected {
            failures.push(format!(
                "{file}:{}: {input:?}\n    expected {}\n    got      {}",
                n + 1,
                show(&expected),
                show(&got)
            ));
        }
    }

    assert!(
        failures.is_empty(),
        "{} of {checked} failed:\n{}",
        failures.len(),
        failures.join("\n")
    );
    checked
}

fn default_mode(file: &str) {
    let n = run(file, Options::default());
    assert!(n > 0, "{file} had no cases");
}

#[test]
fn words() {
    default_mode("words.tsv");
}

#[test]
fn alphabet_and_vowels() {
    default_mode("alphabet.tsv");
}

#[test]
fn stacks() {
    default_mode("stacks.tsv");
}

#[test]
fn syllable_structure() {
    default_mode("syllables.tsv");
}

#[test]
fn sanskrit_and_marks() {
    default_mode("sanskrit.tsv");
}

#[test]
fn punctuation_digits_escapes() {
    default_mode("punctuation.tsv");
}

#[test]
fn corpus_agreed_with_pyewts() {
    default_mode("corpus.tsv");
}

#[test]
fn thl_rules_via_ewts_rs() {
    default_mode("thl_rules.tsv");
}

#[test]
fn robustness_characterization() {
    default_mode("robustness.tsv");
}

#[test]
fn known_deviations_are_pinned() {
    default_mode("deviations.tsv");
}

#[test]
fn at_least_five_hundred_curated_cases() {
    let dir = Path::new(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures");
    let total: usize = fs::read_dir(dir)
        .unwrap()
        .map(|e| e.unwrap().path())
        .filter(|p| p.extension().is_some_and(|x| x == "tsv"))
        .map(|p| {
            fs::read_to_string(p)
                .unwrap()
                .lines()
                .filter(|l| !l.is_empty() && !l.starts_with('#'))
                .count()
        })
        .sum();
    assert!(total >= 500, "only {total} curated cases");
}

#[test]
fn precomposed_option() {
    let n = run("precomposed.tsv", Options { precomposed: true, diplomatic: false });
    assert!(n > 0);
}
