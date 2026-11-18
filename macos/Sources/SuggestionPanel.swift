import Cocoa

/// The small list of Sanskrit suggestions under the word being typed. A
/// non-activating panel, so it never takes focus from the application.
final class SuggestionPanel {
    static let shared = SuggestionPanel()
    private var panel: NSPanel?
    private let content = NSView()
    private var rows: [NSView] = []

    private func ensurePanel() -> NSPanel {
        if let p = panel { return p }
        let p = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: true)
        p.level = .popUpMenu
        p.isFloatingPanel = true
        p.hidesOnDeactivate = false
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.appearance = NSAppearance(named: .aqua)
        content.wantsLayer = true
        content.layer?.cornerRadius = 8
        content.layer?.backgroundColor = NSColor(white: 0.98, alpha: 1).cgColor
        content.layer?.borderWidth = 0.5
        content.layer?.borderColor = NSColor(white: 0, alpha: 0.2).cgColor
        p.contentView = content
        panel = p
        return p
    }

    /// Shows `words` with the one at `selected` highlighted, below `rect` (the text
    /// line in screen coordinates).
    func show(_ words: [String], selected: Int, near rect: NSRect) {
        let p = ensurePanel()
        rows.forEach { $0.removeFromSuperview() }
        rows = []
        let rowHeight: CGFloat = 24
        let font = NSFont.systemFont(ofSize: 14)
        let width = max(150, (words.map { ($0 as NSString).size(withAttributes: [.font: font]).width }.max() ?? 0) + 48)
        let height = rowHeight * CGFloat(words.count) + 8
        for (i, w) in words.enumerated() {
            let y = height - 4 - rowHeight * CGFloat(i + 1)
            let label = NSTextField(labelWithString: w)
            label.font = font
            label.frame = NSRect(x: 26, y: y + 3, width: width - 34, height: 18)
            let on = i == selected
            let bg = NSView(frame: NSRect(x: 4, y: y, width: width - 8, height: rowHeight))
            bg.wantsLayer = true
            bg.layer?.cornerRadius = 5
            bg.layer?.backgroundColor = on ? NSColor.controlAccentColor.cgColor : nil
            label.textColor = on ? .white : .black
            let hint = NSTextField(labelWithString: on ? "⇥" : "")
            hint.font = .systemFont(ofSize: 11)
            hint.textColor = .white
            hint.frame = NSRect(x: 8, y: y + 4, width: 16, height: 16)
            content.addSubview(bg); content.addSubview(label); content.addSubview(hint)
            rows += [bg, label, hint]
        }
        var origin = NSPoint(x: rect.minX, y: rect.minY - height - 4)
        if rect == .zero { origin = NSEvent.mouseLocation }
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(origin) }) ?? NSScreen.main {
            origin.x = min(max(origin.x, screen.visibleFrame.minX), screen.visibleFrame.maxX - width)
            if origin.y < screen.visibleFrame.minY { origin.y = rect.maxY + 4 }
        }
        p.setFrame(NSRect(origin: origin, size: NSSize(width: width, height: height)), display: true)
        p.orderFrontRegardless()
    }

    func hide() { panel?.orderOut(nil) }
}
