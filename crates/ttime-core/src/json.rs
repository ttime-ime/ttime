//! Minimal JSON writing for the native and web bridges, so the two cannot
//! disagree about the shape of a result. Writing only; no parser is needed here.

use crate::ewts::Diagnostic;

pub(crate) fn string(s: &str) -> String {
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

pub(crate) fn diagnostics(diags: &[Diagnostic]) -> String {
    let items: Vec<String> = diags
        .iter()
        .map(|d| {
            format!(
                "{{\"code\":{},\"category\":{},\"severity\":{},\"start\":{},\"end\":{},\"message\":{}}}",
                string(d.code.as_str()),
                string(&format!("{:?}", d.category)),
                string(&format!("{:?}", d.severity)),
                d.span.start,
                d.span.end,
                string(&d.message)
            )
        })
        .collect();
    format!("[{}]", items.join(","))
}
