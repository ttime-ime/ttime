import Foundation

/// The word list behind the Sanskrit (IAST) suggestions: accented words with a usage
/// count, searched by what the user types without diacritics. See
/// docs/reference/sanskrit-spike.md for the measurements that shaped it.
final class SanskritLexicon {
    struct Entry {
        let word: String
        let key: String      // the word with diacritics removed, lowercase
        let count: Int
        let buddhist: Bool
        let length: Int
    }

    /// Entries sorted by key, so every prefix is one contiguous range.
    private var entries: [Entry] = []
    /// Position of each entry in the ranking, best first (indexes `entries`).
    private var rank: [Int32] = []

    /// The IAST letters and what they are typed as (the rest is ASCII already).
    private static let plain: [Unicode.Scalar: Unicode.Scalar] = {
        var m: [Unicode.Scalar: Unicode.Scalar] = [:]
        let pairs = ["ā": "a", "ī": "i", "ū": "u", "ṛ": "r", "ṝ": "r", "ḷ": "l", "ḹ": "l", "ṃ": "m", "ḥ": "h",
                     "ṅ": "n", "ñ": "n", "ṭ": "t", "ḍ": "d", "ṇ": "n", "ś": "s", "ṣ": "s", "ḻ": "l",
                     "Ā": "a", "Ī": "i", "Ū": "u", "Ṛ": "r", "Ṃ": "m", "Ḥ": "h", "Ṅ": "n", "Ñ": "n",
                     "Ṭ": "t", "Ḍ": "d", "Ṇ": "n", "Ś": "s", "Ṣ": "s"]
        for (k, v) in pairs { m[k.unicodeScalars.first!] = v.unicodeScalars.first! }
        return m
    }()

    /// What the user types: the word without diacritics, lowercase.
    static func fold(_ s: String) -> String {
        var out = String.UnicodeScalarView()
        for u in s.unicodeScalars {
            if let p = plain[u] { out.append(p) }
            else if u.value < 0x80 { out.append(contentsOf: String(u).lowercased().unicodeScalars) }
            else if u == "\u{2019}" { continue }
            else {
                // Anything else: decompose and drop combining marks (NFD input, unusual letters).
                for d in String(u).decomposedStringWithCanonicalMapping.unicodeScalars
                where d.properties.canonicalCombiningClass.rawValue == 0 {
                    out.append(contentsOf: String(d).lowercased().unicodeScalars)
                }
            }
        }
        return String(out)
    }

    /// Parses `word<TAB>count<TAB>flag` lines.
    convenience init(tsv: String) { self.init(data: Data(tsv.utf8)) }

    init(data: Data) {
        var list: [Entry] = []
        list.reserveCapacity(210_000)
        data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            let bytes = raw.bindMemory(to: UInt8.self)
            var i = 0
            let n = bytes.count
            while i < n {
                // One line: word \t count \t flag
                var tab1 = i
                while tab1 < n, bytes[tab1] != 9, bytes[tab1] != 10 { tab1 += 1 }
                guard tab1 < n, bytes[tab1] == 9 else { while i < n, bytes[i] != 10 { i += 1 }; i += 1; continue }
                var tab2 = tab1 + 1
                while tab2 < n, bytes[tab2] != 9, bytes[tab2] != 10 { tab2 += 1 }
                var end = tab2 + 1
                while end < n, bytes[end] != 10 { end += 1 }
                var count = 0
                for j in (tab1 + 1)..<tab2 { count = count * 10 + Int(bytes[j] &- 48) }
                let flag = tab2 + 1 < end ? bytes[tab2 + 1] : 45
                let word = String(decoding: UnsafeBufferPointer(rebasing: bytes[i..<tab1]), as: UTF8.self)
                list.append(Entry(word: word, key: Self.fold(word), count: count, buddhist: flag == 98,
                                  length: word.unicodeScalars.count))
                i = end + 1
            }
        }
        // The best word of a key first: more occurrences, then a Buddhist word, then
        // the shorter, then alphabetical.
        let better: (Entry, Entry) -> Bool = { a, b in
            if a.count != b.count { return a.count > b.count }
            if a.buddhist != b.buddhist { return a.buddhist }
            if a.length != b.length { return a.length < b.length }
            return a.word.utf8.lexicographicallyPrecedes(b.word.utf8)
        }
        entries = list.sorted {
            $0.key != $1.key ? $0.key.utf8.lexicographicallyPrecedes($1.key.utf8) : better($0, $1)
        }
        let order = entries.indices.sorted { better(entries[$0], entries[$1]) }
        rank = [Int32](repeating: 0, count: entries.count)
        for (r, i) in order.enumerated() { rank[i] = Int32(r) }
    }

    convenience init?(contentsOf url: URL) {
        guard let data = try? Data(contentsOf: url) else { return nil }
        self.init(data: data)
    }

    var count: Int { entries.count }

    /// The bundled list, loaded once in the background the first time it is wanted, so
    /// typing never waits for it. Nil until it is ready.
    private static var loaded: SanskritLexicon?
    private static var loading = false
    static var shared: SanskritLexicon? {
        if let l = loaded { return l }
        if !loading, let url = Bundle.main.url(forResource: "iast-lexicon", withExtension: "tsv") {
            loading = true
            DispatchQueue.global(qos: .utility).async {
                let l = SanskritLexicon(contentsOf: url)
                DispatchQueue.main.async { loaded = l; loading = false }
            }
        }
        return nil
    }

    /// The best `limit` words whose accent-free spelling starts with `typed`.
    func suggest(_ typed: String, limit: Int = 5) -> [String] {
        let key = Self.fold(typed)
        guard !key.isEmpty else { return [] }
        // First entry whose key is >= key, and first whose key no longer has the prefix.
        var lo = 0, hi = entries.count
        while lo < hi { let m = (lo + hi) / 2; if entries[m].key.utf8.lexicographicallyPrecedes(key.utf8) { lo = m + 1 } else { hi = m } }
        let start = lo
        var end = start
        while end < entries.count, entries[end].key.hasPrefix(key) { end += 1 }
        guard end > start else { return [] }
        var best: [Int] = []
        for i in start..<end {
            if best.count < limit {
                best.append(i)
            } else if let worst = best.max(by: { rank[$0] < rank[$1] }), rank[i] < rank[worst] {
                best[best.firstIndex(of: worst)!] = i
            }
        }
        return best.sorted { rank[$0] < rank[$1] }.map { entries[$0].word }
    }
}

/// The word being typed in Latin mode, and the suggestions for it. Pure state: the
/// composer turns keys into calls on it. Nothing is ever replaced unless the user
/// accepts a suggestion; typed text is otherwise committed exactly as typed.
struct SanskritSuggester {
    /// A list is offered once this many letters are typed.
    static let minimumLetters = 3

    let lexicon: SanskritLexicon
    private(set) var buffer = ""
    private(set) var suggestions: [String] = []
    private(set) var selected = 0

    init(lexicon: SanskritLexicon) { self.lexicon = lexicon }

    var isEmpty: Bool { buffer.isEmpty }

    /// Whether a typed character belongs to a word (an ASCII letter).
    static func isLetter(_ s: String) -> Bool {
        s.count == 1 && s.unicodeScalars.allSatisfy { ($0.value >= 0x41 && $0.value <= 0x5A) || ($0.value >= 0x61 && $0.value <= 0x7A) }
    }

    mutating func type(_ letter: String) {
        buffer += letter
        refresh()
    }

    @discardableResult
    mutating func backspace() -> Bool {
        guard !buffer.isEmpty else { return false }
        buffer.removeLast()
        refresh()
        return true
    }

    mutating func move(_ delta: Int) {
        guard !suggestions.isEmpty else { return }
        selected = min(max(selected + delta, 0), suggestions.count - 1)
    }

    /// Highlights the suggestion at `index`; false if there is none.
    @discardableResult
    mutating func select(_ index: Int) -> Bool {
        guard suggestions.indices.contains(index) else { return false }
        selected = index
        return true
    }

    /// Swaps the last typed letter for `letter` (an accent chosen from the palette).
    mutating func replaceLast(with letter: String) {
        guard !buffer.isEmpty else { return }
        buffer.removeLast()
        buffer += letter
        refresh()
    }

    /// The typed text, exactly as typed; clears the buffer.
    mutating func flush() -> String {
        defer { clear() }
        return buffer
    }

    /// The selected suggestion, in the capitalisation the user began with; clears the
    /// buffer. Nil when there is nothing to accept.
    mutating func accept() -> String? {
        guard suggestions.indices.contains(selected) else { return nil }
        var word = suggestions[selected]
        if buffer.first?.isUppercase == true { word = word.prefix(1).uppercased() + word.dropFirst() }
        clear()
        return word
    }

    mutating func clear() {
        buffer = ""
        suggestions = []
        selected = 0
    }

    /// Suggestions as they would be shown (capitalised like the typed text).
    var shown: [String] {
        buffer.first?.isUppercase == true ? suggestions.map { $0.prefix(1).uppercased() + $0.dropFirst() } : suggestions
    }

    private mutating func refresh() {
        selected = 0
        suggestions = buffer.count >= Self.minimumLetters ? lexicon.suggest(buffer) : []
    }
}
