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

    /// The window's background.
    let paper: NSColor
    /// Text, and the strongest lines.
    let ink: NSColor
    /// Outlines of buttons and cards.
    let line: NSColor
    /// The fill of a soft button.
    let tile: NSColor
    /// The fill of the answer card.
    let card: NSColor
    /// The toolbar's bar.
    let bar: NSColor
    let panelRadius: CGFloat
    let panelBorder: CGFloat
    let panelBorderColor: NSColor
    /// nil follows the system's light or dark mode.
    let appearance: NSAppearance?

    /// Whether the system is in dark mode (for artwork that cannot recolour itself).
    static var systemIsDark: Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    static var current: Theme { Prefs.style == .brutal ? brutalTheme : bubblegumTheme }

    private static func srgb(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
        NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: a)
    }

    /// A colour that is one thing in light mode and another in dark.
    private static func dynamic(light: NSColor, dark: NSColor) -> NSColor {
        NSColor(name: nil) { $0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light }
    }

    private static let bubblegumTheme = Theme(
        id: .bubblegum,
        paper: srgb(0xFCE7E9), ink: srgb(0xA8445F), line: srgb(0xEA8798),
        tile: srgb(0xFEE8D4, 0.85), card: NSColor.white.withAlphaComponent(0.7), bar: srgb(0xE4BBC5),
        panelRadius: 28, panelBorder: 3, panelBorderColor: srgb(0xEA8798),
        appearance: NSAppearance(named: .aqua))  // the brand is light

    private static let brutalTheme = Theme(
        id: .brutal,
        paper: dynamic(light: srgb(0xFFFFFF), dark: srgb(0x0E0E0E)),
        ink: dynamic(light: srgb(0x0E0E0E), dark: srgb(0xF4F4F4)),
        line: dynamic(light: NSColor.black.withAlphaComponent(0.55), dark: NSColor.white.withAlphaComponent(0.55)),
        tile: dynamic(light: NSColor.black.withAlphaComponent(0.06), dark: NSColor.white.withAlphaComponent(0.12)),
        card: dynamic(light: srgb(0xFFFFFF), dark: srgb(0x0E0E0E)),
        bar: dynamic(light: srgb(0xFFFFFF), dark: srgb(0x0E0E0E)),
        panelRadius: 22, panelBorder: 1,
        panelBorderColor: dynamic(light: NSColor.black.withAlphaComponent(0.18), dark: NSColor.white.withAlphaComponent(0.25)),
        appearance: nil)

    // MARK: Type

    /// Didot, which macOS ships; Georgia and then the system serif if it is missing.
    func serif(_ size: CGFloat, bold: Bool = false, italic: Bool = false) -> NSFont {
        let name = bold ? "Didot-Bold" : (italic ? "Didot-Italic" : "Didot")
        if let f = NSFont(name: name, size: size) { return f }
        if let f = NSFont(name: italic ? "Georgia-Italic" : (bold ? "Georgia-Bold" : "Georgia"), size: size) { return f }
        let base = NSFont.systemFont(ofSize: size)
        return base.fontDescriptor.withDesign(.serif).flatMap { NSFont(descriptor: $0, size: size) } ?? base
    }

    /// A row or section name. Brutalist: small capitals, widely tracked.
    func railLabel(_ s: String, width: CGFloat) -> NSTextField {
        let l: NSTextField
        if brutal {
            l = NSTextField(labelWithString: "")
            l.attributedStringValue = NSAttributedString(string: s.uppercased(), attributes: [
                .font: NSFont.systemFont(ofSize: 10, weight: .medium), .kern: 1.6,
                .foregroundColor: ink.withAlphaComponent(0.85)])
        } else {
            l = NSTextField(labelWithString: s)
            l.font = NSFont.systemFont(ofSize: 10, weight: .semibold)
            l.textColor = ink.withAlphaComponent(0.75)
        }
        l.translatesAutoresizingMaskIntoConstraints = false
        l.widthAnchor.constraint(equalToConstant: brutal ? width + 32 : width).isActive = true
        return l
    }

    /// A caption in the style's text face (serif when brutalist).
    func caption(_ s: String, size: CGFloat) -> NSTextField {
        let l = NSTextField(labelWithString: s)
        l.font = brutal ? serif(size + 3) : NSFont.systemFont(ofSize: size, weight: .semibold)
        l.textColor = brutal ? ink : ink.withAlphaComponent(0.75)
        return l
    }

    // MARK: Switching

    /// Rebuilds everything that has been drawn, after the style or the system
    /// appearance changed. Open windows reappear where they were.
    static func restyleAll() {
        MenuIcon.sync()
        Toolbar.shared.rebuild()
        StackerPanel.rebuild()
        SymbolsPanel.rebuild()
    }

    private static var observing = false

    /// Rebuilds when macOS switches between light and dark.
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

/// A one-point rule in the ink colour, faint.
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
    private func paint() { layer?.backgroundColor = resolved(Theme.current.ink.withAlphaComponent(0.22)) }
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
