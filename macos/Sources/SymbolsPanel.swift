import Cocoa

/// A scroll view's document: top-left origin, so cells lay out from the top.
private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

/// The whole illustration, uncropped (the cookies are the symbols), with rounded
/// corners. Give it the image's own proportions.
private final class BannerView: NSView {
    private let image: NSImage?

    init(image: NSImage?, size: NSSize) {
        self.image = image
        super.init(frame: NSRect(origin: .zero, size: size))
        wantsLayer = true
        layer?.cornerRadius = 20
        layer?.masksToBounds = true
        layer?.borderWidth = 2
        layer?.borderColor = StackerPanel.pinkStrong.cgColor
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: size.width).isActive = true
        heightAnchor.constraint(equalToConstant: size.height).isActive = true
        setAccessibilityLabel("A cat-maid icing Tibetan symbol cookies, and a yak sniffing them")
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        guard let image = image, image.size.width > 0 else { return }
        image.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 1)
    }
}

/// The symbols window: Tibetan punctuation, head marks, marks, numbers and
/// Sanskrit letters in one searchable table, in the same pink as the stacker.
/// Type to search (by name, EWTS, code point or the character), arrows move,
/// Return inserts, Tab switches to the stacker, Esc closes. A non-activating
/// panel: the document keeps focus and keys arrive through the input method.
final class SymbolsPanel: NSObject {
    static let shared = SymbolsPanel()

    let model = SymbolsModel()
    /// Puts text into the focused document; set by the active controller.
    var insert: ((String) -> Void)?

    private static let originKey = "SymbolsOrigin"
    private static let columns = 7
    private static let cellSize = NSSize(width: 78, height: 64)
    private static let gap: CGFloat = 5

    private var panel: NSPanel?
    private var pendingClose: DispatchWorkItem?
    private let searchLabel = NSTextField(labelWithString: "")
    private let scroll = NSScrollView()
    private let documentView = FlippedView()
    private var chips: [(String?, BubbleButton)] = []
    private var cells: [BubbleButton] = []
    private let bigGlyph = NSTextField(labelWithString: "")
    private let titleLabel = NSTextField(labelWithString: "")
    private let nameLabel = NSTextField(wrappingLabelWithString: "")
    private let typeLabel = NSTextField(labelWithString: "")
    private let noteLabel = NSTextField(wrappingLabelWithString: "")
    private let hintLabel = NSTextField(labelWithString: "")
    private var insertButton: BubbleButton!
    private var copyButton: BubbleButton!

    var isOpen: Bool { panel?.isVisible ?? false }
    var contentView: NSView? { ensurePanel().contentView }

    // MARK: Showing

    func open(centeredOn center: NSPoint? = nil) {
        pendingClose?.cancel()
        let panel = ensurePanel()
        refresh()
        if !panel.isVisible {
            if let c = center {
                panel.setFrameOrigin(NSPoint(x: c.x - panel.frame.width / 2, y: c.y - panel.frame.height / 2))
            } else { place(panel) }
        }
        panel.orderFrontRegardless()
        panel.invalidateShadow()
    }

    func close() {
        pendingClose?.cancel()
        panel?.orderOut(nil)
    }

    func toggle() { isOpen ? close() : open() }

    func scheduleClose() {
        guard isOpen else { return }
        pendingClose?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.panel?.orderOut(nil) }
        pendingClose = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    func cancelClose() { pendingClose?.cancel() }

    // MARK: Keys

    /// Keys while the window is open. Returns whether the key was used.
    func handle(_ key: KeyInput) -> Bool {
        guard isOpen else { return false }
        switch key {
        case .escape:
            if model.query.isEmpty { close() } else { model.clearQuery() }
        case .enter:
            guard model.selectedEntry != nil else { return false }
            insertSelected()
        case .backspace:
            guard model.backspace() else { return false }
        case .text(let s):
            if s == " " && model.query.isEmpty { return false }
            model.type(s)
        case .left: model.move(-1)
        case .right: model.move(1)
        case .up: model.move(-Self.columns)
        case .down: model.move(Self.columns)
        case .tab:
            let center = panel.map { NSPoint(x: $0.frame.midX, y: $0.frame.midY) }
            close()
            StackerPanel.shared.open(centeredOn: center)
            return true
        case .other:
            return false
        }
        refresh()
        return true
    }

    private func insertSelected() {
        guard let e = model.selectedEntry else { return }
        insert?(e.text)
        model.setHint("Inserted \(e.label.isEmpty ? e.text : e.label).")
    }

    /// An EWTS of just a space would look blank.
    private static func shown(_ ewts: String?) -> String { ewts == " " ? "space" : ewts ?? "" }

    // MARK: Building

    private func ensurePanel() -> NSPanel {
        if let panel = panel { return panel }
        let plum = Toolbar.plum

        var art: NSImage?
        if let url = Bundle.main.url(forResource: "symbols-art", withExtension: "webp") {
            art = NSImage(contentsOf: url)
        }
        let artWidth: CGFloat = 450
        let banner = BannerView(image: art, size: NSSize(width: artWidth, height: artWidth * 1024 / 1536))

        let title = NSTextField(labelWithString: "Symbols")
        title.font = NSFont.systemFont(ofSize: 24, weight: .heavy)
        title.textColor = plum
        let tagline = NSTextField(labelWithString: "punctuation, marks and Sanskrit letters")
        tagline.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        tagline.textColor = plum.withAlphaComponent(0.7)
        let spacer = NSView()
        spacer.setContentHuggingPriority(.init(1), for: .horizontal)
        let closeButton = BubbleButton(glyph: "✕", glyphSize: 13, tip: "Close (Esc)", label: "Close") { [weak self] in
            self?.close()
        }
        closeButton.widthAnchor.constraint(equalToConstant: 30).isActive = true
        closeButton.heightAnchor.constraint(equalToConstant: 30).isActive = true
        let header = NSStackView(views: [title, tagline, spacer, closeButton])
        header.alignment = .lastBaseline
        header.spacing = 8

        searchLabel.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .semibold)
        searchLabel.textColor = plum

        // Category chips: All, then each category in the catalogue's order.
        var chipViews: [NSView] = []
        for c in [nil] + model.categories.map({ Optional($0) }) {
            let b = BubbleButton(glyph: c?.capitalized ?? "All", glyphSize: 12, tip: c.map { "Only \($0)" } ?? "All symbols",
                                 label: c ?? "All") { [weak self] in
                self?.model.setCategory(c)
                self?.refresh()
            }
            b.heightAnchor.constraint(equalToConstant: 28).isActive = true
            b.widthAnchor.constraint(greaterThanOrEqualToConstant: 40).isActive = true
            chips.append((c, b))
            chipViews.append(b)
        }
        let chipRow = NSStackView(views: chipViews)
        chipRow.spacing = 5

        let width = CGFloat(Self.columns) * (Self.cellSize.width + Self.gap) - Self.gap
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.autohidesScrollers = true
        scroll.scrollerStyle = .overlay
        scroll.documentView = documentView
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.widthAnchor.constraint(equalToConstant: width + 14).isActive = true
        scroll.heightAnchor.constraint(equalToConstant: 338).isActive = true

        let detail = detailCard(width: artWidth)

        hintLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        hintLabel.textColor = plum

        // Left: the illustration and the selected symbol. Right: the table.
        let left = NSStackView(views: [banner, detail])
        left.orientation = .vertical
        left.alignment = .leading
        left.spacing = 12
        let right = NSStackView(views: [header, searchLabel, chipRow, scroll, hintLabel])
        right.orientation = .vertical
        right.alignment = .leading
        right.spacing = 9
        header.widthAnchor.constraint(equalToConstant: width + 14).isActive = true
        let stack = NSStackView(views: [left, right])
        stack.orientation = .horizontal
        stack.alignment = .top
        stack.spacing = 22
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 22, bottom: 20, right: 22)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = StackerPanel.pink.cgColor
        container.layer?.cornerRadius = 28
        container.layer?.borderWidth = 3
        container.layer?.borderColor = StackerPanel.pinkStrong.cgColor
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        container.layoutSubtreeIfNeeded()
        var size = container.fittingSize
        size.height = max(size.height, right.fittingSize.height + 40)

        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: size),
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
        panel.setAccessibilityLabel("T-Time symbols")
        NotificationCenter.default.addObserver(self, selector: #selector(panelMoved),
                                               name: NSWindow.didMoveNotification, object: panel)
        self.panel = panel
        refresh()
        return panel
    }

    private func detailCard(width: CGFloat) -> NSView {
        let plum = Toolbar.plum
        bigGlyph.font = NSFont.systemFont(ofSize: 44)
        bigGlyph.textColor = plum
        bigGlyph.alignment = .center
        bigGlyph.translatesAutoresizingMaskIntoConstraints = false
        bigGlyph.widthAnchor.constraint(equalToConstant: 80).isActive = true
        titleLabel.font = NSFont.systemFont(ofSize: 15, weight: .bold)
        titleLabel.textColor = plum
        nameLabel.font = NSFont.systemFont(ofSize: 10.5)
        nameLabel.textColor = plum.withAlphaComponent(0.8)
        typeLabel.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold)
        typeLabel.textColor = plum
        noteLabel.font = NSFont.systemFont(ofSize: 11)
        noteLabel.textColor = plum.withAlphaComponent(0.85)
        for l in [nameLabel, noteLabel] { l.preferredMaxLayoutWidth = width - 260 }

        insertButton = BubbleButton(glyph: "Insert  ⏎", glyphSize: 13, tip: "Put it in the document (Return)", label: "Insert") { [weak self] in
            self?.insertSelected()
            self?.refresh()
        }
        insertButton.filled = true
        copyButton = BubbleButton(glyph: "Copy", glyphSize: 13, tip: "Copy the symbol", label: "Copy") { [weak self] in
            guard let e = self?.model.selectedEntry else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(e.text, forType: .string)
            self?.model.setHint("Copied \(e.text).")
            self?.refresh()
        }
        let buttons = NSStackView(views: [insertButton, copyButton])
        buttons.orientation = .vertical
        buttons.spacing = 6
        for b in [insertButton!, copyButton!] {
            b.widthAnchor.constraint(equalToConstant: 100).isActive = true
            b.heightAnchor.constraint(equalToConstant: 32).isActive = true
        }

        let text = NSStackView(views: [titleLabel, nameLabel, typeLabel, noteLabel])
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = 3
        let row = NSStackView(views: [bigGlyph, text, buttons])
        row.alignment = .centerY
        row.spacing = 12
        row.edgeInsets = NSEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        row.translatesAutoresizingMaskIntoConstraints = false

        let box = NSView()
        box.wantsLayer = true
        box.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.7).cgColor
        box.layer?.cornerRadius = 20
        box.layer?.borderWidth = 2
        box.layer?.borderColor = StackerPanel.pinkStrong.cgColor
        box.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(row)
        NSLayoutConstraint.activate([
            box.widthAnchor.constraint(equalToConstant: width),
            box.heightAnchor.constraint(equalToConstant: 132),
            row.leadingAnchor.constraint(equalTo: box.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: box.trailingAnchor),
            row.centerYAnchor.constraint(equalTo: box.centerYAnchor),
        ])
        return box
    }

    // MARK: Drawing the state

    func refresh() {
        guard panel != nil else { return }
        searchLabel.stringValue = model.query.isEmpty
            ? "search: type a name, EWTS or the character" : "search: \(model.query)▏"
        searchLabel.alphaValue = model.query.isEmpty ? 0.6 : 1
        for (c, b) in chips { b.filled = c == model.category }

        // The grid is rebuilt: at most a few dozen cells.
        for v in documentView.subviews { v.removeFromSuperview() }
        cells = []
        let step = Self.cellSize.width + Self.gap
        for (i, e) in model.results.enumerated() {
            let b = BubbleButton(glyph: e.display, caption: Self.shown(e.ewts), glyphSize: 24,
                                 tip: e.label.isEmpty ? e.name : e.label, label: e.label.isEmpty ? e.name : e.label) { [weak self] in
                self?.model.select(i)
                self?.insertSelected()
                self?.refresh()
            }
            b.translatesAutoresizingMaskIntoConstraints = true
            b.frame = NSRect(x: CGFloat(i % Self.columns) * step, y: CGFloat(i / Self.columns) * (Self.cellSize.height + Self.gap),
                             width: Self.cellSize.width, height: Self.cellSize.height)
            b.filled = i == model.selected
            documentView.addSubview(b)
            cells.append(b)
        }
        let rows = (model.results.count + Self.columns - 1) / Self.columns
        let height = max(CGFloat(rows) * (Self.cellSize.height + Self.gap), 1)
        documentView.frame = NSRect(x: 0, y: 0, width: CGFloat(Self.columns) * step, height: height)
        if cells.indices.contains(model.selected) { documentView.scrollToVisible(cells[model.selected].frame.insetBy(dx: 0, dy: -4)) }

        if let e = model.selectedEntry {
            bigGlyph.stringValue = e.display
            titleLabel.stringValue = e.label.isEmpty ? e.name.capitalized : e.label
            nameLabel.stringValue = "\(e.name.capitalized)  ·  \(e.category)"
            typeLabel.stringValue = (e.ewts.map { "type: \(Self.shown($0))   " } ?? "") + e.codePoints
            noteLabel.stringValue = e.note
        } else {
            bigGlyph.stringValue = "∅"
            titleLabel.stringValue = "Nothing matches"
            nameLabel.stringValue = "Try a shorter search, or pick All."
            typeLabel.stringValue = ""
            noteLabel.stringValue = ""
        }
        noteLabel.isHidden = noteLabel.stringValue.isEmpty
        typeLabel.isHidden = typeLabel.stringValue.isEmpty
        insertButton.isEnabled = model.selectedEntry != nil
        copyButton.isEnabled = model.selectedEntry != nil
        hintLabel.stringValue = model.hint.isEmpty
            ? "Type to search, arrows move, Return inserts, Tab for the stacker, Esc closes." : model.hint
        panel?.invalidateShadow()
    }

    // MARK: Position

    @objc private func panelMoved(_ note: Notification) {
        guard let panel = panel, panel.isVisible else { return }
        UserDefaults.standard.set(NSStringFromPoint(panel.frame.origin), forKey: Self.originKey)
    }

    private func place(_ panel: NSPanel) {
        let size = panel.frame.size
        let area = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        var origin = NSPoint(x: area.midX - size.width / 2, y: area.midY - size.height / 2)
        if let saved = UserDefaults.standard.string(forKey: Self.originKey) {
            let o = NSPointFromString(saved)
            if NSScreen.screens.contains(where: { $0.visibleFrame.intersects(NSRect(origin: o, size: size)) }) { origin = o }
        }
        panel.setFrameOrigin(origin)
    }
}
