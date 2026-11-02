// Shared helpers. Every target caps its input so a run cannot spend its time
// on a single huge case.

use ttime_core::Diagnostic;

pub const MAX_INPUT_BYTES: usize = 4096;

/// Spans must be in order, on char boundaries and inside the input.
pub fn check_spans(input: &str, diags: &[Diagnostic]) {
    for d in diags {
        assert!(d.span.start <= d.span.end && d.span.end <= input.len(), "{d:?}");
        assert!(input.is_char_boundary(d.span.start), "{d:?}");
        assert!(input.is_char_boundary(d.span.end), "{d:?}");
    }
}
