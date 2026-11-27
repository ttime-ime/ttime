import Cocoa

/// The visual styles. A style is a palette, a typeface and a few shapes; the
/// layouts are shared. Pink is the original; brutalist is black and white, set in
/// Didot with tracked capitals and hairlines, and follows light and dark mode.
enum StyleID: String, CaseIterable {
    case bubblegum, brutal

    var title: String { self == .bubblegum ? "Bubblegum (pink)" : "Brutalist (black and white)" }
}

extension Prefs {
    /// The style chosen in the installer, which leaves its name in this file.
    static var installedDefault: StyleID {
        let text = try? String(contentsOfFile: "/Library/Application Support/T-Time/default-style", encoding: .utf8)
        return StyleID(rawValue: text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "") ?? .bubblegum
    }

    /// The style of the toolbar, the Symbols window and the Stacker.
    static var style: StyleID {
        get { StyleID(rawValue: UserDefaults.standard.string(forKey: "Style") ?? "") ?? installedDefault }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "Style") }
    }
}

struct Theme {
    let id: StyleID
    var brutal: Bool { id == .brutal }

    // MARK: Colour

    /// The window's background.
    let paper: NSColor
    /// Primary text and strongest fills (selection).
    let ink: NSColor
    /// Secondary body text (taglines, status).
    let secondaryText: NSColor
    /// Muted / instruction text.
    let mutedText: NSColor
    /// Interactive control outlines (buttons).
    let controlBorder: NSColor
    /// Decorative hairlines and rules (not interactive).
    let separator: NSColor
    /// Legacy alias used by older call sites; maps to controlBorder.
    var line: NSColor { controlBorder }
    /// Quiet fill for vowel/mark tiles.
    let tile: NSColor
    /// The fill of the answer card (Bubblegum).
    let card: NSColor
    /// The toolbar's bar.
    let bar: NSColor
    let panelBorderColor: NSColor

    // MARK: Geometry

    let panelRadius: CGFloat
    let panelBorder: CGFloat
    let cellRadius: CGFloat
    let tileRadius: CGFloat
    let actionRadius: CGFloat
    let presetRadius: CGFloat
    let artRadius: CGFloat
    let toolbarRadius: CGFloat

    let stackerCell: CGSize
    let symbolsCell: CGSize
    let stackerGlyphSize: CGFloat
    let symbolsGlyphSize: CGFloat
    let glyphCaptionSize: CGFloat
    let stackerGapX: CGFloat
    let stackerGapY: CGFloat
    let symbolsGapX: CGFloat
    let symbolsGapY: CGFloat
    let rootSpacing: CGFloat
    let sectionSpacing: CGFloat
    let presetHeight: CGFloat
    let railTracking: CGFloat
    let railSize: CGFloat
    /// Stacker illustration column height (Brutalist 50:50 composition).
    let stackerArtHeight: CGFloat
    /// Stacker illustration / compose column width (Brutalist).
    let composeColumnWidth: CGFloat
    /// Gutter between the two Stacker composition columns.
    let composeGutter: CGFloat
    /// Category rail width inside the alphabet (Brutalist).
    let railWidth: CGFloat
    /// Symbols banner height; width is the content width.
    let symbolsBannerHeight: CGFloat
    /// Nominal Tibetan preview point size (scaled down to fit).
    let previewNominalSize: CGFloat
    /// Action button height (Insert / Copy / Clear).
    let actionButtonHeight: CGFloat
    /// Background wash for prefix-mismatched (still available) cells.
    let dimmedFill: NSColor
    /// Background wash for functionally unavailable cells.
    let unavailableFill: NSColor
    /// Subtle hover / focus wash (Brutalist interaction states).
    let hoverFill: NSColor
    /// Roman glyph captions (Didot); stronger than muted so punctuation stays legible.
    let glyphCaption: NSColor

    /// nil follows the system's light or dark mode.
    let appearance: NSAppearance?

    /// Whether the system is in dark mode (for artwork that cannot recolour itself).
    static var systemIsDark: Bool {
        guard let app = NSApp else { return systemSettingIsDark }
        return app.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    static var systemSettingIsDark: Bool {
        CFPreferencesSynchronize(kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        let v = CFPreferencesCopyValue("AppleInterfaceStyle" as CFString, kCFPreferencesAnyApplication,
                                       kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? String
        return v == "Dark"
    }

    static var current: Theme { Prefs.style == .brutal ? brutalTheme : bubblegumTheme }

    private static func srgb(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
        NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: a)
    }

    private static func dynamic(light: NSColor, dark: NSColor) -> NSColor {
        NSColor(name: nil) { $0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light }
    }

    private static let bubblegumTheme = Theme(
        id: .bubblegum,
        paper: srgb(0xFCE7E9), ink: srgb(0xA8445F),
        secondaryText: srgb(0xA8445F).withAlphaComponent(0.75),
        mutedText: srgb(0xA8445F).withAlphaComponent(0.7),
        controlBorder: srgb(0xEA8798),
        separator: srgb(0xEA8798).withAlphaComponent(0.45),
        tile: srgb(0xFEE8D4, 0.85), card: NSColor.white.withAlphaComponent(0.7), bar: srgb(0xE4BBC5),
        panelBorderColor: srgb(0xEA8798),
        panelRadius: 28, panelBorder: 3,
        cellRadius: 12, tileRadius: 12, actionRadius: 12, presetRadius: 12, artRadius: 20, toolbarRadius: 15 * 0.7,
        stackerCell: NSSize(width: 38, height: 38),
        symbolsCell: NSSize(width: 56, height: 46),
        stackerGlyphSize: 15, symbolsGlyphSize: 18, glyphCaptionSize: 9,
        stackerGapX: 4, stackerGapY: 5, symbolsGapX: 4, symbolsGapY: 4,
        rootSpacing: 9, sectionSpacing: 9, presetHeight: 26, railTracking: 0, railSize: 10,
        stackerArtHeight: 0, composeColumnWidth: 0, composeGutter: 0, railWidth: 82,
        symbolsBannerHeight: 0, previewNominalSize: 46, actionButtonHeight: 32,
        dimmedFill: NSColor.clear, unavailableFill: NSColor.clear, hoverFill: NSColor.clear,
        glyphCaption: srgb(0xA8445F).withAlphaComponent(0.75),
        appearance: NSAppearance(named: .aqua))

    private static let brutalTheme = Theme(
        id: .brutal,
        paper: dynamic(light: srgb(0xFFFFFF), dark: srgb(0x0E0E0E)),
        ink: dynamic(light: srgb(0x0E0E0E), dark: srgb(0xF2F2F2)),
        secondaryText: dynamic(light: srgb(0x595959), dark: srgb(0xA3A3A3)),
        mutedText: dynamic(light: srgb(0x767676), dark: srgb(0x8A8A8A)),
        controlBorder: dynamic(light: srgb(0xCCCCCC), dark: srgb(0x3D3D3D)),
        separator: dynamic(light: srgb(0xE0E0E0), dark: srgb(0x2A2A2A)),
        // Quieter vowel/mark wash so the bottom of the alphabet is not heavier than consonants.
        tile: dynamic(light: srgb(0xF7F7F7), dark: srgb(0x161616)),
        card: dynamic(light: srgb(0xFFFFFF), dark: srgb(0x0E0E0E)),
        bar: dynamic(light: srgb(0xFFFFFF), dark: srgb(0x0E0E0E)),
        // Slightly softer than controlBorder so the floating panel edge is present but not heavy.
        panelBorderColor: dynamic(light: srgb(0xD8D8D8), dark: srgb(0x333333)),
        panelRadius: 18, panelBorder: 1,
        cellRadius: 5, tileRadius: 5, actionRadius: 5, presetRadius: 4, artRadius: 0, toolbarRadius: 12,
        // Measured min height with the full stacker inventory + Sanskrit stress set is 48 pt
        // at glyph 15 / Didot 10; 50 pt keeps ~2 pt slack above the tallest ink.
        stackerCell: NSSize(width: 40, height: 50),
        symbolsCell: NSSize(width: 56, height: 52),
        stackerGlyphSize: 15, symbolsGlyphSize: 18, glyphCaptionSize: 10,
        // Gap 2 keeps the nine-column Marks row inside 476 with a 92 pt rail.
        stackerGapX: 2, stackerGapY: 2, symbolsGapX: 14, symbolsGapY: 2,
        rootSpacing: 6, sectionSpacing: 4, presetHeight: 24, railTracking: 1.1, railSize: 9,
        // 50:50 composition columns; symbols banner target 476×120 (aspect-fill).
        stackerArtHeight: 174, composeColumnWidth: 232, composeGutter: 12, railWidth: 92,
        symbolsBannerHeight: 120, previewNominalSize: 56, actionButtonHeight: 26,
        dimmedFill: dynamic(light: srgb(0xF0F0F0), dark: srgb(0x1A1A1A)),
        // Very quiet wash — unavailable must not outrank ordinary consonants.
        unavailableFill: dynamic(light: srgb(0xF2F2F2), dark: srgb(0x141414)),
        hoverFill: dynamic(light: srgb(0xF4F4F4), dark: srgb(0x1A1A1A)),
        glyphCaption: dynamic(light: srgb(0x666666), dark: srgb(0xA3A3A3)),
        appearance: nil)

    /// Shared disabled treatment for primary and secondary actions.
    var disabledActionFill: NSColor { brutal ? hoverFill : tile }
    var disabledActionInk: NSColor { brutal ? mutedText : ink.withAlphaComponent(0.45) }
    /// Legacy aliases.
    var disabledPrimaryFill: NSColor { disabledActionFill }
    var disabledPrimaryInk: NSColor { disabledActionInk }

    // MARK: Type

    /// Didot, which macOS ships; Georgia and then the system serif if it is missing.
    func serif(_ size: CGFloat, bold: Bool = false, italic: Bool = false) -> NSFont {
        let name = bold ? "Didot-Bold" : (italic ? "Didot-Italic" : "Didot")
        if let f = NSFont(name: name, size: size) { return f }
        if let f = NSFont(name: italic ? "Georgia-Italic" : (bold ? "Georgia-Bold" : "Georgia"), size: size) { return f }
        let base = NSFont.systemFont(ofSize: size)
        return base.fontDescriptor.withDesign(.serif).flatMap { NSFont(descriptor: $0, size: size) } ?? base
    }

    /// A row or section name. Brutalist: small capitals, tracked.
    func railLabel(_ s: String, width: CGFloat) -> NSTextField {
        let l: NSTextField
        if brutal {
            l = NSTextField(labelWithString: "")
            l.attributedStringValue = NSAttributedString(string: s.uppercased(), attributes: [
                .font: NSFont.systemFont(ofSize: railSize, weight: .medium), .kern: railTracking,
                .foregroundColor: secondaryText])
        } else {
            l = NSTextField(labelWithString: s)
            l.font = NSFont.systemFont(ofSize: 10, weight: .semibold)
            l.textColor = ink.withAlphaComponent(0.75)
        }
        l.translatesAutoresizingMaskIntoConstraints = false
        l.widthAnchor.constraint(equalToConstant: brutal ? railWidth : width).isActive = true
        l.lineBreakMode = .byTruncatingTail
        return l
    }

    /// Baskerville for long dictionary definitions; Georgia, then the system serif.
    func textSerif(_ size: CGFloat) -> NSFont {
        if let f = NSFont(name: "Baskerville", size: size) { return f }
        if let f = NSFont(name: "Georgia", size: size) { return f }
        let base = NSFont.systemFont(ofSize: size)
        return base.fontDescriptor.withDesign(.serif).flatMap { NSFont(descriptor: $0, size: size) } ?? base
    }

    /// A caption in the style's text face (serif when brutalist).
    func caption(_ s: String, size: CGFloat) -> NSTextField {
        let l = NSTextField(labelWithString: s)
        l.font = brutal ? serif(size + 3) : NSFont.systemFont(ofSize: size, weight: .semibold)
        l.textColor = brutal ? ink : ink.withAlphaComponent(0.75)
        return l
    }

    // MARK: Switching

    static func restyleAll() {
        GlyphCaptionLayout.clearCaches()
        MenuIcon.sync()
        Toolbar.shared.rebuild()
        StackerPanel.rebuild()
        SymbolsPanel.rebuild()
        DictionaryPanel.rebuild()
    }

    private static var observing = false

    static func observeSystemAppearance() {
        guard !observing else { return }
        observing = true
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("AppleInterfaceThemeChangedNotification"), object: nil, queue: .main) { _ in
            if Prefs.style == .brutal { restyleAll() }
        }
    }
}

extension NSView {
    /// `color` as a CGColor in this view's own appearance, for layers (a dynamic
    /// NSColor needs an appearance to resolve against).
    func resolved(_ color: NSColor) -> CGColor {
        var out = color.cgColor
        effectiveAppearance.performAsCurrentDrawingAppearance { out = color.cgColor }
        return out
    }
}

/// A one-point decorative rule.
final class RuleView: NSView {
    init(vertical: Bool) {
        super.init(frame: .zero)
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
        if vertical { widthAnchor.constraint(equalToConstant: 1).isActive = true }
        else { heightAnchor.constraint(equalToConstant: 1).isActive = true }
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidChangeEffectiveAppearance() { paint() }
    override func viewDidMoveToWindow() { paint() }
    private func paint() { layer?.backgroundColor = resolved(Theme.current.separator) }
}

/// The input-source icon in the menu bar. macOS reads it from Resources/icon.tiff,
/// which is a link to `path`; this puts the style's picture there. macOS caches the
/// icon, so a change also clears the cache and restarts the menu agents.
enum MenuIcon {
    static let path = "/Users/Shared/T-Time/icon.tiff"

    static func sync() {
        let name = Prefs.style == .brutal ? "icon-mono" : "icon-colour"
        guard let src = Bundle.main.url(forResource: name, withExtension: "tiff"),
              let data = try? Data(contentsOf: src) else { return }
        let dest = URL(fileURLWithPath: path)
        if let current = try? Data(contentsOf: dest), current == data { return }
        let fm = FileManager.default
        try? fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true,
                                attributes: [.posixPermissions: 0o777])
        guard (try? data.write(to: dest)) != nil else { return }
        try? fm.setAttributes([.posixPermissions: 0o666], ofItemAtPath: path)
        let cache = fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Caches/com.apple.tiswitcher.cache")
        try? fm.removeItem(at: cache)
        for agent in ["TextInputMenuAgent", "TextInputSwitcher"] {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            p.arguments = [agent]
            try? p.run()
        }
    }
}
