import Foundation

/// How a client application accepts text from an input method.
enum ClientText {
    /// Spotlight's search field shows a character only when the key itself
    /// arrives. Text an input method inserts, and the underlined provisional
    /// syllable (marked text), never appear. Claiming the key then leaves the
    /// field empty, in Tibetan mode and in Latin mode alike.
    static func showsOnlyRawKeys(_ bundleIdentifier: String?) -> Bool {
        bundleIdentifier == "com.apple.Spotlight"
    }
}
