//! Browser bridge. All transliteration happens in `ttime-core`; this crate only
//! adds the commit policy a text field needs and carries results to
//! JavaScript as strings (diagnostics as JSON).
//!
//! Commit policy: input is *provisional* until a space or newline is typed.
//! That keystroke converts the provisional text, appends it to the *committed*
//! text and starts a new provisional run. Committed text is never rewritten.
//! Backspace edits provisional text only; at an empty provisional run it does
//! nothing and the page's ordinary text editing takes over.

use ttime_core::{convert, Diagnostic, Engine, Options};
use wasm_bindgen::prelude::*;

/// Identifies the build in reports. `TTIME_GIT_SHA` is set by the build script.
#[wasm_bindgen]
pub fn version() -> String {
    format!(
        "ttime-wasm {} (core {}, commit {})",
        env!("CARGO_PKG_VERSION"),
        ttime_core::VERSION,
        option_env!("TTIME_GIT_SHA").unwrap_or("unknown")
    )
}

/// Whole-string conversion: `{"text": ..., "diagnostics": [...]}` as JSON.
#[wasm_bindgen]
pub fn convert_json(input: &str, precomposed: bool) -> String {
    let c = convert(input, Options { precomposed });
    format!(
        "{{\"text\":{},\"diagnostics\":{}}}",
        json_string(&c.text),
        diagnostics_json(&c.diagnostics)
    )
}

#[wasm_bindgen]
pub struct Session {
    committed: String,
    engine: Engine,
    precomposed: bool,
}

#[wasm_bindgen]
impl Session {
    #[wasm_bindgen(constructor)]
    pub fn new(precomposed: bool) -> Session {
        Session {
            committed: String::new(),
            engine: Engine::with_options(Options { precomposed }),
            precomposed,
        }
    }

    /// Feeds typed characters one at a time, committing at spaces and newlines.
    pub fn insert_text(&mut self, text: &str) {
        for c in text.chars() {
            self.engine.push(c);
            if (c == ' ' || c == '\n') && !self.holds_open_construct() {
                let out = self.engine.commit();
                self.committed.push_str(&out);
            }
        }
    }

    /// A space inside `[literal text]` or right after a backslash belongs to
    /// that construct, so it must not end the provisional run.
    fn holds_open_construct(&self) -> bool {
        let raw = self.engine.raw();
        let body = &raw[..raw.len() - 1]; // without the space just pushed
        let mut depth = 0usize;
        let mut escaped = false;
        for c in body.chars() {
            if escaped {
                escaped = false;
            } else if c == '\\' {
                escaped = true;
            } else if c == '[' {
                depth += 1;
            } else if c == ']' {
                depth = depth.saturating_sub(1);
            }
        }
        depth > 0 || escaped
    }

    /// Removes the last provisional keystroke. Returns false, changing nothing,
    /// when there is no provisional text.
    pub fn backspace(&mut self) -> bool {
        self.engine.backspace()
    }

    /// Drops the provisional run, keeping committed text.
    pub fn cancel(&mut self) {
        self.engine.cancel();
    }

    /// Commits whatever is provisional and returns the whole text.
    pub fn finish(&mut self) -> String {
        let out = self.engine.commit();
        self.committed.push_str(&out);
        self.committed.clone()
    }

    /// Replaces the committed text (after the page edited it directly) and
    /// clears the provisional run.
    pub fn set_committed(&mut self, text: &str) {
        self.committed = text.to_string();
        self.engine.cancel();
    }

    pub fn reset(&mut self) {
        self.committed.clear();
        self.engine.cancel();
    }

    pub fn committed(&self) -> String {
        self.committed.clone()
    }

    pub fn provisional(&self) -> String {
        self.engine.preedit()
    }

    /// The EWTS typed since the last commit.
    pub fn raw(&self) -> String {
        self.engine.raw().to_string()
    }

    /// Diagnostics for the provisional run only; spans are UTF-8 byte offsets
    /// into [`Session::raw`].
    pub fn diagnostics_json(&self) -> String {
        diagnostics_json(&self.engine.diagnostics())
    }

    pub fn precomposed(&self) -> bool {
        self.precomposed
    }
}

fn diagnostics_json(diags: &[Diagnostic]) -> String {
    let items: Vec<String> = diags
        .iter()
        .map(|d| {
            format!(
                "{{\"code\":{},\"category\":{},\"severity\":{},\"start\":{},\"end\":{},\"message\":{}}}",
                json_string(d.code.as_str()),
                json_string(&format!("{:?}", d.category)),
                json_string(&format!("{:?}", d.severity)),
                d.span.start,
                d.span.end,
                json_string(&d.message)
            )
        })
        .collect();
    format!("[{}]", items.join(","))
}

fn json_string(s: &str) -> String {
    let mut out = String::with_capacity(s.len() + 2);
    out.push('"');
    for c in s.chars() {
        match c {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            c if (c as u32) < 0x20 => out.push_str(&format!("\\u{:04x}", c as u32)),
            c => out.push(c),
        }
    }
    out.push('"');
    out
}
