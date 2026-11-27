import Foundation

/// What the dictionary tab looks up, and where. The panel shows Christian
/// Steinert's Tibetan-English dictionary from its own website; nothing from it is
/// bundled. Pure Foundation so the term rules are tested without any UI.
enum DictionaryLookup {
    static let site = "https://dictionary.christian-steinert.de/"

    /// The site's search page for a Tibetan term (it takes Unicode in the URL).
    static func url(for term: String) -> URL? {
        let t = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/?#&=+%")
        guard let e = t.addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
        return URL(string: "\(site)#/search/tib/\(e)?activeTerm=\(e)")
    }

    /// Tibetan letters, subjoined letters and vowel signs (U+0F40...U+0FBC).
    private static func isTibetanLetter(_ s: Unicode.Scalar) -> Bool { (0x0F40...0x0FBC).contains(s.value) }

    /// A tsheg, a shad or any other mark that can sit between syllables.
    private static func isSeparator(_ s: Unicode.Scalar) -> Bool {
        CharacterSet.whitespacesAndNewlines.contains(s) || (0x0F0B...0x0F14).contains(s.value)
    }

    /// The term to look up: the selection if there is one (trimmed of spaces and
    /// trailing marks), else the syllable just before the caret.
    static func term(selection: String?, before: String?) -> String {
        if let s = selection {
            var scalars = Array(s.unicodeScalars)
            while let l = scalars.last, isSeparator(l) { scalars.removeLast() }
            while let f = scalars.first, CharacterSet.whitespacesAndNewlines.contains(f) { scalars.removeFirst() }
            if !scalars.isEmpty { return String(String.UnicodeScalarView(scalars)) }
        }
        guard let b = before else { return "" }
        var scalars = Array(b.unicodeScalars)
        while let l = scalars.last, isSeparator(l) { scalars.removeLast() }
        var out: [Unicode.Scalar] = []
        while let l = scalars.last, isTibetanLetter(l) { out.insert(l, at: 0); scalars.removeLast() }
        return String(String.UnicodeScalarView(out))
    }
}
