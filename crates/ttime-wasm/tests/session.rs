//! The commit policy must never change what the text converts to.

use ttime_core::{ewts_to_unicode_with, Options};
use ttime_wasm::{convert_json, reverse_json, Session};

fn rng(seed: &mut u64) -> u64 {
    *seed ^= *seed << 13;
    *seed ^= *seed >> 7;
    *seed ^= *seed << 17;
    *seed
}

fn feed(s: &mut Session, text: &str) {
    s.insert_text(text);
}

#[test]
fn committing_at_spaces_equals_whole_string_conversion() {
    let alphabet: Vec<char> = "kgyrlsabdmn'+.~[]\\ _/MHiueo -0123uU\n".chars().collect();
    let mut seed = 0x9E3779B97F4A7C15u64;
    for round in 0..20_000 {
        let len = (rng(&mut seed) % 24) as usize;
        let text: String = (0..len)
            .map(|_| alphabet[(rng(&mut seed) % alphabet.len() as u64) as usize])
            .collect();
        for precomposed in [false, true] {
            let mut s = Session::new(precomposed, None);
            feed(&mut s, &text);
            let got = s.finish();
            let want = ewts_to_unicode_with(
                &text,
                Options {
                    precomposed,
                    diplomatic: false,
                },
            );
            assert_eq!(got, want, "round {round}: {text:?}");
        }
    }
}

#[test]
fn provisional_changes_but_committed_does_not() {
    let mut s = Session::new(false, None);
    s.insert_text("g");
    assert_eq!(s.provisional(), "ག");
    s.insert_text("ya");
    assert_eq!(s.provisional(), "གྱ");
    assert_eq!(s.committed(), "");
    s.insert_text(" ");
    assert_eq!(s.committed(), "གྱ་");
    assert_eq!(s.provisional(), "");
    s.insert_text("k");
    assert_eq!(s.committed(), "གྱ་");
}

#[test]
fn backspace_edits_only_provisional_text() {
    let mut s = Session::new(false, None);
    s.insert_text("ka ");
    assert!(!s.backspace());
    assert_eq!(s.committed(), "ཀ་");
    s.insert_text("kh");
    assert!(s.backspace());
    assert_eq!(s.provisional(), "ཀ");
}

#[test]
fn set_committed_replaces_text_and_clears_provisional() {
    let mut s = Session::new(false, None);
    s.insert_text("ka kh");
    s.set_committed("abc");
    assert_eq!(s.committed(), "abc");
    assert_eq!(s.provisional(), "");
    assert_eq!(s.raw(), "");
}

#[test]
fn json_is_valid_for_awkward_text() {
    let j = convert_json("\"q\\\n[x", false);
    assert!(j.starts_with("{\"text\":\""));
    assert!(j.contains("\"diagnostics\":["));
    assert!(!j.contains('\n'));
}

#[test]
fn reverse_json_reports_fidelity() {
    let j = reverse_json("བོད་སྐད");
    assert!(j.contains("\"text\":\"bod skad\""), "{j}");
    assert!(j.contains("\"fidelity\":\"Exact\""), "{j}");
}

#[test]
fn symbol_search_json_is_shaped_for_the_palette() {
    let all = ttime_wasm::search_symbols_json("");
    assert!(all.starts_with("[{\"id\":"));
    assert!(all.contains("\"codePoints\":\"U+0F0D\""), "{all}");
    let one = ttime_wasm::search_symbols_json("double shad");
    assert!(one.contains("\"id\":\"nyis-shad\""), "{one}");
    assert!(!one.contains("\"id\":\"shad\""), "{one}");
    assert_eq!(ttime_wasm::search_symbols_json("zzzzqq"), "[]");
    assert!(ttime_wasm::symbol_categories_json().starts_with("[\"punctuation\""));
}

#[test]
fn diplomatic_session_reports_a_dropped_a_without_changing_text() {
    let mut s = Session::new(false, Some(true));
    assert!(s.diplomatic());
    s.insert_text("kaa");
    assert!(s.diagnostics_json().contains("ewts.dropped-input"));
    assert_eq!(s.finish(), ewts_to_unicode_with("kaa", Options::default()));
    let mut plain = Session::new(false, None);
    plain.insert_text("kaa");
    assert!(!plain.diagnostics_json().contains("ewts.dropped-input"));
}

#[test]
fn convert_json_with_diplomatic_warns() {
    let j = ttime_wasm::convert_json_with("oM", false, true);
    assert!(
        j.contains("ewts.om-syllable") && j.contains("Warning"),
        "{j}"
    );
    assert!(!ttime_wasm::convert_json("oM", false).contains("ewts.om-syllable"));
}
