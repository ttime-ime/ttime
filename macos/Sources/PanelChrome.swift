import Cocoa

/// The panels that share the tab bar, in tab order.
enum PanelTab: Int, CaseIterable {
    case symbols, stacker, dictionary

    var title: String {
        switch self {
        case .symbols: return "Symbols"
        case .stacker: return "Stacker"
        case .dictionary: return "Dictionary"
        }
    }
}

/// What the symbols and stacker windows have in common: the tab bar, remembering
/// where they sit, and whether they are one column or two.
enum PanelTabs {
    private static let compactKey = "PanelsCompact"

    /// One column (image and answer on top, controls below) instead of two. Shared,
    /// so shrinking one window shrinks the other when you switch tabs.
    static var compact: Bool {
        get { UserDefaults.standard.bool(forKey: compactKey) }
        set { UserDefaults.standard.set(newValue, forKey: compactKey) }
    }

    // MARK: Tabs

    /// The pills at the top of a panel. Custom, not NSSegmentedControl: these
    /// panels never become key, and native controls draw their selection grey then.
    static func makeBar(selected: PanelTab, panel: @escaping () -> NSPanel?) -> NSStackView {
        let bar = TabBar()
        var buttons: [NSView] = []
        for tab in PanelTab.allCases {
            let b = BubbleButton(glyph: tab.title, glyphSize: 13,
                                 tip: tab == selected ? tab.title : "Show \(tab.title) (Tab)",
                                 label: "\(tab.title) tab") {
                guard tab != selected else { return }
                show(tab, from: panel())
            }
            b.filled = tab == selected
            if Theme.current.brutal { b.look = .heading }
            b.heightAnchor.constraint(equalToConstant: Theme.current.brutal ? 34 : 30).isActive = true
            b.widthAnchor.constraint(greaterThanOrEqualToConstant: Theme.current.brutal ? 20 : 82).isActive = true
            buttons.append(b)
        }
        for b in buttons { bar.addArrangedSubview(b) }
        bar.spacing = Theme.current.brutal ? 12 : 5
        return bar
    }

    /// Shows `tab` so that its tab bar sits exactly where the current panel's did:
    /// the panels differ in size and in where the bar is inside them, so matching the
    /// windows' corners would make the tabs jump under the pointer.
    static func show(_ tab: PanelTab, from panel: NSPanel?) {
        let topLeft = panel.map { NSPoint(x: $0.frame.minX, y: $0.frame.maxY) }
        let anchor = tabBarOrigin(in: panel)
        if tab != .symbols { SymbolsPanel.shared.close() }
        if tab != .stacker { StackerPanel.shared.close() }
        if tab != .dictionary { DictionaryPanel.shared.close() }
        let target: NSPanel?
        switch tab {
        case .symbols: SymbolsPanel.shared.open(topLeft: topLeft); target = SymbolsPanel.shared.window
        case .stacker: StackerPanel.shared.open(topLeft: topLeft); target = StackerPanel.shared.window
        case .dictionary: DictionaryPanel.shared.open(topLeft: topLeft); target = DictionaryPanel.shared.window
        }
        if let anchor = anchor, let target = target, let now = tabBarOrigin(in: target) {
            var f = target.frame
            f.origin.x += anchor.x - now.x
            f.origin.y += anchor.y - now.y
            target.setFrame(fit(f), display: true)
            target.invalidateShadow()
        }
    }

    /// The screen position of a panel's tab bar (its top-left corner), if it has one.
    static func tabBarOrigin(in panel: NSPanel?) -> NSPoint? {
        guard let panel = panel, let content = panel.contentView else { return nil }
        content.layoutSubtreeIfNeeded()
        func find(_ v: NSView) -> TabBar? {
            if let b = v as? TabBar { return b }
            for s in v.subviews { if let b = find(s) { return b } }
            return nil
        }
        guard let bar = find(content) else { return nil }
        let r = panel.convertToScreen(bar.convert(bar.bounds, to: nil))
        return NSPoint(x: r.minX, y: r.maxY)
    }

    /// The Tab key: the next panel.
    static func cycle(from tab: PanelTab, panel: NSPanel?) {
        let all = PanelTab.allCases
        show(all[(tab.rawValue + 1) % all.count], from: panel)
    }

    // MARK: Position

    /// The top-left is what is remembered: a window grows and shrinks downwards.
    static func topLeft(of panel: NSPanel) -> NSPoint { NSPoint(x: panel.frame.minX, y: panel.frame.maxY) }

    static func save(_ panel: NSPanel, key: String) {
        guard panel.isVisible else { return }
        UserDefaults.standard.set(NSStringFromPoint(topLeft(of: panel)), forKey: key)
    }

    /// Puts a hidden panel at `topLeft`, else where it was last, else in the middle.
    static func place(_ panel: NSPanel, key: String, topLeft: NSPoint?) {
        let size = panel.frame.size
        var tl: NSPoint
        if let t = topLeft {
            tl = t
        } else if let saved = UserDefaults.standard.string(forKey: key),
                  NSScreen.screens.contains(where: { $0.visibleFrame.contains(NSPointFromString(saved)) }) {
            tl = NSPointFromString(saved)
        } else {
            let area = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
            tl = NSPoint(x: area.midX - size.width / 2, y: area.midY + size.height / 2)
        }
        panel.setFrame(fit(NSRect(x: tl.x, y: tl.y - size.height, width: size.width, height: size.height)), display: false)
    }

    /// Resizes keeping the top-left corner (and the window on screen).
    static func setSize(_ panel: NSPanel, _ size: NSSize) {
        let tl = topLeft(of: panel)
        panel.setFrame(fit(NSRect(x: tl.x, y: tl.y - size.height, width: size.width, height: size.height)), display: panel.isVisible)
        panel.invalidateShadow()
    }

    /// Slides a frame back inside the visible part of the screen it mostly sits on.
    static func fit(_ r: NSRect) -> NSRect {
        let screen = NSScreen.screens.max { a, b in
            let ia = a.visibleFrame.intersection(r), ib = b.visibleFrame.intersection(r)
            return ia.width * ia.height < ib.width * ib.height
        } ?? NSScreen.main
        guard let v = screen?.visibleFrame else { return r }
        var f = r
        if f.maxX > v.maxX { f.origin.x = v.maxX - f.width }
        if f.minX < v.minX { f.origin.x = v.minX }
        if f.maxY > v.maxY { f.origin.y = v.maxY - f.height }
        if f.minY < v.minY { f.origin.y = v.minY }
        return f
    }
}

/// The row of tab pills; a class of its own so a panel's bar can be found.
final class TabBar: NSStackView {}

extension NSStackView {
    /// Replaces the arranged views. The ones that are dropped leave the window
    /// altogether, so a view can move between two stacks.
    func arrange(_ views: [NSView]) {
        for v in arrangedSubviews { removeArrangedSubview(v); v.removeFromSuperview() }
        for v in views { addArrangedSubview(v) }
    }
}

/// A grip in the bottom-right corner. The panels are borderless and never key, so
/// there is no native resize edge; this does it in screen coordinates, like
/// `DraggableView` does the moving. The panel decides what size it will accept
/// (`constrain`), which is how the stacker snaps between one and two columns.
final class ResizeGrip: NSView {
    /// Turns the size the mouse asks for into the size the window takes.
    var constrain: ((NSSize) -> NSSize)?
    private var start: (mouse: NSPoint, frame: NSRect)?

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 14, height: 14))
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 14).isActive = true
        heightAnchor.constraint(equalToConstant: 14).isActive = true
        toolTip = "Drag to resize"
        setAccessibilityLabel("Resize")
    }
    required init?(coder: NSCoder) { fatalError() }

    override var mouseDownCanMoveWindow: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func draw(_ dirtyRect: NSRect) {
        (Theme.current.brutal ? Theme.current.ink.withAlphaComponent(0.5) : StackerPanel.pinkStrong).setStroke()
        let path = NSBezierPath()
        path.lineWidth = 1.6
        path.lineCapStyle = .round
        for i in 0..<3 {
            let o = CGFloat(3 + i * 4)
            path.move(to: NSPoint(x: bounds.maxX - o, y: 2))
            path.line(to: NSPoint(x: bounds.maxX - 2, y: o))
        }
        path.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        guard let window = window else { return }
        start = (NSEvent.mouseLocation, window.frame)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window = window, let start = start else { return }
        let now = NSEvent.mouseLocation
        // Screen y points up: dragging down makes the window taller.
        let wanted = NSSize(width: start.frame.width + now.x - start.mouse.x,
                            height: start.frame.height - (now.y - start.mouse.y))
        let size = constrain?(wanted) ?? wanted
        guard size != window.frame.size else { return }
        window.setFrame(NSRect(x: start.frame.minX, y: start.frame.maxY - size.height,
                               width: size.width, height: size.height), display: true)
        window.invalidateShadow()
    }

    override func mouseUp(with event: NSEvent) { start = nil }
}
