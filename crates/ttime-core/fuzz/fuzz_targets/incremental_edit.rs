#![no_main]
use libfuzzer_sys::fuzz_target;
use ttime_core::{ewts_to_unicode_with, Engine, Options};

const KEYS: &[char] = &[
    'k', 'g', 'r', 'y', 'a', 'i', 'o', 's', 'b', '+', '.', '~', 'M', ' ', '[', ']', '\\', 'u',
    '0', 'F', '-', '_', '/', 'n', 'g',
];

// Byte 0..=15: backspace; otherwise a typed key. Mix of repeated insert/delete.
fuzz_target!(|data: &[u8]| {
    if data.len() > 1024 {
        return;
    }
    let mut e = Engine::new();
    let mut model = String::new();
    for &b in data {
        if b < 16 {
            let had = !model.is_empty();
            assert_eq!(e.backspace(), had);
            model.pop();
        } else {
            let c = KEYS[b as usize % KEYS.len()];
            e.push(c);
            model.push(c);
        }
        assert_eq!(e.raw(), model);
        assert_eq!(e.preedit(), ewts_to_unicode_with(&model, Options::default()));
    }
    let committed = e.commit();
    assert_eq!(committed, ewts_to_unicode_with(&model, Options::default()));
    assert!(e.is_empty());
});
