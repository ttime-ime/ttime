//! C ABI over `ttime-core` for native input-method shells. All behaviour
//! lives in the core; this crate only converts between C and Rust types.
//! See `include/ttime.h` for the contract.

use std::ffi::{c_char, c_int, CStr, CString};
use std::slice;
use std::sync::Arc;
use ttime_core::policy::{
    dictionary_term, dictionary_url, Composer, KeyInput, ModeLock, Outcome, SanskritLexicon,
    ShiftSide, ShiftTap, ShiftTapKind, StackerModel, SymbolsModel, DICTIONARY_SITE,
};
use ttime_core::{convert, unicode_to_ewts, Options, Session};

/// Opaque to C.
#[allow(non_camel_case_types)]
pub struct ttime_session(Session);

fn to_c(s: String) -> *mut c_char {
    // Interior NULs cannot occur in engine output; strip any to stay total.
    CString::new(s.replace('\0', ""))
        .map(CString::into_raw)
        .unwrap_or(std::ptr::null_mut())
}

#[no_mangle]
pub extern "C" fn ttime_version() -> *mut c_char {
    to_c(ttime_core::VERSION.to_string())
}

#[no_mangle]
pub extern "C" fn ttime_session_new(precomposed: bool) -> *mut ttime_session {
    Box::into_raw(Box::new(ttime_session(Session::new(precomposed))))
}

/// # Safety
/// `s` must be null or a pointer from `ttime_session_new`, not yet freed.
#[no_mangle]
pub unsafe extern "C" fn ttime_session_free(s: *mut ttime_session) {
    if !s.is_null() {
        drop(Box::from_raw(s));
    }
}

/// # Safety
/// `s` must be null or a live session; `utf8` null or a NUL-terminated string.
#[no_mangle]
pub unsafe extern "C" fn ttime_session_insert(s: *mut ttime_session, utf8: *const c_char) {
    if s.is_null() || utf8.is_null() {
        return;
    }
    // Invalid UTF-8 is replaced rather than rejected.
    let text = CStr::from_ptr(utf8).to_string_lossy();
    (*s).0.insert_text(&text);
}

/// # Safety
/// `s` must be null or a live session.
#[no_mangle]
pub unsafe extern "C" fn ttime_session_backspace(s: *mut ttime_session) -> bool {
    !s.is_null() && (*s).0.backspace()
}

/// # Safety
/// `s` must be null or a live session.
#[no_mangle]
pub unsafe extern "C" fn ttime_session_cancel(s: *mut ttime_session) {
    if !s.is_null() {
        (*s).0.cancel();
    }
}

/// # Safety
/// `s` must be null or a live session.
#[no_mangle]
pub unsafe extern "C" fn ttime_session_provisional(s: *const ttime_session) -> *mut c_char {
    to_c(if s.is_null() {
        String::new()
    } else {
        (*s).0.provisional()
    })
}

/// # Safety
/// `s` must be null or a live session.
#[no_mangle]
pub unsafe extern "C" fn ttime_session_raw(s: *const ttime_session) -> *mut c_char {
    to_c(if s.is_null() {
        String::new()
    } else {
        (*s).0.raw().to_string()
    })
}

/// # Safety
/// `s` must be null or a live session.
#[no_mangle]
pub unsafe extern "C" fn ttime_session_has_provisional(s: *const ttime_session) -> bool {
    !s.is_null() && !(*s).0.raw().is_empty()
}

/// # Safety
/// `s` must be null or a live session.
#[no_mangle]
pub unsafe extern "C" fn ttime_session_take_committed(s: *mut ttime_session) -> *mut c_char {
    to_c(if s.is_null() {
        String::new()
    } else {
        (*s).0.take_committed()
    })
}

/// # Safety
/// `s` must be null or a live session.
#[no_mangle]
pub unsafe extern "C" fn ttime_session_finish(s: *mut ttime_session) -> *mut c_char {
    if s.is_null() {
        return to_c(String::new());
    }
    (*s).0.finish();
    to_c((*s).0.take_committed())
}

/// # Safety
/// `s` must be null or a live session.
#[no_mangle]
pub unsafe extern "C" fn ttime_session_set_latin(s: *mut ttime_session, on: bool) {
    if !s.is_null() {
        (*s).0.set_latin(on);
    }
}

/// # Safety
/// `s` must be null or a live session.
#[no_mangle]
pub unsafe extern "C" fn ttime_session_is_latin(s: *const ttime_session) -> bool {
    !s.is_null() && (*s).0.latin()
}

/// # Safety
/// Each argument must be null (treated as empty) or a NUL-terminated string.
#[no_mangle]
pub unsafe extern "C" fn ttime_build_stack_json(
    layers: *const c_char,
    vowel: *const c_char,
    marks: *const c_char,
    precomposed: bool,
) -> *mut c_char {
    let text = |p: *const c_char| {
        if p.is_null() {
            String::new()
        } else {
            CStr::from_ptr(p).to_string_lossy().into_owned()
        }
    };
    to_c(ttime_core::build_stack_json(
        &text(layers),
        &text(vowel),
        &text(marks),
        ttime_core::Options {
            precomposed,
            diplomatic: false,
        },
    ))
}

/// # Safety
/// `query` must be null (all entries) or a NUL-terminated string.
#[no_mangle]
pub unsafe extern "C" fn ttime_symbols_json(query: *const c_char) -> *mut c_char {
    let q = if query.is_null() {
        String::new()
    } else {
        CStr::from_ptr(query).to_string_lossy().into_owned()
    };
    to_c(ttime_core::symbols::search_json(&q))
}

#[no_mangle]
pub extern "C" fn ttime_symbol_categories_json() -> *mut c_char {
    to_c(ttime_core::symbols::categories_json())
}

#[no_mangle]
pub extern "C" fn ttime_stack_alphabet_json() -> *mut c_char {
    to_c(ttime_core::stack_alphabet_json())
}

/// # Safety
/// `utf8` must be null (treated as empty) or a NUL-terminated string.
#[no_mangle]
pub unsafe extern "C" fn ttime_convert(utf8: *const c_char, precomposed: bool) -> *mut c_char {
    let input = if utf8.is_null() {
        String::new()
    } else {
        CStr::from_ptr(utf8).to_string_lossy().into_owned()
    };
    to_c(
        convert(
            &input,
            Options {
                precomposed,
                diplomatic: false,
            },
        )
        .text,
    )
}

/// # Safety
/// `utf8` must be null (treated as empty) or a NUL-terminated string.
#[no_mangle]
pub unsafe extern "C" fn ttime_unicode_to_ewts(utf8: *const c_char) -> *mut c_char {
    let input = if utf8.is_null() {
        String::new()
    } else {
        CStr::from_ptr(utf8).to_string_lossy().into_owned()
    };
    to_c(unicode_to_ewts(&input).text)
}

// --- IME policy shared by every shell ---------------------------------------

/// Reads a C string, or "" for null. Invalid UTF-8 is replaced rather than rejected.
///
/// # Safety
/// `p` must be null or a NUL-terminated string.
unsafe fn cstr(p: *const c_char) -> String {
    if p.is_null() {
        String::new()
    } else {
        CStr::from_ptr(p).to_string_lossy().into_owned()
    }
}

/// Like [`cstr`], but keeps null distinct from "".
///
/// # Safety
/// `p` must be null or a NUL-terminated string.
unsafe fn cstr_opt(p: *const c_char) -> Option<String> {
    (!p.is_null()).then(|| cstr(p))
}

fn tri(v: Option<bool>) -> c_int {
    match v {
        None => -1,
        Some(false) => 0,
        Some(true) => 1,
    }
}

fn side_from(side: c_int) -> ShiftSide {
    if side == 0 {
        ShiftSide::Left
    } else {
        ShiftSide::Right
    }
}

/// # Safety
/// `text` must be null or a NUL-terminated string.
unsafe fn key_from(kind: c_int, text: *const c_char) -> KeyInput {
    match kind {
        0 => KeyInput::Text(cstr(text)),
        1 => KeyInput::Backspace,
        2 => KeyInput::Escape,
        3 => KeyInput::Enter,
        4 => KeyInput::Tab,
        5 => KeyInput::Up,
        6 => KeyInput::Down,
        7 => KeyInput::Left,
        8 => KeyInput::Right,
        _ => KeyInput::Other,
    }
}

/// What the host should do after a key, as plain C data (no JSON on the typing path).
/// The strings are owned by the caller; release them with `ttime_outcome_free`.
#[repr(C)]
pub struct ttime_outcome {
    pub insert: *mut c_char,
    pub marked: *mut c_char,
    pub replacing: *mut c_char,
    pub handled: bool,
}

impl From<Outcome> for ttime_outcome {
    fn from(o: Outcome) -> Self {
        Self {
            insert: to_c(o.insert),
            marked: to_c(o.marked),
            replacing: to_c(o.replacing),
            handled: o.handled,
        }
    }
}

/// # Safety
/// `o` must be null or point to an outcome returned by this library whose strings
/// have not been freed. The strings are freed and set to null, so a second call is harmless.
#[no_mangle]
pub unsafe extern "C" fn ttime_outcome_free(o: *mut ttime_outcome) {
    if o.is_null() {
        return;
    }
    for p in [&mut (*o).insert, &mut (*o).marked, &mut (*o).replacing] {
        ttime_string_free(*p);
        *p = std::ptr::null_mut();
    }
}

// --- Sanskrit word list -----------------------------------------------------

/// A parsed Sanskrit word list, shared by every composer that is given it.
#[allow(non_camel_case_types)]
pub struct ttime_lexicon(Arc<SanskritLexicon>);

/// # Safety
/// `bytes` must be null or point to `len` readable bytes.
#[no_mangle]
pub unsafe extern "C" fn ttime_lexicon_new(bytes: *const u8, len: usize) -> *mut ttime_lexicon {
    let data = if bytes.is_null() {
        &[][..]
    } else {
        slice::from_raw_parts(bytes, len)
    };
    Box::into_raw(Box::new(ttime_lexicon(Arc::new(
        SanskritLexicon::from_bytes(data),
    ))))
}

/// # Safety
/// `l` must be null or a pointer from `ttime_lexicon_new`, not yet freed.
#[no_mangle]
pub unsafe extern "C" fn ttime_lexicon_free(l: *mut ttime_lexicon) {
    if !l.is_null() {
        drop(Box::from_raw(l));
    }
}

/// # Safety
/// `l` must be null or a live lexicon.
#[no_mangle]
pub unsafe extern "C" fn ttime_lexicon_len(l: *const ttime_lexicon) -> usize {
    if l.is_null() {
        0
    } else {
        (*l).0.len()
    }
}

// --- Composer ---------------------------------------------------------------

/// Opaque to C.
#[allow(non_camel_case_types)]
pub struct ttime_composer(Composer);

#[no_mangle]
pub extern "C" fn ttime_composer_new(precomposed: bool) -> *mut ttime_composer {
    Box::into_raw(Box::new(ttime_composer(Composer::new(precomposed))))
}

/// # Safety
/// `c` must be null or a pointer from `ttime_composer_new`, not yet freed.
#[no_mangle]
pub unsafe extern "C" fn ttime_composer_free(c: *mut ttime_composer) {
    if !c.is_null() {
        drop(Box::from_raw(c));
    }
}

/// # Safety
/// `c` must be null or a live composer.
#[no_mangle]
pub unsafe extern "C" fn ttime_composer_set_precomposed(c: *mut ttime_composer, on: bool) {
    if !c.is_null() {
        (*c).0.set_precomposed(on);
    }
}

/// # Safety
/// `c` must be null or a live composer.
#[no_mangle]
pub unsafe extern "C" fn ttime_composer_set_accents(c: *mut ttime_composer, on: bool) {
    if !c.is_null() {
        (*c).0.set_accents(on);
    }
}

/// # Safety
/// `c` must be null or a live composer.
#[no_mangle]
pub unsafe extern "C" fn ttime_composer_accents(c: *const ttime_composer) -> bool {
    !c.is_null() && (*c).0.accents()
}

/// # Safety
/// `c` must be null or a live composer; `lex` null or a live lexicon. The composer
/// keeps its own reference, so `lex` may be freed afterwards.
#[no_mangle]
pub unsafe extern "C" fn ttime_composer_set_lexicon(
    c: *mut ttime_composer,
    lex: *const ttime_lexicon,
) {
    if c.is_null() {
        return;
    }
    let shared = if lex.is_null() {
        None
    } else {
        Some(Arc::clone(&(*lex).0))
    };
    (*c).0.set_lexicon(shared);
}

/// # Safety
/// `c` must be null or a live composer.
#[no_mangle]
pub unsafe extern "C" fn ttime_composer_has_suggester(c: *const ttime_composer) -> bool {
    !c.is_null() && (*c).0.has_suggester()
}

/// # Safety
/// `c` must be null or a live composer; `text` null or a NUL-terminated string.
#[no_mangle]
pub unsafe extern "C" fn ttime_composer_handle(
    c: *mut ttime_composer,
    key_kind: c_int,
    text: *const c_char,
    is_repeat: bool,
) -> ttime_outcome {
    if c.is_null() {
        return Outcome::default().into();
    }
    (*c).0.handle(key_from(key_kind, text), is_repeat).into()
}

/// # Safety
/// `c` must be null or a live composer.
#[no_mangle]
pub unsafe extern "C" fn ttime_composer_choose_suggestion(
    c: *mut ttime_composer,
    index: c_int,
) -> ttime_outcome {
    if c.is_null() || index < 0 {
        return Outcome::default().into();
    }
    (*c).0.choose_suggestion(index as usize).into()
}

/// # Safety
/// `c` must be null or a live composer.
#[no_mangle]
pub unsafe extern "C" fn ttime_composer_choose_accent(
    c: *mut ttime_composer,
    index: c_int,
) -> ttime_outcome {
    if c.is_null() || index < 0 {
        return Outcome::default().into();
    }
    (*c).0.choose_accent(index as usize).into()
}

/// # Safety
/// `c` must be null or a live composer.
#[no_mangle]
pub unsafe extern "C" fn ttime_composer_choose_highlighted_accent(
    c: *mut ttime_composer,
) -> ttime_outcome {
    if c.is_null() {
        return Outcome::default().into();
    }
    (*c).0.choose_highlighted_accent().into()
}

/// # Safety
/// `c` must be null or a live composer.
#[no_mangle]
pub unsafe extern "C" fn ttime_composer_set_latin(
    c: *mut ttime_composer,
    on: bool,
) -> ttime_outcome {
    if c.is_null() {
        return Outcome::default().into();
    }
    (*c).0.set_latin(on).into()
}

/// # Safety
/// `c` must be null or a live composer.
#[no_mangle]
pub unsafe extern "C" fn ttime_composer_is_latin(c: *const ttime_composer) -> bool {
    !c.is_null() && (*c).0.is_latin()
}

/// # Safety
/// `c` must be null or a live composer.
#[no_mangle]
pub unsafe extern "C" fn ttime_composer_commit_all(c: *mut ttime_composer) -> *mut c_char {
    to_c(if c.is_null() {
        String::new()
    } else {
        (*c).0.commit_all()
    })
}

/// # Safety
/// `c` must be null or a live composer.
#[no_mangle]
pub unsafe extern "C" fn ttime_composer_reset(c: *mut ttime_composer) {
    if !c.is_null() {
        (*c).0.reset();
    }
}

/// # Safety
/// `c` must be null or a live composer.
#[no_mangle]
pub unsafe extern "C" fn ttime_composer_suggestion_json(c: *const ttime_composer) -> *mut c_char {
    if c.is_null() {
        return std::ptr::null_mut();
    }
    (*c).0.suggestion_json().map_or(std::ptr::null_mut(), to_c)
}

/// # Safety
/// `c` must be null or a live composer.
#[no_mangle]
pub unsafe extern "C" fn ttime_composer_accent_json(c: *const ttime_composer) -> *mut c_char {
    if c.is_null() {
        return std::ptr::null_mut();
    }
    (*c).0.accent_json().map_or(std::ptr::null_mut(), to_c)
}

/// # Safety
/// `c` must be null or a live composer.
#[no_mangle]
pub unsafe extern "C" fn ttime_composer_suggestion_buffer(c: *const ttime_composer) -> *mut c_char {
    to_c(if c.is_null() {
        String::new()
    } else {
        (*c).0.suggestion_buffer().to_string()
    })
}

// --- Mode lock --------------------------------------------------------------

/// Opaque to C.
#[allow(non_camel_case_types)]
pub struct ttime_mode_lock(ModeLock);

#[no_mangle]
pub extern "C" fn ttime_mode_lock_new() -> *mut ttime_mode_lock {
    Box::into_raw(Box::new(ttime_mode_lock(ModeLock::default())))
}

/// # Safety
/// `m` must be null or a pointer from `ttime_mode_lock_new`, not yet freed.
#[no_mangle]
pub unsafe extern "C" fn ttime_mode_lock_free(m: *mut ttime_mode_lock) {
    if !m.is_null() {
        drop(Box::from_raw(m));
    }
}

/// # Safety
/// `m` must be null or a live mode lock.
#[no_mangle]
pub unsafe extern "C" fn ttime_mode_lock_set(m: *mut ttime_mode_lock, locked: c_int) {
    if !m.is_null() {
        (*m).0.locked_latin = match locked {
            -1 => None,
            0 => Some(false),
            _ => Some(true),
        };
    }
}

/// # Safety
/// `m` must be null or a live mode lock.
#[no_mangle]
pub unsafe extern "C" fn ttime_mode_lock_get(m: *const ttime_mode_lock) -> c_int {
    if m.is_null() {
        -1
    } else {
        tri((*m).0.locked_latin)
    }
}

/// # Safety
/// `m` must be null or a live mode lock.
#[no_mangle]
pub unsafe extern "C" fn ttime_mode_lock_set_last(m: *mut ttime_mode_lock, last: c_int) {
    if !m.is_null() {
        (*m).0.last_latin = match last {
            -1 => None,
            0 => Some(false),
            _ => Some(true),
        };
    }
}

/// # Safety
/// `m` must be null or a live mode lock.
#[no_mangle]
pub unsafe extern "C" fn ttime_mode_lock_get_last(m: *const ttime_mode_lock) -> c_int {
    if m.is_null() {
        -1
    } else {
        tri((*m).0.last_latin)
    }
}

/// # Safety
/// `m` must be null or a live mode lock.
#[no_mangle]
pub unsafe extern "C" fn ttime_mode_lock_set_start_latin(m: *mut ttime_mode_lock, latin: bool) {
    if !m.is_null() {
        (*m).0.start_latin = latin;
    }
}

/// # Safety
/// `m` must be null or a live mode lock.
#[no_mangle]
pub unsafe extern "C" fn ttime_mode_lock_left_tap(
    m: *mut ttime_mode_lock,
    kind: c_int,
    is_latin: bool,
) -> c_int {
    if m.is_null() {
        return -1;
    }
    let k = if kind == 2 {
        ShiftTapKind::Double
    } else {
        ShiftTapKind::Single
    };
    tri((*m).0.left_tap(k, is_latin))
}

/// # Safety
/// `m` must be null or a live mode lock.
#[no_mangle]
pub unsafe extern "C" fn ttime_mode_lock_choose(m: *mut ttime_mode_lock, latin: bool) -> bool {
    if m.is_null() {
        latin
    } else {
        (*m).0.choose(latin)
    }
}

/// # Safety
/// `m` must be null or a live mode lock.
#[no_mangle]
pub unsafe extern "C" fn ttime_mode_lock_toggle_lock(m: *mut ttime_mode_lock, is_latin: bool) {
    if !m.is_null() {
        (*m).0.toggle_lock(is_latin);
    }
}

/// # Safety
/// `m` must be null or a live mode lock.
#[no_mangle]
pub unsafe extern "C" fn ttime_mode_lock_mode_on_focus(m: *const ttime_mode_lock) -> bool {
    !m.is_null() && (*m).0.mode_on_focus()
}

// --- Shift tap --------------------------------------------------------------

/// Opaque to C.
#[allow(non_camel_case_types)]
pub struct ttime_shift_tap(ShiftTap);

#[no_mangle]
pub extern "C" fn ttime_shift_tap_new() -> *mut ttime_shift_tap {
    Box::into_raw(Box::new(ttime_shift_tap(ShiftTap::default())))
}

/// # Safety
/// `t` must be null or a pointer from `ttime_shift_tap_new`, not yet freed.
#[no_mangle]
pub unsafe extern "C" fn ttime_shift_tap_free(t: *mut ttime_shift_tap) {
    if !t.is_null() {
        drop(Box::from_raw(t));
    }
}

/// # Safety
/// `t` must be null or a live shift tap.
#[no_mangle]
pub unsafe extern "C" fn ttime_shift_tap_key_down(t: *mut ttime_shift_tap) {
    if !t.is_null() {
        (*t).0.key_down();
    }
}

/// # Safety
/// `t` must be null or a live shift tap.
#[no_mangle]
pub unsafe extern "C" fn ttime_shift_tap_reset(t: *mut ttime_shift_tap) {
    if !t.is_null() {
        (*t).0.reset();
    }
}

/// # Safety
/// `t` must be null or a live shift tap.
#[no_mangle]
pub unsafe extern "C" fn ttime_shift_tap_press(
    t: *mut ttime_shift_tap,
    side: c_int,
    time: f64,
    chord: bool,
    other_held: bool,
) {
    if !t.is_null() {
        (*t).0.press(side_from(side), time, chord, other_held);
    }
}

/// # Safety
/// `t` must be null or a live shift tap.
#[no_mangle]
pub unsafe extern "C" fn ttime_shift_tap_release(
    t: *mut ttime_shift_tap,
    side: c_int,
    time: f64,
    chord: bool,
) -> c_int {
    if t.is_null() {
        return 0;
    }
    match (*t).0.release(side_from(side), time, chord) {
        None => 0,
        Some(e) if e.kind == ShiftTapKind::Single => 1,
        Some(_) => 2,
    }
}

/// # Safety
/// `t` must be null or a live shift tap.
#[no_mangle]
pub unsafe extern "C" fn ttime_shift_tap_held(t: *const ttime_shift_tap, side: c_int) -> bool {
    if t.is_null() {
        return false;
    }
    match side_from(side) {
        ShiftSide::Left => (*t).0.left_held(),
        ShiftSide::Right => (*t).0.right_held(),
    }
}

// --- Stacker ----------------------------------------------------------------

/// Opaque to C.
#[allow(non_camel_case_types)]
pub struct ttime_stacker(StackerModel);

#[no_mangle]
pub extern "C" fn ttime_stacker_new(precomposed: bool) -> *mut ttime_stacker {
    Box::into_raw(Box::new(ttime_stacker(StackerModel::new(precomposed))))
}

/// # Safety
/// `s` must be null or a pointer from `ttime_stacker_new`, not yet freed.
#[no_mangle]
pub unsafe extern "C" fn ttime_stacker_free(s: *mut ttime_stacker) {
    if !s.is_null() {
        drop(Box::from_raw(s));
    }
}

/// # Safety
/// `s` must be null or a live stacker.
#[no_mangle]
pub unsafe extern "C" fn ttime_stacker_set_precomposed(s: *mut ttime_stacker, on: bool) {
    if !s.is_null() {
        (*s).0.set_precomposed(on);
    }
}

/// # Safety
/// `s` must be null or a live stacker; `key` null or a NUL-terminated string.
#[no_mangle]
pub unsafe extern "C" fn ttime_stacker_add_layer(
    s: *mut ttime_stacker,
    key: *const c_char,
) -> bool {
    !s.is_null() && (*s).0.add_layer(&cstr(key))
}

/// # Safety
/// `s` must be null or a live stacker.
#[no_mangle]
pub unsafe extern "C" fn ttime_stacker_remove_layer(s: *mut ttime_stacker, index: c_int) {
    if !s.is_null() && index >= 0 {
        (*s).0.remove_layer(index as usize);
    }
}

/// # Safety
/// `s` must be null or a live stacker; `vowel` null or a NUL-terminated string.
#[no_mangle]
pub unsafe extern "C" fn ttime_stacker_set_vowel(s: *mut ttime_stacker, vowel: *const c_char) {
    if !s.is_null() {
        (*s).0.set_vowel(&cstr(vowel));
    }
}

/// # Safety
/// `s` must be null or a live stacker; `mark` null or a NUL-terminated string.
#[no_mangle]
pub unsafe extern "C" fn ttime_stacker_toggle_mark(s: *mut ttime_stacker, mark: *const c_char) {
    if !s.is_null() {
        (*s).0.toggle_mark(&cstr(mark));
    }
}

/// # Safety
/// `s` must be null or a live stacker; `letters` null or a NUL-terminated string.
#[no_mangle]
pub unsafe extern "C" fn ttime_stacker_use_preset(s: *mut ttime_stacker, letters: *const c_char) {
    if s.is_null() {
        return;
    }
    let owned = cstr(letters);
    let keys: Vec<&str> = owned.split_whitespace().collect();
    (*s).0.use_preset(&keys);
}

/// # Safety
/// `s` must be null or a live stacker.
#[no_mangle]
pub unsafe extern "C" fn ttime_stacker_clear(s: *mut ttime_stacker) {
    if !s.is_null() {
        (*s).0.clear();
    }
}

/// # Safety
/// `s` must be null or a live stacker; `hint` null or a NUL-terminated string.
#[no_mangle]
pub unsafe extern "C" fn ttime_stacker_set_hint(s: *mut ttime_stacker, hint: *const c_char) {
    if !s.is_null() {
        (*s).0.set_hint(&cstr(hint));
    }
}

/// # Safety
/// `s` must be null or a live stacker; `text` null or a NUL-terminated string.
#[no_mangle]
pub unsafe extern "C" fn ttime_stacker_type(s: *mut ttime_stacker, text: *const c_char) {
    if !s.is_null() {
        (*s).0.type_text(&cstr(text));
    }
}

/// # Safety
/// `s` must be null or a live stacker.
#[no_mangle]
pub unsafe extern "C" fn ttime_stacker_confirm_typed(s: *mut ttime_stacker) -> bool {
    !s.is_null() && (*s).0.confirm_typed()
}

/// # Safety
/// `s` must be null or a live stacker.
#[no_mangle]
pub unsafe extern "C" fn ttime_stacker_backspace(s: *mut ttime_stacker) -> bool {
    !s.is_null() && (*s).0.backspace()
}

/// # Safety
/// `s` must be null or a live stacker.
#[no_mangle]
pub unsafe extern "C" fn ttime_stacker_consume(s: *mut ttime_stacker) -> *mut c_char {
    to_c(if s.is_null() {
        String::new()
    } else {
        (*s).0.consume().map(|b| b.text).unwrap_or_default()
    })
}

/// # Safety
/// `s` must be null or a live stacker; `key` null or a NUL-terminated string.
#[no_mangle]
pub unsafe extern "C" fn ttime_stacker_matches(
    s: *const ttime_stacker,
    key: *const c_char,
) -> bool {
    !s.is_null() && (*s).0.matches(&cstr(key))
}

/// # Safety
/// `s` must be null or a live stacker.
#[no_mangle]
pub unsafe extern "C" fn ttime_stacker_state_json(s: *const ttime_stacker) -> *mut c_char {
    to_c(if s.is_null() {
        "{}".into()
    } else {
        (*s).0.state_json()
    })
}

// --- Symbols window -----------------------------------------------------------

/// Opaque to C.
#[allow(non_camel_case_types)]
pub struct ttime_symbols_model(SymbolsModel);

#[no_mangle]
pub extern "C" fn ttime_symbols_model_new() -> *mut ttime_symbols_model {
    Box::into_raw(Box::new(ttime_symbols_model(SymbolsModel::new())))
}

/// # Safety
/// `m` must be null or a pointer from `ttime_symbols_model_new`, not yet freed.
#[no_mangle]
pub unsafe extern "C" fn ttime_symbols_model_free(m: *mut ttime_symbols_model) {
    if !m.is_null() {
        drop(Box::from_raw(m));
    }
}

/// # Safety
/// `m` must be null or a live symbols model; `text` null or a NUL-terminated string.
#[no_mangle]
pub unsafe extern "C" fn ttime_symbols_model_type(
    m: *mut ttime_symbols_model,
    text: *const c_char,
) {
    if !m.is_null() {
        (*m).0.type_text(&cstr(text));
    }
}

/// # Safety
/// `m` must be null or a live symbols model.
#[no_mangle]
pub unsafe extern "C" fn ttime_symbols_model_backspace(m: *mut ttime_symbols_model) -> bool {
    !m.is_null() && (*m).0.backspace()
}

/// # Safety
/// `m` must be null or a live symbols model.
#[no_mangle]
pub unsafe extern "C" fn ttime_symbols_model_clear_query(m: *mut ttime_symbols_model) {
    if !m.is_null() {
        (*m).0.clear_query();
    }
}

/// # Safety
/// `m` must be null or a live symbols model; `category` null or a NUL-terminated string.
#[no_mangle]
pub unsafe extern "C" fn ttime_symbols_model_set_category(
    m: *mut ttime_symbols_model,
    category: *const c_char,
) {
    if m.is_null() {
        return;
    }
    let c = cstr_opt(category).filter(|c| !c.is_empty());
    (*m).0.set_category(c.as_deref());
}

/// # Safety
/// `m` must be null or a live symbols model.
#[no_mangle]
pub unsafe extern "C" fn ttime_symbols_model_next_category(m: *mut ttime_symbols_model) {
    if !m.is_null() {
        (*m).0.next_category();
    }
}

/// # Safety
/// `m` must be null or a live symbols model.
#[no_mangle]
pub unsafe extern "C" fn ttime_symbols_model_move(m: *mut ttime_symbols_model, delta: c_int) {
    if !m.is_null() {
        (*m).0.move_by(delta as isize);
    }
}

/// # Safety
/// `m` must be null or a live symbols model.
#[no_mangle]
pub unsafe extern "C" fn ttime_symbols_model_select(m: *mut ttime_symbols_model, index: c_int) {
    if !m.is_null() && index >= 0 {
        (*m).0.select(index as usize);
    }
}

/// # Safety
/// `m` must be null or a live symbols model; `hint` null or a NUL-terminated string.
#[no_mangle]
pub unsafe extern "C" fn ttime_symbols_model_set_hint(
    m: *mut ttime_symbols_model,
    hint: *const c_char,
) {
    if !m.is_null() {
        (*m).0.set_hint(&cstr(hint));
    }
}

/// # Safety
/// `m` must be null or a live symbols model.
#[no_mangle]
pub unsafe extern "C" fn ttime_symbols_model_state_json(
    m: *const ttime_symbols_model,
) -> *mut c_char {
    to_c(if m.is_null() {
        "{}".into()
    } else {
        (*m).0.state_json()
    })
}

// --- Dictionary ---------------------------------------------------------------

/// # Safety
/// Each argument must be null (none) or a NUL-terminated string.
#[no_mangle]
pub unsafe extern "C" fn ttime_dictionary_term(
    selection: *const c_char,
    before: *const c_char,
) -> *mut c_char {
    let sel = cstr_opt(selection);
    let before = cstr_opt(before);
    to_c(dictionary_term(sel.as_deref(), before.as_deref()))
}

/// # Safety
/// `term` must be null (treated as empty) or a NUL-terminated string.
#[no_mangle]
pub unsafe extern "C" fn ttime_dictionary_url(term: *const c_char) -> *mut c_char {
    to_c(dictionary_url(&cstr(term)).unwrap_or_default())
}

#[no_mangle]
pub extern "C" fn ttime_dictionary_site() -> *mut c_char {
    to_c(DICTIONARY_SITE.to_string())
}

/// # Safety
/// `s` must be null or a string returned by this library, not yet freed.
#[no_mangle]
pub unsafe extern "C" fn ttime_string_free(s: *mut c_char) {
    if !s.is_null() {
        drop(CString::from_raw(s));
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    unsafe fn take(p: *mut c_char) -> String {
        let s = CStr::from_ptr(p).to_str().unwrap().to_string();
        ttime_string_free(p);
        s
    }

    #[test]
    fn types_commits_and_finishes_through_the_c_api() {
        unsafe {
            let s = ttime_session_new(false);
            let ka = CString::new("ka kh").unwrap();
            ttime_session_insert(s, ka.as_ptr());
            assert_eq!(take(ttime_session_take_committed(s)), "ཀ་");
            assert_eq!(take(ttime_session_take_committed(s)), "");
            assert!(ttime_session_has_provisional(s));
            assert_eq!(take(ttime_session_provisional(s)), "ཁ");
            assert_eq!(take(ttime_session_raw(s)), "kh");
            assert!(ttime_session_backspace(s));
            assert_eq!(take(ttime_session_finish(s)), "ཀ");
            assert!(!ttime_session_has_provisional(s));
            assert!(!ttime_session_backspace(s));
            ttime_session_free(s);
        }
    }

    #[test]
    fn null_arguments_are_harmless() {
        unsafe {
            ttime_session_insert(std::ptr::null_mut(), std::ptr::null());
            assert!(!ttime_session_backspace(std::ptr::null_mut()));
            assert_eq!(take(ttime_session_provisional(std::ptr::null())), "");
            assert_eq!(take(ttime_session_finish(std::ptr::null_mut())), "");
            ttime_session_free(std::ptr::null_mut());
            ttime_string_free(std::ptr::null_mut());
        }
    }

    #[test]
    fn invalid_utf8_does_not_crash() {
        unsafe {
            let s = ttime_session_new(false);
            let bad = CString::new(vec![b'k', 0xFF, b'a']).unwrap();
            ttime_session_insert(s, bad.as_ptr());
            let _ = take(ttime_session_finish(s));
            ttime_session_free(s);
        }
    }

    #[test]
    fn latin_mode_passes_text_through_and_flushes_pending_tibetan() {
        unsafe {
            let s = ttime_session_new(false);
            assert!(!ttime_session_is_latin(s));
            let ka = CString::new("ka").unwrap();
            ttime_session_insert(s, ka.as_ptr());
            ttime_session_set_latin(s, true);
            assert!(ttime_session_is_latin(s));
            assert!(!ttime_session_has_provisional(s));
            assert_eq!(take(ttime_session_take_committed(s)), "ཀ");
            let kha = CString::new("kha ").unwrap();
            ttime_session_insert(s, kha.as_ptr());
            assert_eq!(take(ttime_session_take_committed(s)), "kha ");
            ttime_session_set_latin(s, false);
            assert!(!ttime_session_is_latin(s));
            ttime_session_set_latin(std::ptr::null_mut(), true);
            assert!(!ttime_session_is_latin(std::ptr::null()));
            ttime_session_free(s);
        }
    }

    #[test]
    fn builds_a_stack_through_the_c_api() {
        unsafe {
            let layers = CString::new("r g y").unwrap();
            let empty = CString::new("").unwrap();
            let j = take(ttime_build_stack_json(
                layers.as_ptr(),
                empty.as_ptr(),
                empty.as_ptr(),
                false,
            ));
            assert!(j.contains("\"shortest\":\"rgya\""), "{j}");
            let bad = take(ttime_build_stack_json(
                std::ptr::null(),
                std::ptr::null(),
                std::ptr::null(),
                false,
            ));
            assert!(bad.starts_with("{\"ok\":false"), "{bad}");
            assert!(take(ttime_stack_alphabet_json()).starts_with("{\"consonants\""));
        }
    }

    #[test]
    fn symbols_through_the_c_api() {
        unsafe {
            let all = take(ttime_symbols_json(std::ptr::null()));
            assert!(all.starts_with("[{\"id\":"), "{all}");
            let q = CString::new("shad").unwrap();
            assert!(take(ttime_symbols_json(q.as_ptr())).contains("\"id\":\"shad\""));
            assert!(take(ttime_symbol_categories_json()).starts_with("[\""));
        }
    }

    #[test]
    fn version_matches_core() {
        unsafe { assert_eq!(take(ttime_version()), ttime_core::VERSION) }
    }

    #[test]
    fn batch_convert_and_reverse_through_the_c_api() {
        unsafe {
            let ewts = CString::new("bkra shis").unwrap();
            let tib = take(ttime_convert(ewts.as_ptr(), false));
            assert_eq!(tib, "བཀྲ་ཤིས");
            let back = CString::new(tib.clone()).unwrap();
            assert_eq!(take(ttime_unicode_to_ewts(back.as_ptr())), "bkra shis");
            assert_eq!(take(ttime_convert(std::ptr::null(), false)), "");
            assert_eq!(take(ttime_unicode_to_ewts(std::ptr::null())), "");
        }
    }

    unsafe fn take_outcome(mut o: ttime_outcome) -> (String, String, String, bool) {
        let s = |p: *mut c_char| CStr::from_ptr(p).to_str().unwrap().to_string();
        let r = (s(o.insert), s(o.marked), s(o.replacing), o.handled);
        ttime_outcome_free(&mut o);
        assert!(o.insert.is_null() && o.marked.is_null() && o.replacing.is_null());
        ttime_outcome_free(&mut o);
        r
    }

    #[test]
    fn composer_through_the_c_api() {
        unsafe {
            let c = ttime_composer_new(false);
            for ch in ["b", "k", "r", "a"] {
                let k = CString::new(ch).unwrap();
                let (_, marked, _, handled) =
                    take_outcome(ttime_composer_handle(c, 0, k.as_ptr(), false));
                assert!(handled);
                assert!(!marked.is_empty());
            }
            let sp = CString::new(" ").unwrap();
            let o = take_outcome(ttime_composer_handle(c, 0, sp.as_ptr(), false));
            assert_eq!(o, ("བཀྲ་".into(), "".into(), "".into(), true));
            assert!(ttime_composer_suggestion_json(c).is_null());
            assert!(ttime_composer_accent_json(c).is_null());
            let o = take_outcome(ttime_composer_set_latin(c, true));
            assert!(o.3 && ttime_composer_is_latin(c));
            ttime_composer_free(c);
        }
    }

    #[test]
    fn one_lexicon_shared_by_composers() {
        unsafe {
            let tsv = "prajñā\t100\tb\nprajña\t10\t-\n";
            let lex = ttime_lexicon_new(tsv.as_ptr(), tsv.len());
            assert_eq!(ttime_lexicon_len(lex), 2);
            let a = ttime_composer_new(false);
            let b = ttime_composer_new(false);
            ttime_composer_set_lexicon(a, lex);
            ttime_composer_set_lexicon(b, lex);
            ttime_lexicon_free(lex);
            assert!(ttime_composer_has_suggester(a) && ttime_composer_has_suggester(b));
            let _ = take_outcome(ttime_composer_set_latin(a, true));
            for ch in ["p", "r", "a"] {
                let k = CString::new(ch).unwrap();
                let _ = take_outcome(ttime_composer_handle(a, 0, k.as_ptr(), false));
            }
            let j = take(ttime_composer_suggestion_json(a));
            assert!(j.contains("prajñā"), "{j}");
            let tab = take_outcome(ttime_composer_handle(a, 4, std::ptr::null(), false));
            assert_eq!(tab, ("prajñā".into(), "".into(), "pra".into(), true));
            ttime_composer_set_lexicon(b, std::ptr::null());
            assert!(!ttime_composer_has_suggester(b));
            ttime_composer_free(a);
            ttime_composer_free(b);
        }
    }

    #[test]
    fn policy_null_arguments_are_harmless() {
        unsafe {
            let n = std::ptr::null_mut();
            assert_eq!(
                take_outcome(ttime_composer_handle(n, 0, std::ptr::null(), false)),
                ("".into(), "".into(), "".into(), false)
            );
            ttime_composer_set_lexicon(n, std::ptr::null());
            assert_eq!(take(ttime_composer_commit_all(n)), "");
            ttime_composer_free(n);
            ttime_lexicon_free(std::ptr::null_mut());
            assert_eq!(ttime_lexicon_len(ttime_lexicon_new(std::ptr::null(), 0)), 0);
            ttime_outcome_free(std::ptr::null_mut());
            assert_eq!(ttime_mode_lock_get(std::ptr::null()), -1);
            assert_eq!(
                ttime_shift_tap_release(std::ptr::null_mut(), 0, 0.0, false),
                0
            );
            assert!(!ttime_stacker_add_layer(
                std::ptr::null_mut(),
                std::ptr::null()
            ));
            assert_eq!(take(ttime_stacker_state_json(std::ptr::null())), "{}");
            assert_eq!(take(ttime_symbols_model_state_json(std::ptr::null())), "{}");
            assert_eq!(
                take(ttime_dictionary_term(std::ptr::null(), std::ptr::null())),
                ""
            );
            assert_eq!(take(ttime_dictionary_url(std::ptr::null())), "");
        }
    }

    #[test]
    fn mode_lock_and_shift_tap_through_the_c_api() {
        unsafe {
            let m = ttime_mode_lock_new();
            assert_eq!(ttime_mode_lock_left_tap(m, 1, false), 1, "single flips");
            assert_eq!(
                ttime_mode_lock_left_tap(m, 2, true),
                0,
                "double locks Tibetan"
            );
            assert_eq!(ttime_mode_lock_get(m), 0);
            assert!(!ttime_mode_lock_mode_on_focus(m));
            ttime_mode_lock_set(m, 1);
            assert!(ttime_mode_lock_mode_on_focus(m));
            ttime_mode_lock_toggle_lock(m, true);
            assert_eq!(ttime_mode_lock_get(m), -1);
            assert_eq!(
                ttime_mode_lock_get_last(m),
                0,
                "the double tap's mode is remembered"
            );
            ttime_mode_lock_set_last(m, -1);
            ttime_mode_lock_set_start_latin(m, true);
            assert!(ttime_mode_lock_mode_on_focus(m));
            ttime_mode_lock_set_last(m, 0);
            assert!(!ttime_mode_lock_mode_on_focus(m));
            ttime_mode_lock_free(m);

            let t = ttime_shift_tap_new();
            ttime_shift_tap_press(t, 0, 0.0, false, false);
            assert!(ttime_shift_tap_held(t, 0) && !ttime_shift_tap_held(t, 1));
            assert_eq!(ttime_shift_tap_release(t, 0, 0.1, false), 1);
            ttime_shift_tap_press(t, 0, 0.3, false, false);
            assert_eq!(ttime_shift_tap_release(t, 0, 0.4, false), 2);
            ttime_shift_tap_free(t);
        }
    }

    #[test]
    fn stacker_symbols_and_dictionary_through_the_c_api() {
        unsafe {
            let s = ttime_stacker_new(false);
            for k in ["r", "g", "y"] {
                let k = CString::new(k).unwrap();
                assert!(ttime_stacker_add_layer(s, k.as_ptr()));
            }
            let j = take(ttime_stacker_state_json(s));
            assert!(j.contains("\"shortest\":\"rgya\""), "{j}");
            assert_eq!(take(ttime_stacker_consume(s)), "རྒྱ");
            ttime_stacker_free(s);

            let m = ttime_symbols_model_new();
            let q = CString::new("shad").unwrap();
            ttime_symbols_model_type(m, q.as_ptr());
            assert!(take(ttime_symbols_model_state_json(m)).contains("\"id\":\"shad\""));
            let empty = CString::new("").unwrap();
            ttime_symbols_model_set_category(m, empty.as_ptr());
            assert!(take(ttime_symbols_model_state_json(m)).contains("\"category\":null"));
            ttime_symbols_model_free(m);

            let before = CString::new("བོད་སྐད་").unwrap();
            assert_eq!(
                take(ttime_dictionary_term(std::ptr::null(), before.as_ptr())),
                "སྐད"
            );
            let blank = CString::new("  ").unwrap();
            assert_eq!(take(ttime_dictionary_url(blank.as_ptr())), "");
            assert!(take(ttime_dictionary_site()).starts_with("https://"));
        }
    }

    /// Every function `ttime.h` declares is exported here, and nothing is exported
    /// that the header leaves out: the Windows and Linux shells compile against it.
    #[test]
    fn header_matches_exports() {
        use std::collections::BTreeSet;
        let names = |src: &str, marker: &str| -> BTreeSet<String> {
            src.match_indices(marker)
                .map(|(i, _)| {
                    let rest = &src[i + marker.len()..];
                    rest[..rest.find('(').unwrap()].trim().to_string()
                })
                .collect()
        };
        let rust = include_str!("lib.rs");
        let mut exported = names(rust, "extern \"C\" fn ");
        exported.retain(|n| n.starts_with("ttime_"));
        let header = include_str!("../include/ttime.h");
        let declared: BTreeSet<String> = header
            .match_indices("ttime_")
            .filter_map(|(i, _)| {
                let rest = &header[i..];
                let end = rest.find(|c: char| !(c.is_ascii_alphanumeric() || c == '_'))?;
                rest[end..]
                    .starts_with('(')
                    .then(|| rest[..end].to_string())
            })
            .collect();
        let missing: Vec<_> = declared.difference(&exported).collect();
        let undeclared: Vec<_> = exported.difference(&declared).collect();
        assert!(
            missing.is_empty() && undeclared.is_empty(),
            "declared in ttime.h but not exported: {missing:?}; exported but not in ttime.h: {undeclared:?}"
        );
    }
}
