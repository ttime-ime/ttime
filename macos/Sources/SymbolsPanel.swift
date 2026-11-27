import Cocoa

/// A scroll view's document: top-left origin, so cells lay out from the top.
private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

/// The whole illustration, uncropped (the cookies are the symbols), with rounded
/// corners. Its height follows its width, so the window can show it at two sizes.
private final class BannerView: NSView {
    private let image: NSImage?
    private let aspect: CGFloat

    init(image: NSImage?, width: CGFloat, aspect: CGFloat) {
        self.image = image
        self.aspect = aspect
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: width * aspect))
        wantsLayer = true
        layer?.cornerRadius = Theme.current.brutal ? 4 : 20
        layer?.masksToBounds = true
        layer?.borderWidth = Theme.current.brutal ? 0 : 2
        layer?.borderColor = StackerPanel.pinkStrong.cgColor
        translatesAutoresizingMaskIntoConstraints = false
        setAccessibilityLabel("A cat-maid icing Tibetan symbol cookies, and a yak sniffing them")
    }
    required init?(coder: NSCoder) { fatalError() }

    private lazy var sizeConstraints: (NSLayoutConstraint, NSLayoutConstraint) = {
        let w = widthAnchor.constraint(equalToConstant: frame.width)
        let h = heightAnchor.constraint(equalToConstant: frame.height)
        NSLayoutConstraint.activate([w, h])
        return (w, h)
    }()

    func setWidth(_ width: CGFloat) {
        sizeConstraints.0.constant = width
        sizeConstraints.1.constant = (width * aspect).rounded()
        needsDisplay = true
    }

    var height: CGFloat { sizeConstraints.1.constant }

    override func draw(_ dirtyRect: NSRect) {
        guard let image = image, image.size.width > 0 else { return }
        image.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 1)
    }
}

/// The symbols window: Tibetan punctuation, head marks, marks and Sanskrit
/// letters in one table, in the same pink as the stacker. Click a symbol (or move
/// with the arrows and press Return) to insert it; the line under the table says
/// what the selected one is and how to type it. Tab switches to the next panel, Esc
/// closes. A non-activating panel: the document keeps focus and keys arrive
/// through the input method.
///
/// Drag the corner grip to resize: the table gets more or fewer columns, and
/// narrow enough the window becomes one column with the picture above the table
/// (the same views, rearranged, as in the stacker).
final class SymbolsPanel: NSObject {
    static var shared = SymbolsPanel()

    /// Builds the window again in the current style, where it was.
    static func rebuild() {
        let old = shared
        let wasOpen = old.isOpen
        let tl = old.panel.map { PanelTabs.topLeft(of: $0) }
        old.pendingClose?.cancel()
        old.panel?.orderOut(nil)
        let new = SymbolsPanel()
        new.insert = old.insert
        shared = new
        if wasOpen { new.open(topLeft: tl) }
    }

    let model = SymbolsModel()
    /// Puts text into the focused document; set by the active controller.
    var insert: ((String) -> Void)?

    private static let originKey = "SymbolsTopLeft"
    private static let cellSize = NSSize(width: 56, height: 46)
    private static let gap: CGFloat = 4
    private static let step: CGFloat = 60  // cell width plus gap
    /// Dragged narrower than this, the window becomes one column.
    private static let singleColumnBelow: CGFloat = 800
    private static let bannerWide: CGFloat = 600

    private var panel: NSPanel?
    private var pendingClose: DispatchWorkItem?
    private var compact = false
    private var columns = 8
    private var tableHeight: CGFloat = 346

    private let scroll = NSScrollView()
    private let documentView = FlippedView()
    private var cells: [BubbleButton] = []
    private let hintLabel = NSTextField(wrappingLabelWithString: "")

    // The parts the two layouts share, and the constraints that differ.
    private var container: DraggableView!
    private let root = NSStackView()
    private let leftColumn = NSStackView()
    private let rightColumn = NSStackView()
    private var header: NSStackView!
    private var banner: BannerView!
    private var scrollWidth: NSLayoutConstraint!
    private var scrollHeight: NSLayoutConstraint!
    private var headerWidth: NSLayoutConstraint!

    var isOpen: Bool { panel?.isVisible ?? false }
    var window: NSPanel? { panel }
    var contentView: NSView? { ensurePanel().contentView }

    // MARK: Showing

    func open(topLeft: NSPoint? = nil) {
        pendingClose?.cancel()
        let panel = ensurePanel()
        if compact != PanelTabs.compact {
            setCompact(PanelTabs.compact)
            PanelTabs.setSize(panel, container.fittingSize)
        }
        refresh()
        if !panel.isVisible { PanelTabs.place(panel, key: Self.originKey, topLeft: topLeft) }
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

    /// Keys while the window is open. Returns whether the key was used; typing is
    /// not (there is no search), so letters go on to the document.
    func handle(_ key: KeyInput) -> Bool {
        guard isOpen else { return false }
        switch key {
        case .escape:
            close()
            return true
        case .enter:
            guard model.selectedEntry != nil else { return false }
            insertSelected()
        case .left: model.move(-1)
        case .right: model.move(1)
        case .up: model.move(-columns)
        case .down: model.move(columns)
        case .tab:
            PanelTabs.cycle(from: .symbols, panel: panel)
            return true
        case .backspace, .text, .other:
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
        compact = PanelTabs.compact
        loadSize()

        var art: NSImage?
        if let url = Bundle.main.url(forResource: Theme.current.brutal ? "brutal-art" : "symbols-art", withExtension: "webp") {
            art = NSImage(contentsOf: url)
        }
        banner = BannerView(image: art, width: Self.bannerWide, aspect: 1024 / 1536)

        // The tabs and the close button.
        let tabs = PanelTabs.makeBar(selected: .symbols) { [weak self] in self?.panel }
        let spacer = NSView()
        spacer.setContentHuggingPriority(.init(1), for: .horizontal)
        let closeButton = BubbleButton(glyph: "✕", glyphSize: 13, tip: "Close (Esc)", label: "Close") { [weak self] in
            self?.close()
        }
        closeButton.widthAnchor.constraint(equalToConstant: 30).isActive = true
        closeButton.heightAnchor.constraint(equalToConstant: 30).isActive = true
        if Theme.current.brutal {
            let title = NSTextField(labelWithString: "T-Time")
            title.font = Theme.current.serif(30)
            title.textColor = Theme.current.ink
            let tagline = NSTextField(labelWithString: "Tibetan symbols, set in type.")
            tagline.font = Theme.current.serif(12, italic: true)
            tagline.textColor = Theme.current.ink.withAlphaComponent(0.7)
            let block = NSStackView(views: [title, tagline])
            block.orientation = .vertical
            block.alignment = .leading
            block.spacing = 0
            let rule = RuleView(vertical: true)
            rule.heightAnchor.constraint(equalToConstant: 38).isActive = true
            header = NSStackView(views: [block, rule, tabs, spacer, closeButton])
        } else {
            header = NSStackView(views: [tabs, spacer, closeButton])
        }
        header.alignment = .centerY
        header.spacing = 10
        headerWidth = header.widthAnchor.constraint(equalToConstant: 100)
        headerWidth.isActive = true

        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.autohidesScrollers = true
        scroll.scrollerStyle = .overlay
        scroll.documentView = documentView
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scrollWidth = scroll.widthAnchor.constraint(equalToConstant: 600)
        scrollHeight = scroll.heightAnchor.constraint(equalToConstant: tableHeight)
        NSLayoutConstraint.activate([scrollWidth, scrollHeight])

        hintLabel.maximumNumberOfLines = 3

        leftColumn.orientation = .vertical
        leftColumn.alignment = .leading
        rightColumn.orientation = .vertical
        rightColumn.alignment = .leading
        rightColumn.spacing = 9
        root.edgeInsets = NSEdgeInsets(top: 20, left: 22, bottom: 20, right: 22)
        root.translatesAutoresizingMaskIntoConstraints = false

        container = DraggableView()
        container.wantsLayer = true
        container.layer?.backgroundColor = container.resolved(Theme.current.paper)
        container.layer?.cornerRadius = Theme.current.panelRadius
        container.layer?.borderWidth = Theme.current.panelBorder
        container.layer?.borderColor = container.resolved(Theme.current.panelBorderColor)
        container.addSubview(root)
        // The far edges give way (priority 750) so a window mid-resize never
        // conflicts with controls that have a fixed size.
        let trailing = root.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        let bottom = root.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        trailing.priority = .defaultHigh
        bottom.priority = .defaultHigh
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            root.topAnchor.constraint(equalTo: container.topAnchor),
            trailing, bottom,
        ])
        let grip = ResizeGrip()
        grip.constrain = { [weak self] wanted in self?.proposedSize(wanted) ?? wanted }
        container.addSubview(grip)
        NSLayoutConstraint.activate([
            grip.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -9),
            grip.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -9),
        ])

        applyLayout()
        container.layoutSubtreeIfNeeded()
        var size = container.fittingSize
        if !compact { size.height = max(size.height, leftColumn.fittingSize.height + 40) }

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
        panel.appearance = Theme.current.appearance
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.setAccessibilityLabel("T-Time symbols")
        for name in [NSWindow.didMoveNotification, NSWindow.didResizeNotification] {
            NotificationCenter.default.addObserver(self, selector: #selector(panelMoved), name: name, object: panel)
        }
        self.panel = panel
        refresh()
        return panel
    }

    // MARK: One column or two, and how many columns of symbols

    private func loadSize() {
        let d = UserDefaults.standard
        let mode = compact ? "Compact" : "Wide"
        let c = d.integer(forKey: "SymbolsLayoutColumns" + mode)
        columns = c > 0 ? c : (compact ? 7 : 8)
        let h = d.double(forKey: "SymbolsLayoutHeight" + mode)
        tableHeight = h > 0 ? CGFloat(h) : (compact ? 250 : 346)
    }

    private func saveSize() {
        let d = UserDefaults.standard
        let mode = compact ? "Compact" : "Wide"
        d.set(columns, forKey: "SymbolsLayoutColumns" + mode)
        d.set(Double(tableHeight), forKey: "SymbolsLayoutHeight" + mode)
    }

    /// Arranges the shared views for `compact` and the current number of columns.
    /// Views move between stacks; the constraints that tie them to a neighbour are
    /// all constants, so nothing is lost on the way.
    private func applyLayout() {
        let c = compact
        let tableWidth = CGFloat(columns) * Self.step - Self.gap + 14
        scrollWidth.constant = tableWidth
        scrollHeight.constant = tableHeight
        headerWidth.constant = tableWidth
        // Wide: the picture takes the left half. Compact: it spans the window.
        banner.setWidth(c ? tableWidth : Self.bannerWide)
        hintLabel.preferredMaxLayoutWidth = tableWidth

        if c {
            root.arrange([header, banner, scroll, hintLabel])
            leftColumn.arrange([])
            rightColumn.arrange([])
            root.orientation = .vertical
            root.alignment = .leading
            root.spacing = 9
        } else {
            leftColumn.arrange([banner])
            rightColumn.arrange([header, scroll, hintLabel])
            root.arrange([leftColumn, rightColumn])
            root.orientation = .horizontal
            root.alignment = .top
            root.spacing = 22
        }
    }

    private func setCompact(_ c: Bool) {
        guard c != compact else { return }
        compact = c
        PanelTabs.compact = c
        loadSize()
        applyLayout()
        refresh()
    }

    /// The size the window takes for a drag to `wanted`. Width picks the layout
    /// and the number of columns of symbols; height is the table's, which scrolls.
    private func proposedSize(_ wanted: NSSize) -> NSSize {
        var changed = false
        let wantCompact = wanted.width < Self.singleColumnBelow
        if wantCompact != compact {
            compact = wantCompact
            PanelTabs.compact = wantCompact
            loadSize()
            changed = true
        }
        // Width left for the table, after the picture (when wide) and the margins.
        let fixed: CGFloat = compact ? 44 + 14 : 22 + Self.bannerWide + 22 + 14 + 22
        let range = compact ? 5...9 : 6...16
        let fit = Int(((wanted.width - fixed + Self.gap) / Self.step).rounded(.down))
        let cols = min(max(fit, range.lowerBound), range.upperBound)
        if cols != columns { columns = cols; changed = true }
        if changed { applyLayout() }

        // Everything that is not the table, so the rest of the height is the table's.
        let chrome = (compact ? root.fittingSize.height : rightColumn.fittingSize.height + 40) - scrollHeight.constant
        let leftMin = compact ? 0 : leftColumn.fittingSize.height + 40
        let minTable = max(compact ? 140 : 200, leftMin - chrome)
        tableHeight = min(max(wanted.height - chrome, minTable), 900)
        scrollHeight.constant = tableHeight
        if changed { refresh() }
        saveSize()
        var size = container.fittingSize
        if !compact { size.height = max(size.height, leftMin) }
        return size
    }

    // MARK: Drawing the state

    func refresh() {
        guard panel != nil else { return }

        // The grid is rebuilt: about fifty cells.
        for v in documentView.subviews { v.removeFromSuperview() }
        cells = []
        let step = Self.step
        for (i, e) in model.results.enumerated() {
            let name = e.label.isEmpty ? e.name.capitalized : e.label
            let b = BubbleButton(glyph: e.display, caption: Self.shown(e.ewts), glyphSize: 18,
                                 tip: name, label: name) { [weak self] in
                self?.model.select(i)
                self?.insertSelected()
                self?.refresh()
            }
            b.translatesAutoresizingMaskIntoConstraints = true
            b.frame = NSRect(x: CGFloat(i % columns) * step, y: CGFloat(i / columns) * (Self.cellSize.height + Self.gap),
                             width: Self.cellSize.width, height: Self.cellSize.height)
            b.filled = i == model.selected
            documentView.addSubview(b)
            cells.append(b)
        }
        let rows = (model.results.count + columns - 1) / columns
        let height = max(CGFloat(rows) * (Self.cellSize.height + Self.gap) - Self.gap, 1)
        documentView.frame = NSRect(x: 0, y: 0, width: CGFloat(columns) * step, height: height)
        if cells.indices.contains(model.selected) { documentView.scrollToVisible(cells[model.selected].frame.insetBy(dx: 0, dy: -4)) }

        // One line on the selected symbol (or what was just done), one on the keys.
        var first = model.hint
        if first.isEmpty, let e = model.selectedEntry {
            let name = e.label.isEmpty ? e.name.capitalized : e.label
            first = name + (e.ewts.map { "  ·  type \(Self.shown($0))" } ?? "") + "  ·  " + e.codePoints
        }
        let text = NSMutableAttributedString(string: first, attributes: [
            .font: Theme.current.brutal ? Theme.current.serif(14) : NSFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: Theme.current.ink])
        text.append(NSAttributedString(string: "\nClick or Return inserts · arrows move · Tab: next panel · Esc closes", attributes: [
            .font: NSFont.systemFont(ofSize: 10), .foregroundColor: Theme.current.ink.withAlphaComponent(0.7)]))
        hintLabel.attributedStringValue = text
        panel?.invalidateShadow()
    }

    // MARK: Position

    @objc private func panelMoved(_ note: Notification) {
        guard let panel = panel else { return }
        PanelTabs.save(panel, key: Self.originKey)
    }
}
