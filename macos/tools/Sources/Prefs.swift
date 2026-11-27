import Foundation

/// Preferences for T-Time Tools. The look follows the IME's installer default when
/// the user has not chosen one here yet.
enum Prefs {
    private static let d = UserDefaults.standard
    /// The input method's own preferences, so the choices made in its Settings apply here.
    private static let ime = UserDefaults(suiteName: "io.github.ttime-ime.inputmethod.TTime")

    static var precomposed: Bool {
        get { ime?.bool(forKey: "OutputPrecomposed") ?? false }
        set { d.set(newValue, forKey: "OutputPrecomposed") }
    }

    /// Bubblegum or Brutalist; falls back to the file the installer wrote.
    static var styleName: String {
        get {
            if let s = d.string(forKey: "Style"), !s.isEmpty { return s }
            if let s = ime?.string(forKey: "Style"), !s.isEmpty { return s }
            let path = "/Library/Application Support/T-Time/default-style"
            return (try? String(contentsOfFile: path, encoding: .utf8))?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "bubblegum"
        }
        set { d.set(newValue, forKey: "Style") }
    }

    static var brutal: Bool { styleName == "brutal" }
}
