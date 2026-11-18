import Cocoa

/// The font for Tibetan text in T-Time's own windows. macOS's built-in Tibetan
/// fonts (Kailasa, Kokonor) draw ordinary Tibetan stacks but not the Sanskrit
/// ones (retroflex letters under other letters show as dotted circles), so the
/// app bundles Noto Serif Tibetan (SIL OFL 1.1, text beside it in Resources),
/// the same font as the web playground. This affects only T-Time's windows; text
/// inserted into a document is drawn in that document's font.
enum TibetanFont {
    private static let postScriptName = "NotoSerifTibetan-Regular"

    /// Registers the bundled font for this process, once.
    private static let available: Bool = {
        guard let url = Bundle.main.url(forResource: "NotoSerifTibetan", withExtension: "ttf") else { return false }
        return CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }()

    static func font(_ size: CGFloat) -> NSFont {
        if available, let f = NSFont(name: postScriptName, size: size) { return f }
        return NSFont.systemFont(ofSize: size)
    }

    static func contains(_ s: String) -> Bool {
        s.unicodeScalars.contains { (0x0F00...0x0FFF).contains($0.value) }
    }
}
