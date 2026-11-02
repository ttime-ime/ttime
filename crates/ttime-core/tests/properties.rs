//! Property and robustness tests with a small deterministic generator, so
//! failures reproduce and no extra dependencies are needed.

use ttime_core::{
    convert, ewts_to_unicode, ewts_to_unicode_with, unicode_to_ewts, Engine, Fidelity, Options,
};

const PRECOMPOSED: Options = Options {
    precomposed: true,
    diplomatic: false,
};

struct Rng(u64);

impl Rng {
    fn next(&mut self) -> u64 {
        // xorshift64*
        self.0 ^= self.0 >> 12;
        self.0 ^= self.0 << 25;
        self.0 ^= self.0 >> 27;
        self.0.wrapping_mul(0x2545_F491_4F6C_DD1D)
    }

    fn below(&mut self, n: usize) -> usize {
        (self.next() % n as u64) as usize
    }
}

/// Every token the converter understands as a letter, vowel or mark.
const TOKENS: &[&str] = &[
    "k", "kh", "g", "ng", "c", "ch", "j", "ny", "t", "th", "d", "n", "p", "ph", "b", "m", "ts",
    "tsh", "dz", "w", "zh", "z", "'", "y", "r", "l", "sh", "s", "h", "T", "Th", "D", "N", "Sh",
    "gh", "dh", "bh", "dzh", "Dh", "f", "v", "R", "a", "i", "u", "e", "o", "A", "I", "U", "ai",
    "au", "-i", "-I", "uo", "ui", "ue", "M", "H", "~M", "~M`", "~X", "X", "^", "?", "&", " ", "+",
    "-", ".", "/", "//", "_", "0", "5", "9",
];

fn random_tokens(rng: &mut Rng, max: usize) -> String {
    (0..rng.below(max + 1))
        .map(|_| TOKENS[rng.below(TOKENS.len())])
        .collect()
}

fn fixture_words() -> Vec<(String, String)> {
    let text = include_str!("fixtures/words.tsv");
    text.lines()
        .filter(|l| !l.is_empty() && !l.starts_with('#'))
        .map(|l| {
            let (a, b) = l.split_once('\t').unwrap();
            (a.to_string(), b.to_string())
        })
        .collect()
}

/// Reverse of the converter's precomposition table.
fn decompose(text: &str) -> String {
    const PAIRS: &[(char, &str)] = &[
        ('\u{0F69}', "\u{0F40}\u{0FB5}"),
        ('\u{0F43}', "\u{0F42}\u{0FB7}"),
        ('\u{0F4D}', "\u{0F4C}\u{0FB7}"),
        ('\u{0F52}', "\u{0F51}\u{0FB7}"),
        ('\u{0F57}', "\u{0F56}\u{0FB7}"),
        ('\u{0F5C}', "\u{0F5B}\u{0FB7}"),
        ('\u{0FB9}', "\u{0F90}\u{0FB5}"),
        ('\u{0F93}', "\u{0F92}\u{0FB7}"),
        ('\u{0F9D}', "\u{0F9C}\u{0FB7}"),
        ('\u{0FA2}', "\u{0FA1}\u{0FB7}"),
        ('\u{0FA7}', "\u{0FA6}\u{0FB7}"),
        ('\u{0FAC}', "\u{0FAB}\u{0FB7}"),
        ('\u{0F73}', "\u{0F71}\u{0F72}"),
        ('\u{0F75}', "\u{0F71}\u{0F74}"),
        ('\u{0F81}', "\u{0F71}\u{0F80}"),
        ('\u{0F76}', "\u{0FB2}\u{0F80}"),
        ('\u{0F78}', "\u{0FB3}\u{0F80}"),
    ];
    text.chars()
        .map(|c| {
            PAIRS
                .iter()
                .find(|(p, _)| *p == c)
                .map_or(c.to_string(), |(_, d)| d.to_string())
        })
        .collect()
}

/// Combining class of the Tibetan marks (Unicode Character Database).
fn ccc(c: char) -> u8 {
    match c {
        '\u{0F84}' => 9,
        '\u{0F71}' => 129,
        '\u{0F72}' | '\u{0F7A}'..='\u{0F7D}' | '\u{0F80}' => 130,
        '\u{0F74}' => 132,
        '\u{0F39}' => 216,
        '\u{0F18}' | '\u{0F19}' | '\u{0F35}' | '\u{0F37}' | '\u{0FC6}' => 220,
        '\u{0F82}' | '\u{0F83}' | '\u{0F86}' | '\u{0F87}' => 230,
        _ => 0,
    }
}

/// Canonical ordering of combining marks, so two canonically equivalent
/// strings compare equal.
fn canonical_sort(text: &str) -> String {
    let mut chars: Vec<char> = text.chars().collect();
    let mut i = 0;
    while i < chars.len() {
        if ccc(chars[i]) == 0 {
            i += 1;
            continue;
        }
        let mut j = i;
        while j < chars.len() && ccc(chars[j]) > 0 {
            j += 1;
        }
        chars[i..j].sort_by_key(|&c| ccc(c));
        i = j;
    }
    chars.into_iter().collect()
}

#[test]
fn never_panics_on_arbitrary_text() {
    let mut rng = Rng(0x9E37_79B9_7F4A_7C15);
    for _ in 0..30_000 {
        let len = rng.below(40);
        let s: String = (0..len)
            .map(|_| match rng.below(4) {
                0 => char::from_u32(0x20 + rng.below(0x5F) as u32).unwrap(),
                1 => char::from_u32(0x0F00 + rng.below(0x100) as u32).unwrap(),
                2 => ['\n', '\t', '\\', '[', ']', 'é', '中', '😀'][rng.below(8)],
                _ => TOKENS[rng.below(TOKENS.len())].chars().next().unwrap(),
            })
            .collect();
        let _ = ewts_to_unicode(&s);
        let _ = ewts_to_unicode_with(&s, PRECOMPOSED);
    }
}

#[test]
fn never_panics_on_every_prefix_of_tricky_input() {
    for s in [
        "\\u0F4", "\\U0000", "[", "]", "\\", "+", "++k", "k+", "k+ ", "-", "--", "-1-", "oM", "~M",
        "~", "k~",
    ] {
        for end in (0..=s.len()).filter(|&e| s.is_char_boundary(e)) {
            let _ = ewts_to_unicode(&s[..end]);
        }
    }
}

#[test]
fn empty_input_gives_empty_output() {
    assert_eq!(ewts_to_unicode(""), "");
}

#[test]
fn tibetan_text_passes_through_unchanged() {
    let mut rng = Rng(42);
    for _ in 0..2_000 {
        let s: String = (0..rng.below(30))
            .map(|_| char::from_u32(0x0F00 + rng.below(0x100) as u32).unwrap())
            .collect();
        assert_eq!(ewts_to_unicode(&s), s);
        assert_eq!(ewts_to_unicode_with(&s, PRECOMPOSED), s);
    }
}

#[test]
fn token_input_yields_only_tibetan_block_characters() {
    let mut rng = Rng(7);
    for _ in 0..20_000 {
        let s = random_tokens(&mut rng, 25);
        for options in [Options::default(), PRECOMPOSED] {
            let out = ewts_to_unicode_with(&s, options);
            assert!(
                out.chars().all(|c| ('\u{0F00}'..='\u{0FFF}').contains(&c)
                    || matches!(c, ' ' | '-' | '+' | '.')),
                "{s:?} -> {out:?}"
            );
        }
    }
}

#[test]
fn precomposed_output_is_canonically_equivalent_to_default_output() {
    let mut rng = Rng(1234);
    for _ in 0..20_000 {
        let s = random_tokens(&mut rng, 25);
        let default = ewts_to_unicode(&s);
        let pre = ewts_to_unicode_with(&s, PRECOMPOSED);
        assert_eq!(
            canonical_sort(&decompose(&pre)),
            canonical_sort(&default),
            "{s:?}"
        );
    }
}

#[test]
fn spaces_join_syllables_with_tsheg() {
    let words = fixture_words();
    let mut rng = Rng(99);
    for _ in 0..2_000 {
        let (a, ea) = &words[rng.below(words.len())];
        let (b, eb) = &words[rng.below(words.len())];
        assert_eq!(
            ewts_to_unicode(&format!("{a} {b}")),
            format!("{ea}\u{0F0B}{eb}")
        );
    }
}

#[test]
fn underscore_joins_with_a_real_space() {
    let words = fixture_words();
    let mut rng = Rng(5);
    for _ in 0..500 {
        let (a, ea) = &words[rng.below(words.len())];
        let (b, eb) = &words[rng.below(words.len())];
        assert_eq!(ewts_to_unicode(&format!("{a}_{b}")), format!("{ea} {eb}"));
    }
}

#[test]
fn engine_preedit_matches_whole_string_conversion_at_every_step() {
    for (ewts, _) in fixture_words() {
        let mut engine = Engine::new();
        let mut typed = String::new();
        for c in ewts.chars() {
            engine.push(c);
            typed.push(c);
            assert_eq!(engine.preedit(), ewts_to_unicode(&typed), "{typed:?}");
            assert_eq!(engine.raw(), typed);
        }
        assert_eq!(engine.commit(), ewts_to_unicode(&ewts));
        assert!(engine.is_empty());
    }
}

#[test]
fn engine_backspace_undoes_push() {
    let mut rng = Rng(31);
    for _ in 0..2_000 {
        let s = random_tokens(&mut rng, 20);
        let mut engine = Engine::new();
        for c in s.chars() {
            engine.push(c);
        }
        let before = engine.preedit();
        engine.push('k');
        assert!(engine.backspace());
        assert_eq!(engine.preedit(), before);
    }
}

#[test]
fn no_fixture_word_starts_with_a_combining_character() {
    // No bare combining vowel or subjoined letter may start a word.
    for (ewts, expected) in fixture_words() {
        let first = expected.chars().next().unwrap();
        assert!(
            !('\u{0F71}'..='\u{0F84}').contains(&first)
                && !('\u{0F90}'..='\u{0FBC}').contains(&first),
            "{ewts:?} starts with a combining character"
        );
    }
}

#[test]
fn diagnostic_spans_are_valid_sorted_and_do_not_change_text() {
    let mut rng = Rng(0xD1A6);
    for _ in 0..20_000 {
        let mut s = random_tokens(&mut rng, 20);
        // Mix in multi-byte text, escapes and brackets.
        for extra in ["é", "中", "ཀ", "\\u0F4", "[", "~", "q"] {
            if rng.below(6) == 0 {
                let at = (0..=s.len())
                    .rev()
                    .find(|&i| s.is_char_boundary(i) && rng.below(3) == 0)
                    .unwrap_or(0);
                s.insert_str(at, extra);
            }
        }
        let c = convert(&s, Options::default());
        assert_eq!(c.text, ewts_to_unicode(&s), "{s:?}");
        let mut last = 0;
        for d in &c.diagnostics {
            assert!(
                d.span.start <= d.span.end && d.span.end <= s.len(),
                "{s:?} {d:?}"
            );
            assert!(
                s.is_char_boundary(d.span.start) && s.is_char_boundary(d.span.end),
                "{s:?} {d:?}"
            );
            assert!(d.span.start >= last, "{s:?} not sorted");
            assert!(!d.message.is_empty());
            last = d.span.start;
        }
    }
}

#[test]
fn engine_exposes_diagnostics_for_the_raw_buffer() {
    let mut e = Engine::new();
    e.push('k');
    e.push('+');
    let d = e.diagnostics();
    assert_eq!(d.len(), 1);
    assert_eq!(d[0].span, 1..2);
    e.push('y');
    assert!(e.diagnostics().is_empty());
}

#[test]
fn forward_reverse_forward_is_stable() {
    // Whatever the converter produced can be written back as EWTS that
    // converts to exactly the same text.
    let mut rng = Rng(0xFACE);
    let mut failures = Vec::new();
    for _ in 0..30_000 {
        let ewts = random_tokens(&mut rng, 20);
        let unicode = ewts_to_unicode(&ewts);
        let r = unicode_to_ewts(&unicode);
        let back = ewts_to_unicode(&r.text);
        if back != unicode || r.fidelity != Fidelity::Exact {
            failures.push(format!(
                "{ewts:?} -> {unicode:?} -> {:?} -> {back:?} ({:?})",
                r.text, r.fidelity
            ));
        }
    }
    assert!(
        failures.is_empty(),
        "{} failures, first few:\n{}",
        failures.len(),
        failures
            .iter()
            .take(15)
            .cloned()
            .collect::<Vec<_>>()
            .join("\n")
    );
}

#[test]
fn reverse_never_loses_text_for_arbitrary_tibetan_block_input() {
    let mut rng = Rng(0xBEEF);
    let mut lossy = Vec::new();
    for _ in 0..30_000 {
        let s: String = (0..rng.below(14))
            .map(|_| match rng.below(8) {
                0 => char::from_u32(0x0F00 + rng.below(0x100) as u32).unwrap(),
                1 => ['a', ']', '[', 'é', ' ', '\n', '\\'][rng.below(7)],
                _ => char::from_u32(0x0F40 + rng.below(0x40) as u32).unwrap(),
            })
            .collect();
        let r = unicode_to_ewts(&s);
        if r.fidelity == Fidelity::Lossy {
            lossy.push(format!("{s:?} -> {:?}", r.text));
        }
        for d in &r.diagnostics {
            assert!(
                d.span.end <= s.len()
                    && s.is_char_boundary(d.span.start)
                    && s.is_char_boundary(d.span.end),
                "{s:?} {d:?}"
            );
        }
    }
    assert!(
        lossy.is_empty(),
        "{} lossy, first few:\n{}",
        lossy.len(),
        lossy
            .iter()
            .take(15)
            .cloned()
            .collect::<Vec<_>>()
            .join("\n")
    );
}
