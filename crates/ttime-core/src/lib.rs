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
mod json;
pub mod policy;
pub mod symbols;

pub use composition::{Engine, Session};
pub use ewts::{
    build_stack, build_stack_json, convert, ewts_to_unicode, ewts_to_unicode_with, stack_alphabet,
    stack_alphabet_json, unicode_to_ewts, Alphabet, Category, Code, Conversion, Diagnostic,
    Fidelity, Letter, Options, Reverse, Severity, Stack, StackError,
};
pub use policy::{
    AccentPalette, Composer, KeyInput, ModeLock, Outcome, SanskritLexicon, SanskritSuggester,
    ShiftSide, ShiftTap, ShiftTapEvent, ShiftTapKind, StackerModel, SymbolsModel,
};

/// Crate version, for builds that report which core produced a result.
pub const VERSION: &str = env!("CARGO_PKG_VERSION");
