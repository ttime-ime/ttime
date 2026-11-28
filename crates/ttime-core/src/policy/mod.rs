//! IME policy shared by every platform shell: key handling, accents, Sanskrit
//! suggestions, mode lock, shift-tap timing, stacker and symbols state, and
//! dictionary term rules. Drawing and OS event wiring stay in each shell.

mod accent;
mod composer;
#[cfg(test)]
mod composer_tests;
mod dictionary;
mod key;
mod mode_lock;
mod sanskrit;
mod shift_tap;
mod stacker;
mod symbols_model;

pub use accent::AccentPalette;
pub use composer::Composer;
pub use dictionary::{term as dictionary_term, url_for as dictionary_url, SITE as DICTIONARY_SITE};
pub use key::{KeyInput, Outcome};
pub use mode_lock::ModeLock;
pub use sanskrit::{SanskritLexicon, SanskritSuggester};
pub use shift_tap::{ShiftSide, ShiftTap, ShiftTapEvent, ShiftTapKind};
pub use stacker::{BuiltStack, StackLetter, StackResult, StackerModel};
pub use symbols_model::{SymbolEntry, SymbolsModel};
