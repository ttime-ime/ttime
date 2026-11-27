//! C ABI over `ttime-core` for native input-method shells. All behaviour
//! lives in the core; this crate only converts between C and Rust types.
//! See `include/ttime.h` for the contract.

use std::ffi::{c_char, CStr, CString};
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
    to_c(convert(
        &input,
        Options {
            precomposed,
            diplomatic: false,
        },
    )
    .text)
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
}
