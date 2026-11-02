//! C ABI over `ttime-core` for native input-method shells. All behaviour
//! lives in the core; this crate only converts between C and Rust types.
//! See `include/ttime.h` for the contract.

use std::ffi::{c_char, CStr, CString};
use ttime_core::Session;

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
    fn version_matches_core() {
        unsafe { assert_eq!(take(ttime_version()), ttime_core::VERSION) }
    }
}
