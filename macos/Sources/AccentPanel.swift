import Cocoa

/// A view that takes a click anywhere inside it, even from a panel that is not active,
/// and reports which one (`index`) was clicked. Labels drawn under it cannot intercept.
final class ClickableView: NSView {
    var index = 0
    var onClick: ((Int) -> Void)?
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { frame.contains(point) ? self : nil }
    override func mouseDown(with event: NSEvent) { onClick?(index) }
}

/// The strip of accent variants shown above a held letter, each with its number key.
/// A non-activating panel, so it never takes focus from the application; a click on a
/// variant reports its index through `onPick`.
final class AccentPanel {
    static let shared = AccentPanel()
    var onPick: ((Int) -> Void)?
    private var panel: NSPanel?
    private let content = NSView()

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

    /// Shows `options` side by side with the one at `selected` highlighted, above `rect`
    /// (the text line in screen coordinates).
    func show(_ options: [String], selected: Int?, near rect: NSRect) {
        let p = ensurePanel()
        content.subviews.forEach { $0.removeFromSuperview() }
        let cellW: CGFloat = 40, cellH: CGFloat = 52, pad: CGFloat = 4
        let width = cellW * CGFloat(options.count) + pad * 2
        let height = cellH + pad * 2
        for (i, o) in options.enumerated() {
            let on = i == selected
            let cell = ClickableView(frame: NSRect(x: pad + cellW * CGFloat(i), y: pad, width: cellW, height: cellH))
            cell.index = i
            cell.onClick = { [weak self] in self?.onPick?($0) }
            cell.wantsLayer = true
            cell.layer?.cornerRadius = 5
            cell.layer?.backgroundColor = on ? NSColor.controlAccentColor.cgColor : nil
            let letter = NSTextField(labelWithString: o)
            letter.font = .systemFont(ofSize: 24)
            letter.alignment = .center
            letter.textColor = on ? .white : .black
            letter.frame = NSRect(x: 0, y: 20, width: cellW, height: 30)
            let number = NSTextField(labelWithString: String(i + 1))
            number.font = .systemFont(ofSize: 11)
            number.alignment = .center
            number.textColor = on ? .white : .secondaryLabelColor
            number.frame = NSRect(x: 0, y: 3, width: cellW, height: 14)
            cell.addSubview(letter); cell.addSubview(number)
            content.addSubview(cell)
            // The click catcher sits over the letter and number, so they cannot swallow it.
            let hit = ClickableView(frame: cell.frame)
            hit.index = i
            hit.onClick = { [weak self] in self?.onPick?($0) }
            content.addSubview(hit)
        }
        var origin = NSPoint(x: rect.minX, y: rect.maxY + 4)
        if rect == .zero { origin = NSEvent.mouseLocation }
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(origin) }) ?? NSScreen.main {
            origin.x = min(max(origin.x, screen.visibleFrame.minX), screen.visibleFrame.maxX - width)
            if origin.y + height > screen.visibleFrame.maxY { origin.y = rect.minY - height - 4 }
        }
        p.setFrame(NSRect(origin: origin, size: NSSize(width: width, height: height)), display: true)
        p.orderFrontRegardless()
    }

    func hide() { panel?.orderOut(nil) }
}
