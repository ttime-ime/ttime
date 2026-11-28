//! Neutral keystrokes and what the host should do with them.

/// A keystroke reduced to what the engine cares about.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum KeyInput {
    /// Printable characters; all of ASCII is EWTS input.
    Text(String),
    Backspace,
    Escape,
    Enter,
    /// Navigation keys, used by the stacker and symbols windows when open.
    Tab,
    Up,
    Down,
    Left,
    Right,
    /// Anything else (arrows in Tibetan mode, shortcuts): commit what is pending,
    /// then let the application handle the key.
    Other,
}

impl KeyInput {
    /// The characters of a [`KeyInput::Text`] key.
    pub fn text_value(&self) -> &str {
        match self {
            KeyInput::Text(s) => s,
            _ => "",
        }
    }

    pub fn is_up(&self) -> bool {
        matches!(self, KeyInput::Up)
    }
}

/// What the input controller should do with the client application.
#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct Outcome {
    /// Text to insert into the document (committed Tibetan), possibly empty.
    pub insert: String,
    /// The whole provisional run to show as marked text; empty clears it.
    pub marked: String,
    /// Typed text just before the caret that `insert` takes the place of (a Sanskrit
    /// word being completed, or a letter given an accent); empty when `insert` is added
    /// at the caret as it is.
    pub replacing: String,
    /// Whether T-Time consumed the key. If false the application gets it.
    pub handled: bool,
}

impl Outcome {
    pub fn handled_only() -> Self {
        Self {
            handled: true,
            ..Self::default()
        }
    }

    /// JSON: `{"insert","marked","replacing","handled"}`.
    pub fn to_json(&self) -> String {
        use crate::json::string;
        format!(
            "{{\"insert\":{},\"marked\":{},\"replacing\":{},\"handled\":{}}}",
            string(&self.insert),
            string(&self.marked),
            string(&self.replacing),
            if self.handled { "true" } else { "false" }
        )
    }
}
