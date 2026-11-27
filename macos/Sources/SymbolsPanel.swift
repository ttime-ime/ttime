import Cocoa

/// A scroll view's document: top-left origin, so cells lay out from the top.
private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

/// Banner illustration. Bubblegum: height follows width × aspect (full image).
/// Brutalist: fixed banner height with aspect-fill (centred crop, no stretch).
private final class BannerView: NSView {
    private let image: NSImage?
    private let aspect: CGFloat
    private let fixedHeight: CGFloat?
    /// When true with `fixedHeight`, scale to fill the banner and crop overflow.
    private let aspectFill: Bool

    init(image: NSImage?, width: CGFloat, aspect: CGFloat, fixedHeight: CGFloat? = nil,
         aspectFill: Bool = false,
         accessibilityDescription: String = "A cat-maid icing Tibetan symbol cookies, and a yak sniffing them") {
        self.image = image
        self.aspect = aspect
        self.fixedHeight = fixedHeight
        self.aspectFill = aspectFill
        let h = fixedHeight ?? (width * aspect)
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: h))
        wantsLayer = true
        layer?.cornerRadius = Theme.current.artRadius
        layer?.masksToBounds = true
        layer?.borderWidth = Theme.current.brutal ? 0 : 2
        layer?.borderColor = StackerPanel.pinkStrong.cgColor
        translatesAutoresizingMaskIntoConstraints = false
        setAccessibilityLabel(accessibilityDescription)
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
        sizeConstraints.1.constant = fixedHeight ?? (width * aspect).rounded()
        needsDisplay = true
    }

    var height: CGFloat { sizeConstraints.1.constant }

    override func draw(_ dirtyRect: NSRect) {
        guard let image = image, image.size.width > 0 else {
            if fixedHeight != nil { Theme.current.paper.setFill(); bounds.fill() }
            return
        }
        if aspectFill, fixedHeight != nil {
            // Scale to cover the banner; crop centred overflow (no distortion).
            let scale = max(bounds.width / image.size.width, bounds.height / image.size.height)
            let drawW = image.size.width * scale
            let drawH = image.size.height * scale
            let draw = NSRect(x: (bounds.width - drawW) / 2, y: (bounds.height - drawH) / 2,
                              width: drawW, height: drawH)
            image.draw(in: draw, from: .zero, operation: .sourceOver, fraction: 1)
        } else if fixedHeight != nil {
            Theme.current.paper.setFill()
            bounds.fill()
            let imgAspect = image.size.height / max(image.size.width, 1)
            var draw = bounds
            if imgAspect > bounds.height / max(bounds.width, 1) {
                let w = bounds.height / imgAspect
                draw = NSRect(x: (bounds.width - w) / 2, y: 0, width: w, height: bounds.height)
            } else {
                let h = bounds.width * imgAspect
                draw = NSRect(x: 0, y: (bounds.height - h) / 2, width: bounds.width, height: h)
            }
            image.draw(in: draw, from: .zero, operation: .sourceOver, fraction: 1)
        } else {
            image.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 1)
        }
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

    private static let originKey = PanelTabs.originKey
    private static var cellSize: NSSize { Theme.current.symbolsCell }
    private static var gapX: CGFloat { Theme.current.symbolsGapX }
    private static var gapY: CGFloat { Theme.current.symbolsGapY }
    private static var step: CGFloat { cellSize.width + gapX }
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

    var isOpen: Bool { panel?.isVisible ?? false }
    var window: NSPanel? { panel }
    var contentView: NSView? { ensurePanel().contentView }

    // MARK: Showing

    func open(topLeft: NSPoint? = nil) {
        pendingClose?.cancel()
        let panel = ensurePanel()
        let h = PanelTabs.height(for: .symbols)
        PanelTabs.setSize(panel, NSSize(width: PanelTabs.width, height: h))
        adaptHeight(h)
        refresh()
        if !panel.isVisible { PanelTabs.place(panel, key: Self.originKey, topLeft: topLeft) }
        panel.orderFrontRegardless()
        panel.invalidateShadow()
    }

    /// Content-tight height: header + banner + grid document + footer (no empty scroll pad).
    var naturalHeight: CGFloat {
        _ = ensurePanel()
        loadSize()
        applyLayout()
        refresh()
        let rows = max(1, (model.results.count + max(columns, 1) - 1) / max(columns, 1))
        let docH = CGFloat(rows) * (Self.cellSize.height + Self.gapY) - Self.gapY
        scrollHeight.constant = docH
        tableHeight = docH
        container.layoutSubtreeIfNeeded()
        // Header + banner + document + footer + root insets/spacing.
        let measured = ceil(root.fittingSize.height)
        // Guard against a stale oversized scrollHeight leaking into fittingSize.
        return min(measured, ceil(PanelTabs.insets.top + PanelTabs.insets.bottom
                                  + 38 + Theme.current.symbolsBannerHeight + docH + 70 + Theme.current.rootSpacing * 4))
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

        let t0 = Theme.current
        var art: NSImage?
        let artAspect: CGFloat
        let fixed: CGFloat?
        let artLabel: String
        let fill: Bool
        if t0.brutal {
            // Landscape banner at the design height (476×120); aspect-fill, no stretch.
            if let url = Bundle.main.url(forResource: "symbols-brutal", withExtension: "png") {
                art = NSImage(contentsOf: url)
            }
            artAspect = art.flatMap { $0.size.width > 0 ? $0.size.height / $0.size.width : nil }
                ?? (t0.symbolsBannerHeight / max(PanelTabs.innerWidth, 1))
            fixed = t0.symbolsBannerHeight
            fill = true
            artLabel = "A stencil of a Tibetan vessel on weathered concrete panels"
        } else {
            if let url = Bundle.main.url(forResource: "symbols-art", withExtension: "webp") {
                art = NSImage(contentsOf: url)
            }
            artAspect = 1024 / 1536
            fixed = nil
            fill = false
            artLabel = "A cat-maid icing Tibetan symbol cookies, and a yak sniffing them"
        }
        banner = BannerView(image: art, width: Self.bannerWide, aspect: artAspect, fixedHeight: fixed,
                            aspectFill: fill, accessibilityDescription: artLabel)

        // The same title, tabs and close button as the other panels.
        header = PanelTabs.makeHeader(selected: .symbols, panel: { [weak self] in self?.panel }) { [weak self] in self?.close() }

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
        rightColumn.spacing = Theme.current.rootSpacing
        root.edgeInsets = PanelTabs.insets
        root.spacing = Theme.current.rootSpacing
        root.translatesAutoresizingMaskIntoConstraints = false

        // Warm the symbols ink envelope from the full catalogue (all categories).
        let t = Theme.current
        var inventory: [SymbolEntry] = []
        let probe = SymbolsModel()
        inventory.append(contentsOf: probe.results)
        for cat in probe.categories {
            probe.setCategory(cat)
            inventory.append(contentsOf: probe.results)
        }
        GlyphCaptionLayout.warmSymbols(entries: inventory, glyphSize: t.symbolsGlyphSize)

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

    // MARK: Size

    /// The table is as many columns as fit the navigator's width.
    private func loadSize() {
        // 7×56 + 6×14 = 476 at the standard content width.
        columns = max(5, Int((PanelTabs.innerWidth + Self.gapX) / Self.step))
        tableHeight = compactTableHeight
    }
    private let compactTableHeight: CGFloat = 330

    /// Arranges the views in one column at the navigator's width.
    private func applyLayout() {
        let tableWidth = PanelTabs.innerWidth
        scrollWidth.constant = tableWidth
        scrollHeight.constant = tableHeight
        banner.setWidth(tableWidth)
        hintLabel.preferredMaxLayoutWidth = tableWidth
        var body: [NSView] = [header, banner, scroll]
        if Theme.current.brutal {
            let rule = RuleView(vertical: false)
            rule.widthAnchor.constraint(equalToConstant: tableWidth).isActive = true
            body.append(rule)
        }
        body.append(hintLabel)
        root.arrange(body)
        leftColumn.arrange([])
        rightColumn.arrange([])
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = Theme.current.rootSpacing
        if Theme.current.brutal {
            // ~4 pt more air between the panorama and the first symbol row.
            root.setCustomSpacing(16, after: banner)
            root.setCustomSpacing(6, after: scroll)
        }
    }

    /// Gives the table whatever height the navigator has left after the rest.
    /// Brutalist defaults to the document height; extra space only when the user grows the window.
    private func adaptHeight(_ height: CGFloat) {
        guard container != nil else { return }
        container.layoutSubtreeIfNeeded()
        let chrome = root.fittingSize.height - scrollHeight.constant
        let rows = max(1, (model.results.count + columns - 1) / columns)
        let docH = CGFloat(rows) * (Self.cellSize.height + Self.gapY) - Self.gapY
        let available = max(140, height - chrome)
        // Use remaining window space; when that exceeds the document the clip view
        // simply shows paper below the last row (user-enlarged windows only).
        tableHeight = Theme.current.brutal ? max(docH, available) : available
        _ = docH
        scrollHeight.constant = tableHeight
        container.layoutSubtreeIfNeeded()
    }

    /// The size the window takes for a drag to `wanted`: only the height changes.
    private func proposedSize(_ wanted: NSSize) -> NSSize {
        let size = PanelTabs.proposed(wanted, tab: .symbols)
        adaptHeight(size.height)
        refresh()
        return size
    }

    // MARK: Drawing the state

    func refresh() {
        guard panel != nil else { return }

        // The grid is rebuilt: about fifty cells.
        for v in documentView.subviews { v.removeFromSuperview() }
        cells = []
        let step = Self.step
        let cell = Self.cellSize
        let rowPitch = cell.height + Self.gapY
        let t = Theme.current
        for (i, e) in model.results.enumerated() {
            let name = e.label.isEmpty ? e.name.capitalized : e.label
            let b = BubbleButton(glyph: e.display, caption: Self.shown(e.ewts), glyphSize: t.symbolsGlyphSize,
                                 tip: name, label: name) { [weak self] in
                self?.model.select(i)
                self?.insertSelected()
                self?.refresh()
            }
            b.inventory = .symbols
            b.translatesAutoresizingMaskIntoConstraints = true
            b.frame = NSRect(x: CGFloat(i % columns) * step, y: CGFloat(i / columns) * rowPitch,
                             width: cell.width, height: cell.height)
            b.filled = i == model.selected
            documentView.addSubview(b)
            cells.append(b)
        }
        let rows = (model.results.count + columns - 1) / columns
        let height = max(CGFloat(rows) * rowPitch - Self.gapY, 1)
        documentView.frame = NSRect(x: 0, y: 0, width: CGFloat(columns) * step, height: height)
        if cells.indices.contains(model.selected) { documentView.scrollToVisible(cells[model.selected].frame.insetBy(dx: 0, dy: -4)) }

        // One line on the selected symbol (or what was just done), one on the keys.
        var first = model.hint
        if first.isEmpty, let e = model.selectedEntry {
            let name = e.label.isEmpty ? e.name.capitalized : e.label
            first = name + (e.ewts.map { "  ·  type \(Self.shown($0))" } ?? "") + "  ·  " + e.codePoints
        }
        let text = NSMutableAttributedString(string: first, attributes: [
            .font: t.brutal ? t.serif(14) : NSFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: t.ink])
        text.append(NSAttributedString(string: "\nClick or Return inserts · arrows move · Tab: next panel · Esc closes", attributes: [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: t.brutal ? t.mutedText : t.ink.withAlphaComponent(0.7)]))
        hintLabel.attributedStringValue = text
        panel?.invalidateShadow()
    }

    // MARK: Position

    @objc private func panelMoved(_ note: Notification) {
        guard let panel = panel else { return }
        PanelTabs.save(panel, key: Self.originKey)
    }
}
