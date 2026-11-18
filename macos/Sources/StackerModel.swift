import Foundation

/// One selectable letter, vowel or mark: its EWTS key and an example of how it looks.
struct StackLetter: Equatable {
    let key: String
    let example: String
}

/// Everything the engine's stack builder accepts.
struct StackAlphabet {
    var consonants: [StackLetter] = []
    var subjoinedOnly: [StackLetter] = []
    var vowels: [StackLetter] = []
    var marks: [StackLetter] = []

    static func load() -> StackAlphabet {
        guard let json = take(ttime_stack_alphabet_json()),
              let obj = (try? JSONSerialization.jsonObject(with: Data(json.utf8))) as? [String: Any]
        else { return StackAlphabet() }
        func list(_ name: String) -> [StackLetter] {
            (obj[name] as? [[String: String]] ?? []).compactMap { d in
                guard let k = d["key"], let e = d["example"] else { return nil }
                return StackLetter(key: k, example: e)
            }
        }
        return StackAlphabet(consonants: list("consonants"), subjoinedOnly: list("subjoinedOnly"),
                             vowels: list("vowels"), marks: list("marks"))
    }
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

/// Reads and frees a string returned by the C API.
func take(_ p: UnsafeMutablePointer<CChar>?) -> String? {
    guard let p = p else { return nil }
    defer { ttime_string_free(p) }
    return String(cString: p)
}

/// The stacker's state and rules, with no UI: which letters are chosen, what is
/// being typed, and what the engine makes of it. The engine builds every stack,
/// so what the window shows cannot disagree with typing.
final class StackerModel {
    /// Starting points. Each is built by the engine like any other stack.
    static let presets: [(label: String, letters: [String])] = [
        ("kṣa", ["k", "Sh"]), ("jña", ["j", "ny"]), ("ṣṭha", ["Sh", "Th"]), ("stra", ["s", "t", "r"]),
        ("ddhya", ["d", "dh", "y"]), ("kṣma", ["k", "Sh", "m"]), ("rgya", ["r", "g", "y"]),
        ("bsgrub", ["b", "s", "g", "r"]),
    ]

    let alphabet: StackAlphabet
    var precomposed = false

    private(set) var layers: [String] = []
    private(set) var vowel = ""  // "" is the inherent a
    private(set) var marks: [String] = []
    /// EWTS typed so far for the next letter.
    private(set) var typed = ""
    /// A short message for the person: why a key did nothing, or what was inserted.
    private(set) var hint = ""
    private(set) var result: StackResult = .empty

    init(alphabet: StackAlphabet = .load()) {
        self.alphabet = alphabet
        rebuild()
    }

    private var consonantKeys: [String] { alphabet.consonants.map(\.key) }
    private var subjoinedOnlyKeys: Set<String> { Set(alphabet.subjoinedOnly.map(\.key)) }
    private var addableKeys: [String] { consonantKeys + alphabet.subjoinedOnly.map(\.key) }

    var built: BuiltStack? {
        if case .built(let b) = result { return b }
        return nil
    }

    /// Letters whose keys start with what has been typed (all of them when nothing is).
    func matches(_ key: String) -> Bool { typed.isEmpty || key.hasPrefix(typed) }

    /// The key that what is typed stands for: an exact match, else the only candidate.
    var typedKey: String? {
        if typed.isEmpty { return nil }
        let all = addableKeys
        if all.contains(typed) { return typed }
        let candidates = all.filter { $0.hasPrefix(typed) }
        return candidates.count == 1 ? candidates[0] : nil
    }

    // MARK: Changes

    /// Adds a letter below the others. A letter that only exists under another
    /// one needs a letter above it.
    @discardableResult
    func addLayer(_ key: String) -> Bool {
        typed = ""
        if subjoinedOnlyKeys.contains(key) && layers.isEmpty {
            hint = "\(key) only exists under another letter. Add a letter first."
            return false
        }
        layers.append(key)
        changed()
        return true
    }

    func removeLayer(at i: Int) {
        guard layers.indices.contains(i) else { return }
        layers.remove(at: i)
        changed()
    }

    func setVowel(_ v: String) {
        vowel = vowel == v ? "" : v
        changed()
    }

    func toggleMark(_ m: String) {
        if marks.contains(m) { marks.removeAll { $0 == m } } else { marks.append(m) }
        changed()
    }

    func usePreset(_ letters: [String]) {
        layers = letters
        vowel = ""
        marks = []
        typed = ""
        changed()
    }

    func clear() {
        layers = []
        vowel = ""
        marks = []
        typed = ""
        changed()
    }

    func setHint(_ s: String) { hint = s }

    func type(_ s: String) {
        typed += s
        hint = ""
    }

    /// Adds the letter that is typed. False if what is typed names no letter.
    @discardableResult
    func confirmTyped() -> Bool {
        guard let key = typedKey else {
            if !typed.isEmpty { hint = "\(typed) is not a letter the stacker knows." }
            return false
        }
        return addLayer(key)
    }

    /// Deletes the last typed character, else the last letter. False if nothing was left to delete.
    @discardableResult
    func backspace() -> Bool {
        if !typed.isEmpty {
            typed.removeLast()
            hint = ""
            return true
        }
        guard !layers.isEmpty else { return false }
        layers.removeLast()
        changed()
        return true
    }

    /// Takes the finished stack to insert it, and starts the next one.
    func consume() -> BuiltStack? {
        guard let b = built else { return nil }
        layers = []
        vowel = ""
        marks = []
        typed = ""
        rebuild()
        hint = "Inserted \(b.text). Next time, type \(b.shortest)."
        return b
    }

    // MARK: Building

    private func changed() {
        hint = ""
        rebuild()
    }

    private func rebuild() {
        guard !layers.isEmpty else { result = .empty; return }
        let json = take(ttime_build_stack_json(layers.joined(separator: " "), vowel,
                                               marks.joined(separator: " "), precomposed))
        guard let json = json,
              let obj = (try? JSONSerialization.jsonObject(with: Data(json.utf8))) as? [String: Any]
        else { result = .failed("The engine gave no answer."); return }
        guard obj["ok"] as? Bool == true else {
            result = .failed(obj["error"] as? String ?? "Cannot build this stack.")
            return
        }
        let notes = (obj["diagnostics"] as? [[String: Any]] ?? []).compactMap { $0["message"] as? String }
        result = .built(BuiltStack(text: obj["text"] as? String ?? "",
                                   canonical: obj["canonical"] as? String ?? "",
                                   shortest: obj["shortest"] as? String ?? "",
                                   codePoints: obj["codePoints"] as? String ?? "",
                                   notes: notes))
    }
}
