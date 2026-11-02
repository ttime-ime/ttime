//! Platform-independent Tibetan input engine.
//!
//! Converts Extended Wylie (EWTS) to Tibetan Unicode. The mapping tables are
//! our own; Keyman's `tibetan_ewts` and m17n's `bo-ewts` were used only as
//! behavioural references.

mod ewts;
mod engine;

pub use engine::Engine;
pub use ewts::{ewts_to_unicode, ewts_to_unicode_with, Options};
