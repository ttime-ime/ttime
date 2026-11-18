import Cocoa

/// T-Time's floating toolbar: the brand, the Tibetan/Latin mode (with lock),
/// and buttons for the symbols table and the stacker. A non-activating panel,
/// so clicking it never takes focus from the document being edited.
///
/// It looks the same in light and dark mode on purpose: the cream and plum are
/// the brand. One panel serves every client application; the active controller
/// sets the actions below and tells it the current state.
final class Toolbar: NSObject {
    static let shared = Toolbar()

    struct State: Equatable {
        var latin: Bool
        var locked: Bool
    }

    // Brand colours, taken from the logo.
    static let cream = NSColor(srgbRed: 254 / 255, green: 247 / 255, blue: 240 / 255, alpha: 1)
    static let plum = NSColor(srgbRed: 160 / 255, green: 68 / 255, blue: 100 / 255, alpha: 1)
    static let pink = NSColor(srgbRed: 229 / 255, green: 117 / 255, blue: 142 / 255, alpha: 1)

    /// Actions, set by the active controller. A nil action disables its control.
    var chooseMode: ((_ latin: Bool) -> Void)?
    var toggleLock: (() -> Void)?
    var openSymbols: (() -> Void)? { didSet { render() } }
    var openStacker: (() -> Void)? { didSet { render() } }

    private static let hiddenKey = "ToolbarHidden"
    private static let originKey = "ToolbarOrigin"
    private static let margin: CGFloat = 16

    /// The user can turn the toolbar off from the input menu.
    static var isHidden: Bool {
        get { UserDefaults.standard.bool(forKey: hiddenKey) }
        set { UserDefaults.standard.set(newValue, forKey: hiddenKey) }
    }

    private(set) var state = State(latin: false, locked: false)
    private var panel: NSPanel?
    private var tibetanButton = NSButton()
    private var latinButton = NSButton()
    private var lockButton = NSButton()
    private var symbolsButton = NSButton()
    private var stackerButton = NSButton()
    private var pendingHide: DispatchWorkItem?

    /// The panel's content, for rendering without showing it.
    var contentView: NSView? { ensurePanel().contentView }

    // MARK: Showing

    /// Shows the toolbar (unless the user turned it off) in the given state.
    func show(_ state: State) {
        pendingHide?.cancel()
        self.state = state
        guard !Self.isHidden else { hideNow(); return }
        let panel = ensurePanel()
        render()
        if !panel.isVisible { place(panel) }
        panel.orderFrontRegardless()
    }

    func update(_ state: State) {
        self.state = state
        render()
    }

    /// Hides shortly after, not at once: moving between fields or apps sends a
    /// deactivate then an activate, and hiding in between would flicker.
    func scheduleHide() {
        pendingHide?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.panel?.orderOut(nil) }
        pendingHide = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    func hideNow() {
        pendingHide?.cancel()
        panel?.orderOut(nil)
    }

    // MARK: Building

    private func ensurePanel() -> NSPanel {
        if let panel = panel { return panel }

        let logo = NSImageView()
        logo.image = Bundle.main.image(forResource: "toolbar-logo")
        logo.imageScaling = .scaleProportionallyUpOrDown
        logo.setAccessibilityLabel("T-Time, Tibetan input method")
        let logoHeight: CGFloat = 46
        let ratio = logo.image.map { $0.size.width / max($0.size.height, 1) } ?? 3.6
        logo.widthAnchor.constraint(equalToConstant: logoHeight * ratio).isActive = true
        logo.heightAnchor.constraint(equalToConstant: logoHeight).isActive = true

        // A custom pill, not NSSegmentedControl: this panel never becomes key, and
        // native segmented controls draw their selection grey in a non-key window.
        tibetanButton = modeButton("བོད", action: #selector(tibetanClicked),
                                   tip: "Tibetan (EWTS)", label: "Tibetan")
        latinButton = modeButton("A", action: #selector(latinClicked),
                                 tip: "Latin: typed text passes through unchanged", label: "Latin")
        let pill = NSStackView(views: [tibetanButton, latinButton])
        pill.orientation = .horizontal
        pill.spacing = 2
        pill.translatesAutoresizingMaskIntoConstraints = false
        let pillBox = NSView()
        pillBox.wantsLayer = true
        pillBox.layer?.cornerRadius = 12
        pillBox.layer?.borderWidth = 1.5
        pillBox.layer?.borderColor = Self.plum.withAlphaComponent(0.35).cgColor
        pillBox.addSubview(pill)
        NSLayoutConstraint.activate([
            pill.leadingAnchor.constraint(equalTo: pillBox.leadingAnchor, constant: 3),
            pill.trailingAnchor.constraint(equalTo: pillBox.trailingAnchor, constant: -3),
            pill.topAnchor.constraint(equalTo: pillBox.topAnchor, constant: 3),
            pill.bottomAnchor.constraint(equalTo: pillBox.bottomAnchor, constant: -3),
        ])
        pillBox.setAccessibilityLabel("Input mode")

        lockButton = iconButton(action: #selector(lockClicked), label: "Lock the input mode")
        symbolsButton = textButton("༄", action: #selector(symbolsClicked),
                                   tip: "Symbols (double-tap right Shift)", label: "Symbols")
        stackerButton = textButton("ཀྵ", action: #selector(stackerClicked),
                                   tip: "Stacker", label: "Stacker")

        let stack = NSStackView(views: [logo, pillBox, lockButton, symbolsButton, stackerButton])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 10
        stack.setCustomSpacing(16, after: logo)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = Self.cream.cgColor
        container.layer?.cornerRadius = 16
        container.layer?.borderColor = Self.plum.cgColor
        container.layer?.borderWidth = 1.5
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
        ])
        container.layoutSubtreeIfNeeded()

        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: container.fittingSize),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.contentView = container
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.appearance = NSAppearance(named: .aqua)  // the brand is light
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.setAccessibilityLabel("T-Time toolbar")
        NotificationCenter.default.addObserver(self, selector: #selector(panelMoved),
                                               name: NSWindow.didMoveNotification, object: panel)
        self.panel = panel
        render()
        return panel
    }

    private func modeButton(_ title: String, action: Selector, tip: String, label: String) -> NSButton {
        let b = NSButton(title: title, target: self, action: action)
        b.isBordered = false
        b.wantsLayer = true
        b.layer?.cornerRadius = 9
        b.toolTip = tip
        b.setAccessibilityLabel(label)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.widthAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        b.heightAnchor.constraint(equalToConstant: 30).isActive = true
        return b
    }

    private func style(_ b: NSButton, selected: Bool) {
        b.layer?.backgroundColor = selected ? Self.plum.cgColor : NSColor.clear.cgColor
        b.attributedTitle = NSAttributedString(string: b.title, attributes: [
            .font: NSFont.systemFont(ofSize: 16, weight: .semibold),
            .foregroundColor: selected ? NSColor.white : Self.plum,
        ])
        b.setAccessibilityValue(selected ? "selected" : "not selected")
    }

    private func iconButton(action: Selector, label: String) -> NSButton {
        let b = NSButton()
        b.isBordered = false
        b.imagePosition = .imageOnly
        b.contentTintColor = Self.plum
        b.target = self
        b.action = action
        b.setAccessibilityLabel(label)
        return b
    }

    private func textButton(_ title: String, action: Selector, tip: String, label: String) -> NSButton {
        let b = NSButton(title: title, target: self, action: action)
        b.bezelStyle = .rounded
        b.font = NSFont.systemFont(ofSize: 17)
        b.contentTintColor = Self.plum
        b.toolTip = tip
        b.setAccessibilityLabel(label)
        return b
    }

    private func render() {
        guard panel != nil else { return }
        style(tibetanButton, selected: !state.latin)
        style(latinButton, selected: state.latin)
        let symbol = state.locked ? "lock.fill" : "lock.open"
        lockButton.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        lockButton.contentTintColor = state.locked ? Self.pink : Self.plum.withAlphaComponent(0.55)
        lockButton.toolTip = state.locked
            ? "Locked: stays \(state.latin ? "Latin" : "Tibetan") when you change field or app. Click to unlock."
            : "Lock this mode across fields and apps (or double-tap left Shift)"
        symbolsButton.isEnabled = openSymbols != nil
        stackerButton.isEnabled = openStacker != nil
    }

    // MARK: Actions

    @objc private func tibetanClicked() { chooseMode?(false); render() }
    @objc private func latinClicked() { chooseMode?(true); render() }
    @objc private func lockClicked() { toggleLock?() }
    @objc private func symbolsClicked() { openSymbols?() }
    @objc private func stackerClicked() { openStacker?() }

    // MARK: Position

    @objc private func panelMoved(_ note: Notification) {
        guard let panel = panel, panel.isVisible else { return }
        UserDefaults.standard.set(NSStringFromPoint(panel.frame.origin), forKey: Self.originKey)
    }

    /// Puts the panel where the user left it, or bottom right the first time,
    /// and pulls it back on screen if that screen has gone.
    private func place(_ panel: NSPanel) {
        let size = panel.frame.size
        var origin: NSPoint
        if let saved = UserDefaults.standard.string(forKey: Self.originKey) {
            origin = NSPointFromString(saved)
        } else {
            let area = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
            origin = NSPoint(x: area.maxX - size.width - Self.margin, y: area.minY + Self.margin)
        }
        let frame = NSRect(origin: origin, size: size)
        if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(frame) }) {
            let area = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
            origin = NSPoint(x: area.maxX - size.width - Self.margin, y: area.minY + Self.margin)
        }
        panel.setFrameOrigin(origin)
    }
}
