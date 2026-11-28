//! Composer behaviour, ported from the macOS shell's key-policy tests so every
//! platform shell inherits the same guarantees.

use super::composer::Composer;
use super::key::{KeyInput, Outcome};
use super::sanskrit::SanskritLexicon;
use std::sync::Arc;

use KeyInput::{Backspace, Down, Enter, Escape, Other, Right, Tab};

fn text(s: &str) -> KeyInput {
    KeyInput::Text(s.to_string())
}

fn out(insert: &str, marked: &str, replacing: &str, handled: bool) -> Outcome {
    Outcome {
        insert: insert.into(),
        marked: marked.into(),
        replacing: replacing.into(),
        handled,
    }
}

fn handled() -> Outcome {
    Outcome::handled_only()
}

fn passed() -> Outcome {
    Outcome::default()
}

/// Types `s` key by key; the result is the last outcome with every insert joined.
fn typed(c: &mut Composer, s: &str) -> Outcome {
    let mut last = Outcome::default();
    let mut inserted = String::new();
    for ch in s.chars() {
        last = c.handle(text(&ch.to_string()), false);
        inserted.push_str(&last.insert);
    }
    last.insert = inserted;
    last
}

/// Types `s` key by key and returns only the last outcome.
fn type_last(c: &mut Composer, s: &str) -> Outcome {
    let mut last = Outcome::default();
    for ch in s.chars() {
        last = c.handle(text(&ch.to_string()), false);
    }
    last
}

fn hold(c: &mut Composer, s: &str) -> Outcome {
    c.handle(text(s), true)
}

const SAMPLE: &str = "prajñā\t100\tb\nprajña\t10\t-\nprājña\t5\t-\npratītyasamutpāda\t20\tb\npratyaya\t50\tb\nśiva\t80\t-\nśivā\t3\t-\nsiva\t1\t-\nśūnyatā\t40\tb\n";
const ACCENT_SAMPLE: &str = "prajñā\t100\tb\nprajña\t10\t-\nsūtra\t30\tb\n";

fn latin(tsv: Option<&str>, accents: bool) -> Composer {
    let mut c = Composer::new(false);
    let _ = c.set_latin(true);
    c.set_accents(accents);
    c.set_lexicon(tsv.map(|t| Arc::new(SanskritLexicon::from_tsv(t))));
    c
}

// --- Tibetan ---

#[test]
fn provisional_and_space_commit() {
    let mut c = Composer::new(false);
    assert_eq!(typed(&mut c, "bkra"), out("", "བཀྲ", "", true));
    assert_eq!(c.handle(text(" "), false), out("བཀྲ་", "", "", true));
}

#[test]
fn backspace_edits_then_passes_through() {
    let mut c = Composer::new(false);
    typed(&mut c, "kh");
    assert_eq!(c.handle(Backspace, false), out("", "ཀ", "", true));
    assert_eq!(c.handle(Backspace, false), out("", "", "", true));
    assert_eq!(c.handle(Backspace, false), passed());
}

#[test]
fn escape_and_return() {
    let mut c = Composer::new(false);
    assert_eq!(c.handle(Escape, false), passed(), "escape with nothing");
    typed(&mut c, "ka");
    assert_eq!(c.handle(Escape, false), handled(), "escape cancels");
    assert_eq!(c.handle(Enter, false), passed(), "return with nothing");
    typed(&mut c, "ka");
    assert_eq!(
        c.handle(Enter, false),
        out("ཀ", "", "", false),
        "return commits, passes"
    );
}

#[test]
fn other_keys_commit_then_pass() {
    let mut c = Composer::new(false);
    typed(&mut c, "ka");
    assert_eq!(c.handle(Other, false), out("ཀ", "", "", false));
    assert_eq!(c.handle(Other, false), passed());
}

#[test]
fn space_inside_brackets_stays_provisional() {
    let mut c = Composer::new(false);
    typed(&mut c, "[a b");
    let o = c.handle(text(" "), false);
    assert!(o.insert.is_empty() && o.handled, "{o:?}");
}

#[test]
fn four_syllables() {
    let mut c = Composer::new(false);
    let all: String = ["bkra", "shis", "bde", "legs"]
        .iter()
        .map(|w| typed(&mut c, &format!("{w} ")).insert)
        .collect();
    assert_eq!(all, "བཀྲ་ཤིས་བདེ་ལེགས་");
}

#[test]
fn reset_forgets_pending_input() {
    let mut c = Composer::new(false);
    typed(&mut c, "ka");
    c.reset();
    assert_eq!(c.handle(Enter, false), passed());
}

#[test]
fn latin_mode() {
    let mut c = Composer::new(false);
    typed(&mut c, "ka");
    assert_eq!(c.set_latin(true), out("ཀ", "", "", true));
    assert!(c.is_latin());
    assert_eq!(typed(&mut c, "ka "), out("ka ", "", "", true));
    assert_eq!(c.set_latin(false), handled());
    assert_eq!(typed(&mut c, "ka "), out("ཀ་", "", "", true));
}

#[test]
fn set_precomposed_keeps_latin() {
    let mut c = Composer::new(false);
    let _ = c.set_latin(true);
    c.set_precomposed(true);
    assert!(c.is_latin() && c.precomposed());
}

// --- Sanskrit suggestions ---

#[test]
fn suggestions_replace_the_typed_word() {
    let mut c = latin(Some(SAMPLE), false);
    assert_eq!(
        type_last(&mut c, "pr"),
        out("r", "", "", true),
        "no marked text"
    );
    assert!(c.suggestion_list().is_none(), "no list under three letters");
    type_last(&mut c, "aj");
    assert_eq!(c.suggestion_list().unwrap().0[0], "prajñā");
    assert_eq!(c.handle(Tab, false), out("prajñā", "", "praj", true));
    assert!(c.suggestion_list().is_none(), "list gone after accepting");
}

#[test]
fn down_then_tab_accepts_the_selected_one() {
    let mut c = latin(Some(SAMPLE), false);
    type_last(&mut c, "praj");
    assert_eq!(c.handle(Down, false), handled());
    assert_eq!(c.suggestion_list().unwrap().1, 1);
    assert_eq!(c.handle(Tab, false), out("prajña", "", "praj", true));
}

#[test]
fn space_keeps_what_was_typed() {
    let mut c = latin(Some(SAMPLE), false);
    type_last(&mut c, "siva");
    assert_eq!(c.handle(text(" "), false), out(" ", "", "", true));
}

#[test]
fn capital_kept() {
    let mut c = latin(Some(SAMPLE), false);
    type_last(&mut c, "Praj");
    assert_eq!(c.handle(Tab, false), out("Prajñā", "", "Praj", true));
}

#[test]
fn backspace_and_escape_while_suggesting() {
    let mut c = latin(Some(SAMPLE), false);
    type_last(&mut c, "praj");
    assert_eq!(
        c.handle(Backspace, false),
        passed(),
        "left to the application"
    );
    assert_eq!(c.suggestion_buffer(), "pra", "the copy follows");
    assert_eq!(
        c.handle(Escape, false),
        handled(),
        "escape keeps the typed text"
    );
}

#[test]
fn keys_that_end_the_word() {
    let mut c = latin(Some(SAMPLE), false);
    type_last(&mut c, "pr");
    assert_eq!(c.handle(Tab, false), passed(), "tab with no list");
    type_last(&mut c, "praj");
    assert_eq!(c.handle(Enter, false), passed(), "return passes through");
    type_last(&mut c, "praj");
    assert_eq!(
        c.handle(text("1"), false),
        out("1", "", "", true),
        "digit ends the word"
    );
    type_last(&mut c, "praj");
    assert_eq!(
        c.set_latin(false),
        handled(),
        "leaving Latin forgets the word"
    );
}

#[test]
fn tab_with_no_word_is_not_ours() {
    let mut c = latin(Some(SAMPLE), false);
    assert_eq!(c.handle(Tab, false), passed());
    let mut off = latin(None, false);
    assert_eq!(type_last(&mut off, "a"), out("a", "", "", true));
}

#[test]
fn click_on_a_suggestion() {
    let mut c = latin(Some(SAMPLE), false);
    assert_eq!(c.choose_suggestion(0), passed(), "no list");
    type_last(&mut c, "praj");
    assert_eq!(c.choose_suggestion(1), out("prajña", "", "praj", true));
    assert!(c.suggestion_list().is_none());
}

#[test]
fn one_lexicon_serves_many_composers() {
    let lex = Arc::new(SanskritLexicon::from_tsv(SAMPLE));
    let mut a = Composer::new(false);
    let mut b = Composer::new(false);
    let _ = a.set_latin(true);
    let _ = b.set_latin(true);
    a.set_lexicon(Some(Arc::clone(&lex)));
    b.set_lexicon(Some(Arc::clone(&lex)));
    assert_eq!(Arc::strong_count(&lex), 3);
    type_last(&mut a, "praj");
    assert!(a.suggestion_list().is_some());
    assert!(b.suggestion_list().is_none(), "state is per composer");
}

// --- Accent palette, with suggestions ---

#[test]
fn hold_opens_and_number_picks() {
    let mut c = latin(Some(ACCENT_SAMPLE), true);
    type_last(&mut c, "pra");
    assert_eq!(hold(&mut c, "a"), handled(), "first repeat opens");
    assert_eq!(c.accent_list(), Some((vec!["ā".to_string()], None)));
    assert_eq!(
        hold(&mut c, "a"),
        handled(),
        "further repeats are swallowed"
    );
    assert_eq!(c.handle(text("1"), false), out("ā", "", "a", true));
    assert!(c.accent_list().is_none());
    assert_eq!(c.handle(text("j"), false).insert, "j");
    assert_eq!(
        c.suggestion_buffer(),
        "prāj",
        "typing goes on after the accent"
    );
}

#[test]
fn arrows_and_return_pick() {
    let mut c = latin(Some(ACCENT_SAMPLE), true);
    type_last(&mut c, "pr");
    hold(&mut c, "r");
    assert_eq!(c.accent_list().unwrap().0, vec!["ṛ", "ṝ"]);
    c.handle(Right, false);
    c.handle(Right, false);
    assert_eq!(c.accent_list().unwrap().1, Some(1));
    assert_eq!(c.handle(Enter, false), out("ṝ", "", "r", true));
}

#[test]
fn tab_cycles_and_space_picks() {
    let mut c = latin(Some(ACCENT_SAMPLE), true);
    type_last(&mut c, "pn");
    hold(&mut c, "n");
    assert_eq!(c.accent_list().unwrap().0.len(), 3);
    c.handle(Tab, false);
    assert_eq!(c.accent_list().unwrap().1, Some(0));
    c.handle(Tab, false);
    c.handle(Tab, false);
    assert_eq!(c.accent_list().unwrap().1, Some(2));
    c.handle(Tab, false);
    assert_eq!(c.accent_list().unwrap().1, Some(0), "wraps round");
    assert_eq!(c.handle(text(" "), false), out("ṅ", "", "n", true));
}

#[test]
fn escape_other_keys_and_backspace_keep_the_plain_letter() {
    let mut c = latin(Some(ACCENT_SAMPLE), true);
    type_last(&mut c, "pra");
    hold(&mut c, "a");
    assert_eq!(c.handle(Escape, false), handled());
    assert!(c.accent_list().is_none());
    hold(&mut c, "a");
    let o = c.handle(text("j"), false);
    assert_eq!(o.insert, "j");
    assert_eq!(c.suggestion_buffer(), "praj");
    assert!(c.accent_list().is_none());
    type_last(&mut c, "a");
    hold(&mut c, "a");
    let b = c.handle(Backspace, false);
    assert!(!b.handled);
    assert_eq!(c.suggestion_buffer(), "praj");
    assert!(c.accent_list().is_none());
}

#[test]
fn nothing_highlighted() {
    let mut c = latin(Some(ACCENT_SAMPLE), true);
    type_last(&mut c, "pra");
    hold(&mut c, "a");
    assert_eq!(c.handle(Enter, false), passed(), "return keeps the letter");
    type_last(&mut c, "a");
    hold(&mut c, "a");
    assert_eq!(
        c.handle(text(" "), false),
        out(" ", "", "", true),
        "space ends the word"
    );
}

#[test]
fn letters_without_variants_repeat_as_usual() {
    let mut c = latin(Some(ACCENT_SAMPLE), true);
    type_last(&mut c, "ak");
    assert_eq!(hold(&mut c, "k"), out("k", "", "", true));
    assert!(c.accent_list().is_none());
    let mut c = latin(Some(ACCENT_SAMPLE), true);
    type_last(&mut c, "pra");
    assert_eq!(hold(&mut c, "u").insert, "u", "not the last typed letter");
    assert_eq!(c.suggestion_buffer(), "prau");
}

#[test]
fn click_picks_and_held_repeats_are_ignored() {
    let mut c = latin(Some(ACCENT_SAMPLE), true);
    type_last(&mut c, "pra");
    assert_eq!(c.choose_accent(0), passed(), "closed palette");
    hold(&mut c, "a");
    assert_eq!(c.choose_accent(0), out("ā", "", "a", true));
    assert_eq!(hold(&mut c, "a"), handled());
    assert_eq!(hold(&mut c, "a"), handled());
    assert!(c.accent_list().is_none(), "does not reopen");
    assert_eq!(
        c.handle(text("a"), false).insert,
        "a",
        "a fresh press types"
    );
    assert_eq!(c.suggestion_buffer(), "prāa");
}

#[test]
fn letting_go_picks_the_highlighted_variant() {
    let mut c = latin(Some(ACCENT_SAMPLE), true);
    type_last(&mut c, "pn");
    assert_eq!(c.choose_highlighted_accent(), passed());
    hold(&mut c, "n");
    assert_eq!(
        c.choose_highlighted_accent(),
        passed(),
        "nothing highlighted"
    );
    c.handle(Tab, false);
    c.handle(Tab, false);
    assert_eq!(c.choose_highlighted_accent(), out("ñ", "", "n", true));
    assert!(c.accent_list().is_none());
}

#[test]
fn escape_while_still_held() {
    let mut c = latin(Some(ACCENT_SAMPLE), true);
    type_last(&mut c, "pa");
    hold(&mut c, "a");
    c.handle(Escape, false);
    assert_eq!(hold(&mut c, "a"), handled());
    assert!(c.accent_list().is_none());
}

// --- Accent palette, without suggestions: the letter waits as marked text ---

#[test]
fn variant_letter_waits() {
    let mut c = latin(None, true);
    assert_eq!(c.handle(text("a"), false), out("", "a", "", true));
    assert_eq!(c.handle(text("k"), false), out("ak", "", "", true));
    assert_eq!(c.handle(text("a"), false), out("", "a", "", true));
    assert_eq!(c.handle(text("i"), false), out("a", "i", "", true));
    assert_eq!(hold(&mut c, "i"), out("", "i", "", true));
    assert_eq!(c.handle(text("1"), false), out("ī", "", "", true));
    assert!(c.commit_all().is_empty());
}

#[test]
fn waiting_letter_and_other_keys() {
    let mut c = latin(None, true);
    c.handle(text("s"), false);
    assert_eq!(c.handle(Backspace, false), out("", "", "", true));
    c.handle(text("s"), false);
    assert_eq!(c.handle(Enter, false), out("s", "", "", false));
    c.handle(text("s"), false);
    assert_eq!(c.commit_all(), "s");
    c.handle(text("s"), false);
    assert_eq!(c.set_latin(false), out("s", "", "", true));
    let mut c = latin(None, true);
    c.handle(text("s"), false);
    c.reset();
    assert!(c.commit_all().is_empty());
}

#[test]
fn click_without_suggester() {
    let mut c = latin(None, true);
    c.handle(text("a"), false);
    hold(&mut c, "a");
    assert_eq!(c.choose_accent(0), out("ā", "", "", true));
    assert_eq!(hold(&mut c, "a"), out("", "", "", true));
    assert_eq!(c.handle(text("k"), false), out("k", "", "", true));
}

#[test]
fn off_or_tibetan_is_untouched() {
    let mut c = latin(None, false);
    assert_eq!(c.handle(text("a"), false), out("a", "", "", true));
    let mut tib = Composer::new(false);
    tib.set_accents(true);
    assert!(tib.handle(text("a"), true).handled);
    assert!(tib.accent_list().is_none());
}

#[test]
fn list_json() {
    let mut c = latin(Some(SAMPLE), false);
    assert!(c.suggestion_json().is_none());
    type_last(&mut c, "Praj");
    let j = c.suggestion_json().unwrap();
    assert!(j.starts_with("{\"words\":[\"Prajñā\""), "{j}");
    assert!(j.ends_with("\"selected\":0,\"buffer\":\"Praj\"}"), "{j}");
    let mut c = latin(None, true);
    c.handle(text("a"), false);
    hold(&mut c, "a");
    assert_eq!(
        c.accent_json().as_deref(),
        Some("{\"options\":[\"ā\"],\"selected\":null}")
    );
}
