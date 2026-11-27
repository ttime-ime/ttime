import Foundation

/// Thin wrap of the C conversion API. All EWTS rules live in `ttime-core`.
enum Engine {
    private static func take(_ p: UnsafeMutablePointer<CChar>?) -> String {
        guard let p else { return "" }
        defer { ttime_string_free(p) }
        return String(cString: p)
    }

    /// EWTS → Tibetan Unicode.
    static func toTibetan(_ text: String, precomposed: Bool = Prefs.precomposed) -> String {
        text.withCString { take(ttime_convert($0, precomposed)) }
    }

    /// Tibetan Unicode → EWTS.
    static func toWylie(_ text: String) -> String {
        text.withCString { take(ttime_unicode_to_ewts($0)) }
    }

    static var version: String { take(ttime_version()) }
}
