//! Platform-independent Tibetan input engine.
//!
//! Layer 1 (this crate today): deterministic EWTS to Unicode conversion
//! ([`ewts`]) and the composition state an IME front end drives
//! ([`composition`]). The mapping tables are our own; Keyman's
//! `tibetan_ewts`, m17n's `bo-ewts` and pyewts were used as references. See
//! `docs/specification/ewts.md`.
//!
//! The crate has no operating-system or GUI dependencies.

pub mod composition;
pub mod ewts;

pub use composition::{Engine, Session};
pub use ewts::{
    convert, ewts_to_unicode, ewts_to_unicode_with, unicode_to_ewts, Category, Code, Conversion,
    Diagnostic, Fidelity, Options, Reverse, Severity,
};

/// Crate version, for builds that report which core produced a result.
pub const VERSION: &str = env!("CARGO_PKG_VERSION");
