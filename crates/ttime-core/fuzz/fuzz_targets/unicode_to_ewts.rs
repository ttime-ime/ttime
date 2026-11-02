#![no_main]
use libfuzzer_sys::fuzz_target;
use ttime_core::{ewts_to_unicode, unicode_to_ewts, Fidelity};

include!("common.rs");

fuzz_target!(|data: &str| {
    if data.len() > MAX_INPUT_BYTES {
        return;
    }
    let r = unicode_to_ewts(data);
    check_spans(data, &r.diagnostics);
    if r.fidelity == Fidelity::Exact {
        assert_eq!(ewts_to_unicode(&r.text), data, "exact claim broken: {:?}", r.text);
    }
});
