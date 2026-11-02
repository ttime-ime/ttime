#![no_main]
use libfuzzer_sys::fuzz_target;
use ttime_core::{convert, Options};

include!("common.rs");

fuzz_target!(|data: &str| {
    if data.len() > MAX_INPUT_BYTES {
        return;
    }
    for precomposed in [false, true] {
        let c = convert(data, Options { precomposed });
        check_spans(data, &c.diagnostics);
        // Diagnostics never change the text.
        assert_eq!(c.text, ttime_core::ewts_to_unicode_with(data, Options { precomposed }));
    }
});
