import Cocoa

/// Same bundled Noto Serif Tibetan as the IME (SIL OFL 1.1).
enum TibetanFont {
    private static let postScriptName = "NotoSerifTibetan-Regular"

    private static let available: Bool = {
        guard let url = Bundle.main.url(forResource: "NotoSerifTibetan", withExtension: "ttf") else { return false }
        return CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }()

    static func font(_ size: CGFloat) -> NSFont {
        if available, let f = NSFont(name: postScriptName, size: size) { return f }
        return NSFont.systemFont(ofSize: size)
    }
}
