import Foundation

/// What the dictionary tab looks up, and where. The panel shows Christian
/// Steinert's Tibetan-English dictionary from its own website; nothing from it is
/// bundled. The term rules and the URL live in `ttime-core` (`ttime_dictionary_*`).
enum DictionaryLookup {
    static let site = take(ttime_dictionary_site())

    /// The site's search page for a Tibetan term (it takes Unicode in the URL).
    static func url(for term: String) -> URL? {
        let s = term.withCString { take(ttime_dictionary_url($0)) }
        return s.isEmpty ? nil : URL(string: s)
    }

    /// The term to look up: the selection if there is one (trimmed of spaces and
    /// trailing marks), else the syllable just before the caret.
    static func term(selection: String?, before: String?) -> String {
        withOptionalCString(selection) { sel in
            withOptionalCString(before) { bef in take(ttime_dictionary_term(sel, bef)) }
        }
    }

    private static func withOptionalCString(_ s: String?, _ body: (UnsafePointer<CChar>?) -> String) -> String {
        guard let s = s else { return body(nil) }
        return s.withCString { body($0) }
    }

    private static func take(_ p: UnsafeMutablePointer<CChar>?) -> String {
        guard let p = p else { return "" }
        defer { ttime_string_free(p) }
        return String(cString: p)
    }
}
