#![no_main]
use libfuzzer_sys::fuzz_target;
use ttime_core::{convert, Options};

include!("common.rs");

// Bytes pick characters from the ones that stress error paths.
const ALPHABET: &[&str] = &[
    "+", ".", "~", "[", "]", "\\", "u", "U", "0", "F", "4", "D", "8", "-", "_", " ", "/", "M",
    "H", "X", "^", "?", "&", "a", "i", "k", "g", "r", "y", "w", "s", "'", "oM", "~M", "~M`",
    "\\u0F40", "\\U00000F40", "ཀ", "\u{0F71}", "\u{0F7E}",
];

fuzz_target!(|data: &[u8]| {
    if data.len() > 512 {
        return;
    }
    let s: String = data.iter().map(|b| ALPHABET[*b as usize % ALPHABET.len()]).collect();
    let c = convert(&s, Options::default());
    check_spans(&s, &c.diagnostics);
});
