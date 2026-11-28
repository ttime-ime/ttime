import AppKit
import CoreText

/// Registers the bundled Nunito family (SIL OFL) for Bubblegum UI typography.
enum BubblegumFonts {
    private static var didRegister = false

    /// Register once per process. Safe to call repeatedly.
    static func registerIfNeeded() {
        guard !didRegister else { return }
        didRegister = true
        let names = ["Nunito-Regular", "Nunito-Medium", "Nunito-SemiBold", "Nunito-Bold", "Nunito-ExtraBold"]
        for name in names {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf", subdirectory: "Fonts")
                    ?? Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            var err: Unmanaged<CFError>?
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, &err)
        }
    }

    /// Nunito weight → PostScript name.
    private static func postScript(weight: NSFont.Weight) -> String {
        switch weight {
        case ...(.regular): return "Nunito-Regular"
        case ...(.medium): return "Nunito-Medium"
        case ...(.semibold): return "Nunito-SemiBold"
        case ...(.bold): return "Nunito-Bold"
        default: return "Nunito-ExtraBold"
        }
    }

    /// Preferred Bubblegum UI face; falls back to rounded system, then system.
    static func ui(_ size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        registerIfNeeded()
        if let f = NSFont(name: postScript(weight: weight), size: size) { return f }
        let base = NSFont.systemFont(ofSize: size, weight: weight)
        if let rounded = base.fontDescriptor.withDesign(.rounded).flatMap({ NSFont(descriptor: $0, size: size) }) {
            return rounded
        }
        return base
    }
}
