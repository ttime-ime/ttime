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
    var bubblegum: Bool { id == .bubblegum }
    /// 50:50 Stacker composition + alphabet scroll (both refined themes).
    var usesComposeLayout: Bool { composeColumnWidth > 0 }
    /// Core Text shared-baseline glyph+caption cells.
    var usesSharedBaselineCells: Bool { true }

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
    /// Quiet fill for vowel/mark tiles / cream character tiles.
    let tile: NSColor
    /// The fill of the answer card / reading surface.
    let card: NSColor
    /// Preview and dictionary reading surface (cream / dark chocolate).
    let surface: NSColor
    /// Decorative strawberry-icing accent.
    let accent: NSColor
    /// Selected control fill (raspberry jam).
    let selection: NSColor
    /// Glyph ink on a selected control.
    let selectedInk: NSColor
    /// Caption ink on a selected control.
    let selectedCaption: NSColor
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

    /// Confectionery Bubblegum: strawberry milk, vanilla cream, raspberry jam; follows system light/dark.
    private static let bubblegumTheme = Theme(
        id: .bubblegum,
        paper: dynamic(light: srgb(0xFBE8EC), dark: srgb(0x302029)),
        ink: dynamic(light: srgb(0x773047), dark: srgb(0xF8DCE4)),
        secondaryText: dynamic(light: srgb(0xA65A72), dark: srgb(0xD5A5B6)),
        mutedText: dynamic(light: srgb(0xC07A90), dark: srgb(0xB88A9A)),
        controlBorder: dynamic(light: srgb(0xEDB2BE), dark: srgb(0x79505F)),
        separator: dynamic(light: srgb(0xEFCBD4), dark: srgb(0x593B48)),
        tile: dynamic(light: srgb(0xFFF0E2), dark: srgb(0x49303B)),
        card: dynamic(light: srgb(0xFFF8F6), dark: srgb(0x392630)),
        surface: dynamic(light: srgb(0xFFF8F6), dark: srgb(0x392630)),
        accent: dynamic(light: srgb(0xE98CA4), dark: srgb(0xDF8CA6)),
        selection: dynamic(light: srgb(0xA33D60), dark: srgb(0xAD4267)),
        selectedInk: dynamic(light: srgb(0xFFFFFF), dark: srgb(0xFFFFFF)),
        selectedCaption: dynamic(light: srgb(0xFFF0E2), dark: srgb(0xF8DCE4)),
        bar: dynamic(light: srgb(0xE4BBC5), dark: srgb(0x49303B)),
        panelBorderColor: dynamic(light: srgb(0xE98CA4), dark: srgb(0x79505F)),
        panelRadius: 24, panelBorder: 1.5,
        // ~23% tighter radius than Phase 3.0 (11→8.5): soft biscuit, not telephone key.
        cellRadius: 8.5, tileRadius: 8.5, actionRadius: 8, presetRadius: 9, artRadius: 14, toolbarRadius: 15 * 0.7,
        // Shared-baseline cells: taller than the old 38×38 fixed-offset tiles.
        stackerCell: NSSize(width: 42, height: 52),
        symbolsCell: NSSize(width: 58, height: 54),
        stackerGlyphSize: 15, symbolsGlyphSize: 18, glyphCaptionSize: 10,
        // Symbols: (506 − 7×58) / 6 ≈ 16.67 so the grid spans the content rectangle.
        stackerGapX: 4, stackerGapY: 3, symbolsGapX: 16.67, symbolsGapY: 4,
        rootSpacing: 6, sectionSpacing: 4, presetHeight: 24, railTracking: 0, railSize: 11,
        // 50:50: (506 − 12) / 2 = 247; composition height trimmed ~30 pt from Phase 3.0.
        stackerArtHeight: 224, composeColumnWidth: 247, composeGutter: 12, railWidth: 88,
        // 0 = use artwork's natural aspect (do not crop to Brutalist's 120 pt banner).
        symbolsBannerHeight: 0, previewNominalSize: 50, actionButtonHeight: 26,
        dimmedFill: dynamic(light: srgb(0xF5D6DE), dark: srgb(0x3A2830)),
        unavailableFill: dynamic(light: srgb(0xF3DDE3), dark: srgb(0x35252D)),
        hoverFill: dynamic(light: srgb(0xFFE8EE), dark: srgb(0x423038)),
        glyphCaption: dynamic(light: srgb(0xA65A72), dark: srgb(0xD5A5B6)),
        appearance: nil)

    private static let brutalTheme = Theme(
        id: .brutal,
        paper: dynamic(light: srgb(0xFFFFFF), dark: srgb(0x0E0E0E)),
        ink: dynamic(light: srgb(0x0E0E0E), dark: srgb(0xF2F2F2)),
        secondaryText: dynamic(light: srgb(0x595959), dark: srgb(0xA3A3A3)),
        mutedText: dynamic(light: srgb(0x767676), dark: srgb(0x8A8A8A)),
        controlBorder: dynamic(light: srgb(0xCCCCCC), dark: srgb(0x3D3D3D)),
        separator: dynamic(light: srgb(0xE0E0E0), dark: srgb(0x2A2A2A)),
        tile: dynamic(light: srgb(0xF7F7F7), dark: srgb(0x161616)),
        card: dynamic(light: srgb(0xFFFFFF), dark: srgb(0x0E0E0E)),
        surface: dynamic(light: srgb(0xFFFFFF), dark: srgb(0x0E0E0E)),
        accent: dynamic(light: srgb(0x0E0E0E), dark: srgb(0xF2F2F2)),
        selection: dynamic(light: srgb(0x0E0E0E), dark: srgb(0xF2F2F2)),
        selectedInk: dynamic(light: srgb(0xFFFFFF), dark: srgb(0x0E0E0E)),
        selectedCaption: dynamic(light: srgb(0xFFFFFF), dark: srgb(0x0E0E0E)),
        bar: dynamic(light: srgb(0xFFFFFF), dark: srgb(0x0E0E0E)),
        panelBorderColor: dynamic(light: srgb(0xD8D8D8), dark: srgb(0x333333)),
        panelRadius: 18, panelBorder: 1,
        cellRadius: 5, tileRadius: 5, actionRadius: 5, presetRadius: 4, artRadius: 0, toolbarRadius: 12,
        stackerCell: NSSize(width: 40, height: 50),
        symbolsCell: NSSize(width: 56, height: 52),
        stackerGlyphSize: 15, symbolsGlyphSize: 18, glyphCaptionSize: 10,
        stackerGapX: 2, stackerGapY: 2, symbolsGapX: 14, symbolsGapY: 2,
        rootSpacing: 6, sectionSpacing: 4, presetHeight: 24, railTracking: 1.1, railSize: 9,
        stackerArtHeight: 174, composeColumnWidth: 232, composeGutter: 12, railWidth: 92,
        symbolsBannerHeight: 120, previewNominalSize: 56, actionButtonHeight: 26,
        dimmedFill: dynamic(light: srgb(0xF0F0F0), dark: srgb(0x1A1A1A)),
        unavailableFill: dynamic(light: srgb(0xF2F2F2), dark: srgb(0x141414)),
        hoverFill: dynamic(light: srgb(0xF4F4F4), dark: srgb(0x1A1A1A)),
        glyphCaption: dynamic(light: srgb(0x666666), dark: srgb(0xA3A3A3)),
        appearance: nil)

    /// Shared disabled treatment for primary and secondary actions.
    var disabledActionFill: NSColor { brutal ? hoverFill : unavailableFill }
    var disabledActionInk: NSColor { mutedText }
    /// Legacy aliases.
    var disabledPrimaryFill: NSColor { disabledActionFill }
    var disabledPrimaryInk: NSColor { disabledActionInk }

    // MARK: Bubblegum polish experiments (harness / review)

    /// Subtle 1–2 pt darker lower edge on cream tiles (biscuit thickness). Off by default.
    static var bubblegumBiscuitEdge = false
    /// Tiny decorative paw in the header trailing space. Off by default.
    static var bubblegumPawMotif = false

    // MARK: Type

    /// Didot, which macOS ships; Georgia and then the system serif if it is missing.
    func serif(_ size: CGFloat, bold: Bool = false, italic: Bool = false) -> NSFont {
        let name = bold ? "Didot-Bold" : (italic ? "Didot-Italic" : "Didot")
        if let f = NSFont(name: name, size: size) { return f }
        if let f = NSFont(name: italic ? "Georgia-Italic" : (bold ? "Georgia-Bold" : "Georgia"), size: size) { return f }
        let base = NSFont.systemFont(ofSize: size)
        return base.fontDescriptor.withDesign(.serif).flatMap { NSFont(descriptor: $0, size: size) } ?? base
    }

    /// A row or section name. Brutalist: small capitals, tracked. Bubblegum: title-case Nunito.
    func railLabel(_ s: String, width: CGFloat) -> NSTextField {
        let l: NSTextField
        if brutal {
            l = NSTextField(labelWithString: "")
            l.attributedStringValue = NSAttributedString(string: s.uppercased(), attributes: [
                .font: NSFont.systemFont(ofSize: railSize, weight: .medium), .kern: railTracking,
                .foregroundColor: secondaryText])
        } else {
            l = NSTextField(labelWithString: s)
            l.font = BubblegumFonts.ui(railSize, weight: .bold)
            l.textColor = secondaryText
        }
        l.translatesAutoresizingMaskIntoConstraints = false
        l.widthAnchor.constraint(equalToConstant: usesComposeLayout ? railWidth : width).isActive = true
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

    /// A caption in the style's text face (serif when brutalist; Nunito when Bubblegum).
    func caption(_ s: String, size: CGFloat) -> NSTextField {
        let l = NSTextField(labelWithString: s)
        if brutal {
            l.font = serif(size + 3)
            l.textColor = ink
        } else {
            l.font = BubblegumFonts.ui(size, weight: .semibold)
            l.textColor = secondaryText
        }
        return l
    }

    // MARK: Switching

    static func restyleAll() {
        GlyphCaptionLayout.clearCaches()
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
            // Both refined themes follow system light/dark.
            restyleAll()
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
