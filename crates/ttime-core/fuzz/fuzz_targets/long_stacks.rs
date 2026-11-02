#![no_main]
use libfuzzer_sys::fuzz_target;
use ttime_core::{convert, ewts_to_unicode, unicode_to_ewts, Fidelity, Options};

include!("common.rs");

const LETTERS: &[&str] = &[
    "k", "kh", "g", "ng", "c", "j", "ny", "t", "d", "n", "p", "b", "m", "ts", "dz", "w", "z",
    "'", "y", "r", "l", "sh", "s", "h", "T", "gh", "R", "W", "Y",
];
const VOWELS: &[&str] = &["", "a", "i", "u", "e", "o", "A", "ai", "au", "-i", "M"];

fuzz_target!(|data: &[u8]| {
    if data.len() > 200 {
        return;
    }
    // Pairs of bytes: (letter, joiner-or-vowel). Stacks up to 200 deep.
    let mut s = String::new();
    for pair in data.chunks(2) {
        s.push_str(LETTERS[pair[0] as usize % LETTERS.len()]);
        match pair.get(1).copied().unwrap_or(0) % 4 {
            0 => s.push('+'),
            1 => s.push_str(VOWELS[pair[1] as usize / 4 % VOWELS.len()]),
            2 => s.push('.'),
            _ => {}
        }
    }
    let c = convert(&s, Options::default());
    check_spans(&s, &c.diagnostics);
    let r = unicode_to_ewts(&c.text);
    if r.fidelity == Fidelity::Exact {
        assert_eq!(ewts_to_unicode(&r.text), c.text);
    }
});
