#![no_main]
use libfuzzer_sys::fuzz_target;
use ttime_core::{ewts_to_unicode, unicode_to_ewts, Fidelity};

include!("common.rs");

// Arbitrary Tibetan-block text: every sequence of letters, subjoined letters,
// vowel signs and marks in any order.
fuzz_target!(|data: &[u8]| {
    if data.len() > 400 {
        return;
    }
    let s: String = data
        .chunks(2)
        .filter_map(|p| {
            let n = ((p[0] as u32) << 8 | *p.get(1).unwrap_or(&0) as u32) % 0x100;
            char::from_u32(0x0F00 + n)
        })
        .collect();
    let r = unicode_to_ewts(&s);
    check_spans(&s, &r.diagnostics);
    if r.fidelity == Fidelity::Exact {
        assert_eq!(ewts_to_unicode(&r.text), s);
    }
});
