import Foundation

/// Typing and display preferences, edited in the settings window.
enum Prefs {
    private static let d = UserDefaults.standard

    /// Emit the precomposed code points Unicode keeps for compatibility (U+0F43 for
    /// gha, and so on) instead of the normalised decomposed form. Off by default.
    static var precomposed: Bool {
        get { d.bool(forKey: "OutputPrecomposed") }
        set { d.set(newValue, forKey: "OutputPrecomposed") }
    }

    /// The mode a text field starts in when it gains focus (a lock overrides it).
    /// true is Latin; the default is Tibetan.
    static var startLatin: Bool {
        get { d.bool(forKey: "StartInLatin") }
        set { d.set(newValue, forKey: "StartInLatin") }
    }

    /// The opt-in key log, see DebugLog.
    static var debugKeys: Bool {
        get { d.bool(forKey: "DebugKeys") }
        set { d.set(newValue, forKey: "DebugKeys") }
    }
}
