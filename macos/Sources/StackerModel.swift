import Foundation

/// One selectable letter, vowel or mark: its EWTS key and an example of how it looks.
struct StackLetter: Equatable {
    let key: String
    let example: String
}

/// Everything the engine's stack builder accepts. It never changes, so it is read once.
struct StackAlphabet {
    var consonants: [StackLetter] = []
    var subjoinedOnly: [StackLetter] = []
    var vowels: [StackLetter] = []
    var marks: [StackLetter] = []

    static let shared: StackAlphabet = {
        guard let obj = stackerJSON(ttime_stack_alphabet_json()) else { return StackAlphabet() }
        func list(_ name: String) -> [StackLetter] {
            (obj[name] as? [[String: String]] ?? []).compactMap { d in
                guard let k = d["key"], let e = d["example"] else { return nil }
                return StackLetter(key: k, example: e)
            }
        }
        return StackAlphabet(consonants: list("consonants"), subjoinedOnly: list("subjoinedOnly"),
                             vowels: list("vowels"), marks: list("marks"))
    }()
}

/// A finished stack, as the engine reports it.
struct BuiltStack: Equatable {
    var text: String
    var canonical: String  // every letter joined with +
    var shortest: String  // the shortest EWTS that gives the same text
    var codePoints: String
    var notes: [String]  // what the engine says about it
}

enum StackResult: Equatable {
    case empty
    case built(BuiltStack)
    case failed(String)
}

/// Reads, frees and parses a JSON object returned by the C API.
private func stackerJSON(_ p: UnsafeMutablePointer<CChar>?) -> [String: Any]? {
    guard let p = p else { return nil }
    defer { ttime_string_free(p) }
    return (try? JSONSerialization.jsonObject(with: Data(String(cString: p).utf8))) as? [String: Any]
}

/// The stacker's state and rules, which live in `ttime-core` (`ttime_stacker_*`);
/// this class mirrors the state for the panel after every change. The engine builds
/// every stack, so what the window shows cannot disagree with typing.
final class StackerModel {
    /// Starting points. Each is built by the engine like any other stack.
    static let presets: [(label: String, letters: [String])] = [
        ("kṣa", ["k", "Sh"]), ("jña", ["j", "ny"]), ("ṣṭha", ["Sh", "Th"]), ("stra", ["s", "t", "r"]),
        ("ddhya", ["d", "dh", "y"]), ("kṣma", ["k", "Sh", "m"]), ("rgya", ["r", "g", "y"]),
        ("bsgrub", ["b", "s", "g", "r"]),
    ]

    private let ptr: OpaquePointer?
    let alphabet = StackAlphabet.shared

    /// The output form; changing it rebuilds the current stack.
    var precomposed = false {
        didSet {
            guard precomposed != oldValue else { return }
            ttime_stacker_set_precomposed(ptr, precomposed)
            refresh()
        }
    }

    private(set) var layers: [String] = []
    private(set) var vowel = ""  // "" is the inherent a
    private(set) var marks: [String] = []
    /// EWTS typed so far for the next letter.
    private(set) var typed = ""
    /// The key that what is typed stands for: an exact match, else the only candidate.
    private(set) var typedKey: String?
    /// A short message for the person: why a key did nothing, or what was inserted.
    private(set) var hint = ""
    private(set) var result: StackResult = .empty

    init() {
        ptr = ttime_stacker_new(false)
        refresh()
    }

    deinit { ttime_stacker_free(ptr) }

    var built: BuiltStack? {
        if case .built(let b) = result { return b }
        return nil
    }

    /// Letters whose keys start with what has been typed (all of them when nothing is).
    func matches(_ key: String) -> Bool { key.withCString { ttime_stacker_matches(ptr, $0) } }

    /// Adds a letter below the others. A letter that only exists under another
    /// one needs a letter above it.
    @discardableResult
    func addLayer(_ key: String) -> Bool { change { key.withCString { ttime_stacker_add_layer(ptr, $0) } } }

    func removeLayer(at i: Int) { change { ttime_stacker_remove_layer(ptr, Int32(clamping: i)) } }

    func setVowel(_ v: String) { change { v.withCString { ttime_stacker_set_vowel(ptr, $0) } } }

    func toggleMark(_ m: String) { change { m.withCString { ttime_stacker_toggle_mark(ptr, $0) } } }

    func usePreset(_ letters: [String]) {
        change { letters.joined(separator: " ").withCString { ttime_stacker_use_preset(ptr, $0) } }
    }

    func clear() { change { ttime_stacker_clear(ptr) } }

    func setHint(_ s: String) { change { s.withCString { ttime_stacker_set_hint(ptr, $0) } } }

    func type(_ s: String) { change { s.withCString { ttime_stacker_type(ptr, $0) } } }

    /// Adds the letter that is typed. False if what is typed names no letter.
    @discardableResult
    func confirmTyped() -> Bool { change { ttime_stacker_confirm_typed(ptr) } }

    /// Deletes the last typed character, else the last letter. False if nothing was left to delete.
    @discardableResult
    func backspace() -> Bool { change { ttime_stacker_backspace(ptr) } }

    /// Takes the finished stack to insert it, and starts the next one.
    func consume() -> BuiltStack? {
        let b = built
        change { ttime_string_free(ttime_stacker_consume(ptr)) }
        return b
    }

    private func change<T>(_ body: () -> T) -> T {
        let r = body()
        refresh()
        return r
    }

    private func refresh() {
        guard let obj = stackerJSON(ttime_stacker_state_json(ptr)) else { return }
        layers = obj["layers"] as? [String] ?? []
        vowel = obj["vowel"] as? String ?? ""
        marks = obj["marks"] as? [String] ?? []
        typed = obj["typed"] as? String ?? ""
        typedKey = obj["typedKey"] as? String
        hint = obj["hint"] as? String ?? ""
        guard let r = obj["result"] as? [String: Any] else { result = .empty; return }
        switch r["kind"] as? String {
        case "built":
            result = .built(BuiltStack(text: r["text"] as? String ?? "",
                                       canonical: r["canonical"] as? String ?? "",
                                       shortest: r["shortest"] as? String ?? "",
                                       codePoints: r["codePoints"] as? String ?? "",
                                       notes: r["notes"] as? [String] ?? []))
        case "failed":
            result = .failed(r["error"] as? String ?? "Cannot build this stack.")
        default:
            result = .empty
        }
    }
}
