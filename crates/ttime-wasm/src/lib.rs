//! Browser bridge. All transliteration and the commit policy live in
//! `ttime-core`; this crate only carries results to JavaScript as strings
//! (diagnostics as JSON).

use ttime_core::{convert, unicode_to_ewts, Diagnostic, Fidelity, Options};
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
    convert_json_with(input, precomposed, false)
}

/// Like `convert_json`; in diplomatic mode every choice or ignored input is a
/// Warning. The text is the same in both modes.
#[wasm_bindgen]
pub fn convert_json_with(input: &str, precomposed: bool, diplomatic: bool) -> String {
    let c = convert(input, Options { precomposed, diplomatic });
    format!(
        "{{\"text\":{},\"diagnostics\":{}}}",
        json_string(&c.text),
        diagnostics_json(&c.diagnostics)
    )
}

/// Unicode to EWTS: `{"text": ..., "fidelity": "Exact"|"Canonical"|"Lossy", "diagnostics": [...]}`.
#[wasm_bindgen]
pub fn reverse_json(input: &str) -> String {
    let r = unicode_to_ewts(input);
    let fidelity = match r.fidelity {
        Fidelity::Exact => "Exact",
        Fidelity::Canonical => "Canonical",
        Fidelity::Lossy => "Lossy",
    };
    format!(
        "{{\"text\":{},\"fidelity\":\"{}\",\"diagnostics\":{}}}",
        json_string(&r.text),
        fidelity,
        diagnostics_json(&r.diagnostics)
    )
}

/// The symbol catalogue entries matching `query` (all of them when empty), as a
/// JSON array in display order. Search lives in `ttime-core`.
#[wasm_bindgen]
pub fn search_symbols_json(query: &str) -> String {
    let items: Vec<String> = ttime_core::symbols::search(query)
        .iter()
        .map(|s| {
            format!(
                "{{\"id\":{},\"category\":{},\"text\":{},\"ewts\":{},\"name\":{},\"label\":{},\"note\":{},\"evidence\":{},\"codePoints\":{}}}",
                json_string(&s.id),
                json_string(&s.category),
                json_string(&s.text),
                s.ewts.as_deref().map_or("null".to_string(), json_string),
                json_string(&s.name),
                json_string(&s.label),
                json_string(&s.note),
                json_string(&s.evidence),
                json_string(&s.code_points())
            )
        })
        .collect();
    format!("[{}]", items.join(","))
}

/// Category names in order of first appearance, as a JSON array.
#[wasm_bindgen]
pub fn symbol_categories_json() -> String {
    let items: Vec<String> = ttime_core::symbols::categories()
        .into_iter()
        .map(json_string)
        .collect();
    format!("[{}]", items.join(","))
}

#[wasm_bindgen]
pub struct Session {
    inner: ttime_core::Session,
}

#[wasm_bindgen]
impl Session {
    #[wasm_bindgen(constructor)]
    pub fn new(precomposed: bool, diplomatic: Option<bool>) -> Session {
        Session {
            inner: ttime_core::Session::with_options(Options {
                precomposed,
                diplomatic: diplomatic.unwrap_or(false),
            }),
        }
    }

    /// Feeds typed characters one at a time, committing at spaces and newlines.
    pub fn insert_text(&mut self, text: &str) {
        self.inner.insert_text(text);
    }

    /// Removes the last provisional keystroke. Returns false, changing nothing,
    /// when there is no provisional text.
    pub fn backspace(&mut self) -> bool {
        self.inner.backspace()
    }

    /// Drops the provisional run, keeping committed text.
    pub fn cancel(&mut self) {
        self.inner.cancel();
    }

    /// Commits whatever is provisional and returns the whole text.
    pub fn finish(&mut self) -> String {
        self.inner.finish()
    }

    /// Replaces the committed text (after the page edited it directly) and
    /// clears the provisional run.
    pub fn set_committed(&mut self, text: &str) {
        self.inner.set_committed(text);
    }

    pub fn reset(&mut self) {
        self.inner.reset();
    }

    pub fn committed(&self) -> String {
        self.inner.committed().to_string()
    }

    pub fn provisional(&self) -> String {
        self.inner.provisional()
    }

    /// The EWTS typed since the last commit.
    pub fn raw(&self) -> String {
        self.inner.raw().to_string()
    }

    /// Diagnostics for the provisional run only; spans are UTF-8 byte offsets
    /// into [`Session::raw`].
    pub fn diagnostics_json(&self) -> String {
        diagnostics_json(&self.inner.diagnostics())
    }

    pub fn precomposed(&self) -> bool {
        self.inner.precomposed()
    }

    pub fn diplomatic(&self) -> bool {
        self.inner.diplomatic()
    }

    /// Latin mode passes typed text through unchanged; switching fixes the
    /// pending run first, so nothing is lost.
    pub fn set_latin(&mut self, on: bool) {
        self.inner.set_latin(on);
    }

    pub fn latin(&self) -> bool {
        self.inner.latin()
    }

    /// Dead keys for the IAST letters in Latin mode: `;` then a key gives the
    /// lower-case letter, `:` then a key gives the capital.
    pub fn set_dead_keys(&mut self, on: bool) {
        self.inner.set_dead_keys(on);
    }

    pub fn dead_keys(&self) -> bool {
        self.inner.dead_keys()
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
