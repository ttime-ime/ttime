import Foundation

/// The long-press accent palette for Latin mode: hold a letter and a small strip offers
/// its IAST variants (hold `a` for `ā`). Pure state, like `SanskritSuggester`: the
/// composer decides when to open it, the panel draws it.
///
/// There is no key-release event in an input method, so the palette stays open after
/// the key is let go, as the system's own does, until a variant is chosen or another
/// key closes it. Closing keeps the plain letter.
struct AccentPalette {
    /// Variants of each lowercase letter, in the order they are numbered. All are
    /// single precomposed (NFC) code points, so they behave as one letter when edited.
    static let lower: [String: [String]] = [
        "a": ["ā"], "i": ["ī"], "u": ["ū"],
        "r": ["ṛ", "ṝ"], "l": ["ḷ", "ḹ"],
        "m": ["ṃ"], "h": ["ḥ"],
        "n": ["ṅ", "ñ", "ṇ"],
        "t": ["ṭ"], "d": ["ḍ"],
        "s": ["ś", "ṣ"],
    ]

    /// The variants of one typed letter (capitals give capitals); empty when it has none.
    static func variants(for letter: String) -> [String] {
        guard letter.count == 1 else { return [] }
        if let v = lower[letter] { return v }
        if letter != letter.lowercased(), let v = lower[letter.lowercased()] { return v.map { $0.uppercased() } }
        return []
    }

    static func hasVariants(_ letter: String) -> Bool { !variants(for: letter).isEmpty }

    private(set) var options: [String] = []
    /// The highlighted variant; nil until an arrow key moves onto one, so a stray
    /// Return or Space never picks one by accident.
    private(set) var selected: Int?

    var isOpen: Bool { !options.isEmpty }

    mutating func open(for letter: String) {
        options = Self.variants(for: letter)
        selected = nil
    }

    mutating func close() {
        options = []
        selected = nil
    }

    /// Moves the highlight; from nothing, forward starts at the first and back at the last.
    mutating func move(_ delta: Int) {
        guard isOpen else { return }
        if let s = selected { selected = min(max(s + delta, 0), options.count - 1) }
        else { selected = delta > 0 ? 0 : options.count - 1 }
    }

    /// Moves the highlight forward, from the last back to the first (Tab).
    mutating func cycle() {
        guard isOpen else { return }
        selected = ((selected ?? -1) + 1) % options.count
    }

    /// The variant shown under a number key (1 is the first).
    func option(number: Int) -> String? {
        options.indices.contains(number - 1) ? options[number - 1] : nil
    }
}
