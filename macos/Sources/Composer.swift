import Foundation

/// A keystroke reduced to what the engine cares about.
enum KeyInput {
    /// Printable characters; all of ASCII is EWTS input.
    case text(String)
    case backspace
    case escape
    case enter
    /// Navigation keys, used by the stacker and symbols windows when open.
    case tab, up, down, left, right
    /// Anything else (shortcuts and so on): commit what is pending, then let the
    /// application handle the key.
    case other

    /// The characters of a `.text` key.
    var textValue: String { if case .text(let s) = self { return s } else { return "" } }
    var isUp: Bool { if case .up = self { return true } else { return false } }

    fileprivate var kind: Int32 {
        switch self {
        case .text: return Int32(TTIME_KEY_TEXT)
        case .backspace: return Int32(TTIME_KEY_BACKSPACE)
        case .escape: return Int32(TTIME_KEY_ESCAPE)
        case .enter: return Int32(TTIME_KEY_ENTER)
        case .tab: return Int32(TTIME_KEY_TAB)
        case .up: return Int32(TTIME_KEY_UP)
        case .down: return Int32(TTIME_KEY_DOWN)
        case .left: return Int32(TTIME_KEY_LEFT)
        case .right: return Int32(TTIME_KEY_RIGHT)
        case .other: return Int32(TTIME_KEY_OTHER)
        }
    }
}

/// What the input controller should do with the client application.
struct Outcome: Equatable {
    /// Text to insert into the document (committed Tibetan), possibly empty.
    var insert = ""
    /// The whole provisional run to show as marked text; empty clears it.
    var marked = ""
    /// Typed text just before the caret that `insert` takes the place of (a Sanskrit
    /// word being completed, or a letter given an accent); empty when `insert` is added
    /// at the caret as it is.
    var replacing = ""
    /// Whether T-Time consumed the key. If false the application gets it.
    var handled = false

    /// Copies a C outcome and frees its strings.
    fileprivate init(taking raw: ttime_outcome) {
        var raw = raw
        insert = raw.insert.map { String(cString: $0) } ?? ""
        marked = raw.marked.map { String(cString: $0) } ?? ""
        replacing = raw.replacing.map { String(cString: $0) } ?? ""
        handled = raw.handled
        ttime_outcome_free(&raw)
    }

    init(insert: String = "", marked: String = "", replacing: String = "", handled: Bool = false) {
        self.insert = insert
        self.marked = marked
        self.replacing = replacing
        self.handled = handled
    }
}

/// Reads and frees a string returned by the C API; nil for a NULL pointer.
private func takeString(_ p: UnsafeMutablePointer<CChar>?) -> String? {
    guard let p = p else { return nil }
    defer { ttime_string_free(p) }
    return String(cString: p)
}

private func jsonObject(_ s: String?) -> [String: Any]? {
    guard let s = s else { return nil }
    return (try? JSONSerialization.jsonObject(with: Data(s.utf8))) as? [String: Any]
}

/// The IME key policy, which lives in `ttime-core` (`ttime_composer_*`); this class
/// only converts between Swift and C. No UI dependencies, so it is testable.
final class Composer {
    private let ptr: OpaquePointer?

    init(precomposed: Bool = false) {
        ptr = ttime_composer_new(precomposed)
    }

    deinit { ttime_composer_free(ptr) }

    /// Switches the output form. Anything being typed is dropped, so call it only
    /// between compositions (when focus arrives).
    func setPrecomposed(_ on: Bool) { ttime_composer_set_precomposed(ptr, on) }

    /// Whether holding a letter offers its accented variants. Set it between words.
    var accents: Bool {
        get { ttime_composer_accents(ptr) }
        set { ttime_composer_set_accents(ptr, newValue) }
    }

    /// Sanskrit suggestions for Latin mode; nil when off or the word list is not loaded.
    /// The list is shared, so assigning it is cheap. Set it only between words (when
    /// focus arrives, after `reset`): it forgets the word being typed.
    var lexicon: SanskritLexicon? {
        didSet { ttime_composer_set_lexicon(ptr, lexicon?.ptr) }
    }

    /// What to show in the suggestion list, or nil when there is no list.
    var suggestionList: (words: [String], selected: Int)? {
        guard let obj = jsonObject(takeString(ttime_composer_suggestion_json(ptr))),
              let words = obj["words"] as? [String],
              let selected = obj["selected"] as? Int
        else { return nil }
        return (words, selected)
    }

    /// The word being typed in Latin mode. It is already in the document (typed as it
    /// is, with no underline); a suggestion replaces it.
    var suggestionBuffer: String { takeString(ttime_composer_suggestion_buffer(ptr)) ?? "" }

    /// What to show in the accent palette, or nil when it is closed.
    var accentList: (options: [String], selected: Int?)? {
        guard let obj = jsonObject(takeString(ttime_composer_accent_json(ptr))),
              let options = obj["options"] as? [String]
        else { return nil }
        return (options, obj["selected"] as? Int)
    }

    /// Accepts the suggestion at `index` (a click); nothing happens if there is no list.
    func chooseSuggestion(index: Int) -> Outcome {
        Outcome(taking: ttime_composer_choose_suggestion(ptr, Int32(clamping: index)))
    }

    /// Picks the highlighted variant (the held key was let go); nothing if none is highlighted.
    func chooseHighlightedAccent() -> Outcome {
        Outcome(taking: ttime_composer_choose_highlighted_accent(ptr))
    }

    /// Picks the palette entry at `index` (a click); nothing happens if it is closed.
    func chooseAccent(index: Int) -> Outcome {
        Outcome(taking: ttime_composer_choose_accent(ptr, Int32(clamping: index)))
    }

    /// `isRepeat` is true for the repeats of a held key (a long press).
    func handle(_ key: KeyInput, isRepeat: Bool = false) -> Outcome {
        key.textValue.withCString { p in
            Outcome(taking: ttime_composer_handle(ptr, key.kind, p, isRepeat))
        }
    }

    var isLatin: Bool { ttime_composer_is_latin(ptr) }

    /// Switches between Tibetan and Latin. Pending Tibetan is fixed first and
    /// comes back as `insert`; the marked text is cleared.
    func setLatin(_ on: Bool) -> Outcome { Outcome(taking: ttime_composer_set_latin(ptr, on)) }

    /// Commits any pending text and returns everything not yet inserted.
    func commitAll() -> String { takeString(ttime_composer_commit_all(ptr)) ?? "" }

    /// Forgets pending input, for example when the input source is activated.
    func reset() { ttime_composer_reset(ptr) }
}
