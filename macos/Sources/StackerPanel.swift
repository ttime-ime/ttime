import Cocoa

/// A pink, bubbly button. Layer-backed and borderless: a native bezel would draw
/// grey in this window, which never becomes key.
final class BubbleButton: NSButton {
    var onClick: (() -> Void)?
    var glyph = ""
    var caption = ""
    var glyphSize: CGFloat = 18
    /// The caption goes beside the glyph instead of under it (compact chips).
    var inlineCaption = false
    var filled = false { didSet { paint() } }

    convenience init(glyph: String, caption: String = "", glyphSize: CGFloat = 18, tip: String, label: String,
                     onClick: @escaping () -> Void) {
        self.init(frame: .zero)
        self.glyph = glyph
        self.caption = caption
        self.glyphSize = glyphSize
        self.onClick = onClick
        isBordered = false
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.borderWidth = 1.5
        toolTip = tip
        setAccessibilityLabel(label)
        target = self
        action = #selector(fire)
        translatesAutoresizingMaskIntoConstraints = false
        paint()
    }

    private var glyphLabel: NSTextField?
    private var captionLabel: NSTextField?

    private func ensureLabels() -> (NSTextField, NSTextField) {
        if let g = glyphLabel, let c = captionLabel { return (g, c) }
        let g = NSTextField(labelWithString: "")
        let c = NSTextField(labelWithString: "")
        for l in [g, c] {
            l.translatesAutoresizingMaskIntoConstraints = false
            addSubview(l)
            l.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
        }
        g.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -4).isActive = true
        c.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -3).isActive = true
        glyphLabel = g
        captionLabel = c
        return (g, c)
    }

    // The labels are only drawing; every click belongs to the button.
    override func hitTest(_ point: NSPoint) -> NSView? { frame.contains(point) ? self : nil }

    @objc private func fire() { onClick?() }
    override var acceptsFirstResponder: Bool { false }

    override var isEnabled: Bool {
        didSet { alphaValue = isEnabled ? 1 : 0.4 }
    }

    /// `soft`: the style's ordinary button. `tile`: a quiet filled pill (vowels,
    /// marks). `heading`: brutalist tabs, which are just serif words.
    enum Look { case soft, tile, heading }
    var look = Look.soft { didSet { paint() } }

    private var isCell: Bool { !caption.isEmpty && !inlineCaption }

    override func viewDidMoveToWindow() { paint() }
    override func viewDidChangeEffectiveAppearance() { paint() }

    override func layout() {
        super.layout()
        if Theme.current.brutal { layer?.cornerRadius = isCell ? 9 : min(bounds.height / 2, 16) }
    }

    func paint() {
        let t = Theme.current
        let ink: NSColor
        var captionFont = NSFont.monospacedSystemFont(ofSize: 9, weight: .medium)
        var labelFont: NSFont? = nil
        if t.brutal {
            ink = filled && look != .heading ? t.paper : t.ink
            layer?.cornerRadius = isCell ? 9 : min(max(bounds.height, 28) / 2, 16)
            switch look {
            case .heading:
                layer?.backgroundColor = NSColor.clear.cgColor
                layer?.borderWidth = 0
                labelFont = t.serif(20)
                alphaValue = filled ? 1 : 0.4
            case .tile:
                layer?.backgroundColor = resolved(filled ? t.ink : t.tile)
                layer?.borderWidth = 0
            case .soft:
                if filled {
                    layer?.backgroundColor = resolved(t.ink); layer?.borderWidth = 0
                } else if isCell {
                    layer?.backgroundColor = NSColor.clear.cgColor; layer?.borderWidth = 0
                } else {
                    layer?.backgroundColor = NSColor.clear.cgColor
                    layer?.borderWidth = 1; layer?.borderColor = resolved(t.line)
                }
            }
            captionFont = t.serif(11)
        } else {
            layer?.backgroundColor = (filled ? Toolbar.plum : Toolbar.cream.withAlphaComponent(0.85)).cgColor
            layer?.borderColor = (filled ? Toolbar.plum : StackerPanel.pinkStrong).cgColor
            ink = filled ? NSColor.white : Toolbar.plum
        }
        let font = TibetanFont.contains(glyph) ? TibetanFont.font(glyphSize)
            : labelFont ?? NSFont.systemFont(ofSize: glyphSize, weight: caption.isEmpty || inlineCaption ? .semibold : .regular)
        let para = NSMutableParagraphStyle()
        para.alignment = .center
        if caption.isEmpty || inlineCaption {
            // One line: an ordinary button title.
            let text = NSMutableAttributedString(string: glyph, attributes: [
                .font: font, .foregroundColor: ink, .paragraphStyle: para])
            if inlineCaption {
                text.append(NSAttributedString(string: "  " + caption, attributes: [
                    .font: captionFont,
                    .foregroundColor: ink.withAlphaComponent(0.75), .paragraphStyle: para]))
            }
            attributedTitle = text
            glyphLabel?.isHidden = true
            captionLabel?.isHidden = true
        } else {
            // A glyph over a key. Noto Serif Tibetan has tall line boxes that a
            // single title would push the caption out with, so each gets a label.
            attributedTitle = NSAttributedString(string: "")
            let g = ensureLabels()
            g.0.isHidden = false
            g.1.isHidden = false
            g.0.attributedStringValue = NSAttributedString(string: glyph, attributes: [
                .font: font, .foregroundColor: ink, .paragraphStyle: para])
            g.1.attributedStringValue = NSAttributedString(string: caption, attributes: [
                .font: captionFont,
                .foregroundColor: ink.withAlphaComponent(0.75), .paragraphStyle: para])
        }
        setAccessibilityValue(filled ? "selected" : "not selected")
    }
}

/// The stacker window: pink, bubbly, with the flatbread tower and the yak.
/// Choose letters top to bottom (click, or type their EWTS); the engine builds
/// the stack, and the window shows what to type for it next time.
///
/// Two layouts. Wide: the picture and the answer on the left, the letters on the
/// right. Compact (drag the corner grip narrower): one column, the picture and a
/// short answer on top, the letters below. Both hold the same views, rearranged.
///
/// A non-activating panel like the toolbar, so the document keeps focus and the
/// keys go through the input method (see `handle`).
final class StackerPanel: NSObject {
    static var shared = StackerPanel()

    /// Builds the window again in the current style, where it was.
    static func rebuild() {
        let old = shared
        let wasOpen = old.isOpen
        let tl = old.panel.map { PanelTabs.topLeft(of: $0) }
        old.pendingClose?.cancel()
        old.panel?.orderOut(nil)
        let new = StackerPanel()
        new.insert = old.insert
        shared = new
        if wasOpen { new.open(topLeft: tl) }
    }

    static let pink = NSColor(srgbRed: 0xFC / 255, green: 0xE7 / 255, blue: 0xE9 / 255, alpha: 1)
    static let pinkStrong = NSColor(srgbRed: 0xEA / 255, green: 0x87 / 255, blue: 0x98 / 255, alpha: 1)

    let model = StackerModel()
    /// Puts text into the focused document; set by the active controller.
    var insert: ((String) -> Void)?

    private static let originKey = "StackerTopLeft"
    private static let columnWidth: CGFloat = 264
    /// Dragged narrower than this, the window becomes one column.
    private static let singleColumnBelow: CGFloat = 620

    /// Height over width of the picture.
    private var artRatio: CGFloat { Theme.current.brutal ? 1024.0 / 1536 : 1050.0 / 960 }

    private var panel: NSPanel?
    private var pendingClose: DispatchWorkItem?
    private var compact = false

    private var cells: [String: BubbleButton] = [:]
    private var vowelButtons: [String: BubbleButton] = [:]
    private var markButtons: [String: BubbleButton] = [:]
    private let layersRow = NSStackView()
    private let emptyHint = NSTextField(labelWithString: "Click letters below, or type them: top to bottom.")
    private let typedLabel = NSTextField(labelWithString: "")
    private let preview = NSTextField(labelWithString: "")
    private let shortestLabel = NSTextField(labelWithString: "")
    private let canonicalLabel = NSTextField(labelWithString: "")
    private let codesLabel = NSTextField(wrappingLabelWithString: "")
    private let notesLabel = NSTextField(wrappingLabelWithString: "")
    private let hintLabel = NSTextField(wrappingLabelWithString: "")
    private var typeRowView: NSView?
    private var insertButton: BubbleButton!
    private var copyButton: BubbleButton!
    private var clearButton: BubbleButton!

    // The parts the two layouts share, and the constraints that differ.
    private var container: DraggableView!
    private let root = NSStackView()
    private let leftColumn = NSStackView()
    private let rightColumn = NSStackView()
    private let topRow = NSStackView()
    private let typedRow = NSStackView()  // compact: what you are typing, and the hint
    private var header: NSStackView!
    private let tagline = NSTextField(labelWithString: "Stack up Sanskrit letters.")
    private var layersBox: NSView!
    private let flexible = NSView()
    private var art: NSImageView!
    private var card: NSView!
    private let cardStack = NSStackView()
    private var previewRow: NSStackView!
    private var buttonsRow: NSStackView!
    private var presetLabel: NSTextField!
    private var presetButtons: [BubbleButton] = []
    private var presetLines: [NSStackView] = []
    private let presetsWide = NSStackView()
    private let presetsCompact = NSStackView()
    private let presetChips = NSStackView()
    private var grid: NSStackView!
    private var vowelSection: NSView!
    private var marksSection: NSView!
    private var artWidth: NSLayoutConstraint!
    private var artHeight: NSLayoutConstraint!
    private var cardWidth: NSLayoutConstraint!
    private var cardMinHeight: NSLayoutConstraint!
    private var headerWidth: NSLayoutConstraint!
    private var typedRowWidth: NSLayoutConstraint!
    private var previewRowWidth: NSLayoutConstraint!
    private var cellHeights: [NSLayoutConstraint] = []
    private var presetHeights: [NSLayoutConstraint] = []
    private var wideOnly: [NSLayoutConstraint] = []     // controls that fill the card
    private var compactOnly: [NSLayoutConstraint] = []  // controls in the footer

    var isOpen: Bool { panel?.isVisible ?? false }
    /// The panel's content, for rendering without showing it.
    var contentView: NSView? { ensurePanel().contentView }

    // MARK: Showing

    func open(topLeft: NSPoint? = nil) {
        model.precomposed = Prefs.precomposed
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

    /// Closes shortly after the document loses focus; moving between fields
    /// sends a deactivate then an activate, and `cancelClose` cancels it.
    func scheduleClose() {
        guard isOpen else { return }
        pendingClose?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.panel?.orderOut(nil) }
        pendingClose = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    func cancelClose() { pendingClose?.cancel() }

    // MARK: Keys

    /// Keys while the window is open: letters are typed into the stacker, not the
    /// document. Returns whether the key was used (otherwise the app gets it).
    func handle(_ key: KeyInput) -> Bool {
        guard isOpen else { return false }
        switch key {
        case .escape:
            close()
            return true
        case .enter:
            if !model.typed.isEmpty { model.confirmTyped() } else if model.built != nil { insertBuilt() } else { return false }
        case .backspace:
            guard model.backspace() else { return false }
        case .text(let s):
            if s == " " || s == "+" {
                if model.typed.isEmpty { return s == "+" }
                model.confirmTyped()
            } else {
                model.type(s)
            }
        case .tab:
            PanelTabs.cycle(from: .stacker, panel: panel)
            return true
        default:
            return false
        }
        refresh()
        return true
    }

    private func insertBuilt() {
        guard let b = model.consume() else { return }
        insert?(b.text)
    }

    // MARK: Building

    private func ensurePanel() -> NSPanel {
        if let panel = panel { return panel }
        compact = PanelTabs.compact
        let alphabet = model.alphabet

        // The illustration, dominant when wide, smaller on top when compact.
        art = NSImageView()
        if let url = Bundle.main.url(forResource: Theme.current.brutal ? "brutal-art" : "stacker-art", withExtension: "webp") {
            art.image = NSImage(contentsOf: url)
        }
        art.imageScaling = .scaleProportionallyUpOrDown
        art.setAccessibilityLabel("A cat-maid carrying a tower of flatbreads, and a yak with books")
        art.translatesAutoresizingMaskIntoConstraints = false
        artWidth = art.widthAnchor.constraint(equalToConstant: Self.columnWidth)
        artHeight = art.heightAnchor.constraint(equalToConstant: Self.columnWidth * artRatio)
        NSLayoutConstraint.activate([artWidth, artHeight])

        card = resultCard()

        // The tabs, the tagline and the close button.
        let tabs = PanelTabs.makeBar(selected: .stacker) { [weak self] in self?.panel }
        tagline.font = Theme.current.brutal ? Theme.current.serif(13, italic: true) : NSFont.systemFont(ofSize: 12, weight: .medium)
        tagline.textColor = Theme.current.ink.withAlphaComponent(0.7)
        let spacer = NSView()
        let closeButton = BubbleButton(glyph: "✕", glyphSize: 13, tip: "Close (Esc)", label: "Close") { [weak self] in
            self?.close()
        }
        closeButton.widthAnchor.constraint(equalToConstant: 30).isActive = true
        closeButton.heightAnchor.constraint(equalToConstant: 30).isActive = true
        if Theme.current.brutal {
            let title = NSTextField(labelWithString: "T-Time")
            title.font = Theme.current.serif(30)
            title.textColor = Theme.current.ink
            tagline.font = Theme.current.serif(12, italic: true)
            let block = NSStackView(views: [title, tagline])
            block.orientation = .vertical
            block.alignment = .leading
            block.spacing = 0
            let rule = RuleView(vertical: true)
            rule.heightAnchor.constraint(equalToConstant: 38).isActive = true
            header = NSStackView(views: [block, rule, tabs, spacer, closeButton])
        } else {
            header = NSStackView(views: [tabs, tagline, spacer, closeButton])
        }
        header.alignment = .centerY
        header.spacing = 10
        spacer.setContentHuggingPriority(.init(1), for: .horizontal)
        headerWidth = header.widthAnchor.constraint(equalToConstant: 100)
        headerWidth.isActive = true
        typedRowWidth = typedRow.widthAnchor.constraint(equalToConstant: 100)
        typedRowWidth.isActive = true

        // The chosen letters are drawn the way the stack is: one above the other,
        // first letter on top. The column lives in the answer card (resultCard).
        layersRow.orientation = .vertical
        layersRow.spacing = 3
        layersRow.alignment = .centerX
        emptyHint.stringValue = "Add letters top to bottom: the first goes on top."
        emptyHint.font = NSFont.systemFont(ofSize: 12)
        emptyHint.textColor = Theme.current.ink.withAlphaComponent(0.7)
        layersBox = NSView()
        layersBox.translatesAutoresizingMaskIntoConstraints = false
        layersBox.heightAnchor.constraint(equalToConstant: 20).isActive = true
        for v in [emptyHint] {
            v.translatesAutoresizingMaskIntoConstraints = false
            layersBox.addSubview(v)
            v.leadingAnchor.constraint(equalTo: layersBox.leadingAnchor).isActive = true
            v.centerYAnchor.constraint(equalTo: layersBox.centerYAnchor).isActive = true
        }

        typedLabel.font = Theme.current.brutal ? Theme.current.serif(15) : NSFont.monospacedSystemFont(ofSize: 13, weight: .semibold)
        typedLabel.textColor = Theme.current.ink

        grid = NSStackView()
        grid.orientation = .vertical
        grid.alignment = .leading
        grid.spacing = 5
        let known = Set(alphabet.consonants.map(\.key))
        let example = Dictionary(uniqueKeysWithValues: (alphabet.consonants + alphabet.subjoinedOnly).map { ($0.key, $0.example) })
        var rows: [(String, [String])] = Self.rows.map { ($0.0, $0.1.filter { known.contains($0) }) }
        let placed = Set(Self.rows.flatMap(\.1))
        let rest = alphabet.consonants.map(\.key).filter { !placed.contains($0) }
        if !rest.isEmpty { rows.append(("More", rest)) }
        rows.append(("Under a letter", alphabet.subjoinedOnly.map(\.key)))
        for (name, keys) in rows where !keys.isEmpty {
            let label = Theme.current.railLabel(name, width: 82)
            var buttons: [NSView] = [label]
            for key in keys {
                let b = BubbleButton(glyph: example[key] ?? key, caption: key, glyphSize: 15,
                                     tip: "Add \(key)", label: "Add \(key)") { [weak self] in
                    self?.model.addLayer(key)
                    self?.refresh()
                }
                b.widthAnchor.constraint(equalToConstant: 38).isActive = true
                let h = b.heightAnchor.constraint(equalToConstant: 38)
                h.isActive = true
                cellHeights.append(h)
                cells[key] = b
                buttons.append(b)
            }
            let line = NSStackView(views: buttons)
            line.spacing = 4
            grid.addArrangedSubview(line)
        }

        let vowelOrder = ["i", "I", "u", "U", "e", "o", "ai", "au", "A", "-i", "-I", "ui", "ue", "uo"]
        let rank = { (k: String) in vowelOrder.firstIndex(of: k) ?? vowelOrder.count }
        var vowelRow: [NSView] = []
        let inherent = BubbleButton(glyph: "a", glyphSize: 14, tip: "Inherent vowel a (no sign)", label: "Vowel a") { [weak self] in
            self?.model.setVowel("")
            self?.refresh()
        }
        vowelButtons[""] = inherent
        vowelRow.append(inherent)
        for v in alphabet.vowels.sorted(by: { rank($0.key) < rank($1.key) }) {
            let b = BubbleButton(glyph: v.example, caption: v.key, glyphSize: 15, tip: "Vowel \(v.key)", label: "Vowel \(v.key)") { [weak self] in
                self?.model.setVowel(v.key)
                self?.refresh()
            }
            vowelButtons[v.key] = b
            vowelRow.append(b)
        }
        var markRow: [NSView] = []
        for m in alphabet.marks {
            let b = BubbleButton(glyph: m.example, caption: m.key, glyphSize: 15, tip: "Mark \(m.key)", label: "Mark \(m.key)") { [weak self] in
                self?.model.toggleMark(m.key)
                self?.refresh()
            }
            markButtons[m.key] = b
            markRow.append(b)
        }
        for b in (vowelRow + markRow) {
            (b as? BubbleButton)?.look = .tile
            b.widthAnchor.constraint(greaterThanOrEqualToConstant: 34).isActive = true
            b.heightAnchor.constraint(equalToConstant: 34).isActive = true
        }
        vowelSection = section("Vowel", vowelRow, perRow: 8)
        marksSection = section("Marks", markRow, perRow: 9)

        leftColumn.orientation = .vertical
        leftColumn.alignment = .centerX
        leftColumn.spacing = 10
        rightColumn.orientation = .vertical
        rightColumn.alignment = .leading
        rightColumn.spacing = 9
        flexible.setContentHuggingPriority(.init(1), for: .vertical)
        flexible.setContentCompressionResistancePriority(.init(1), for: .vertical)
        topRow.orientation = .horizontal
        topRow.alignment = .top
        topRow.spacing = 12
        typedRow.orientation = .horizontal
        typedRow.alignment = .firstBaseline
        typedRow.spacing = 10

        root.edgeInsets = NSEdgeInsets(top: 18, left: 20, bottom: 20, right: 22)
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
        panel.appearance = Theme.current.appearance
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.setAccessibilityLabel("T-Time stacker")
        for name in [NSWindow.didMoveNotification, NSWindow.didResizeNotification] {
            NotificationCenter.default.addObserver(self, selector: #selector(panelMoved), name: name, object: panel)
        }
        self.panel = panel
        refresh()
        return panel
    }

    private static let rows: [(String, [String])] = [
        ("Velar", ["k", "kh", "g", "gh", "ng"]), ("Palatal", ["c", "ch", "j", "dzh", "ny"]),
        ("Retroflex", ["T", "Th", "D", "Dh", "N"]), ("Dental", ["t", "th", "d", "dh", "n"]),
        ("Labial", ["p", "ph", "b", "bh", "m"]), ("Affricate, w, z", ["ts", "tsh", "dz", "w", "zh", "z"]),
        ("Others", ["'", "y", "r", "l", "sh", "Sh", "s", "h"]), ("Special", ["f", "v", "R"]),
    ]

    private func section(_ name: String, _ items: [NSView], perRow: Int) -> NSView {
        let label = Theme.current.railLabel(name, width: 82)
        let lines = stride(from: 0, to: items.count, by: perRow).map { i -> NSView in
            let s = NSStackView(views: Array(items[i..<min(i + perRow, items.count)]))
            s.spacing = 4
            return s
        }
        let column = NSStackView(views: lines)
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = 4
        let row = NSStackView(views: [label, column])
        row.alignment = .top
        return row
    }

    /// The answer card. Its contents are arranged by `applyLayout`: all of them
    /// when wide, just the glyph and what to type when compact.
    private func resultCard() -> NSView {
        preview.font = TibetanFont.font(46)
        preview.textColor = Theme.current.ink
        preview.alignment = .center
        preview.lineBreakMode = .byTruncatingTail
        shortestLabel.font = NSFont.monospacedSystemFont(ofSize: 17, weight: .bold)
        shortestLabel.textColor = Theme.current.ink
        canonicalLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        canonicalLabel.textColor = Theme.current.ink.withAlphaComponent(0.8)
        for l in [codesLabel, notesLabel] {
            l.preferredMaxLayoutWidth = Self.columnWidth - 24
        }
        codesLabel.font = NSFont.monospacedSystemFont(ofSize: 9.5, weight: .regular)
        codesLabel.textColor = Theme.current.ink.withAlphaComponent(0.7)
        notesLabel.font = NSFont.systemFont(ofSize: 10.5)
        notesLabel.textColor = Theme.current.ink.withAlphaComponent(0.85)
        hintLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        hintLabel.textColor = Theme.current.ink
        hintLabel.preferredMaxLayoutWidth = Self.columnWidth - 24

        insertButton = BubbleButton(glyph: "Insert  ⏎", glyphSize: 13, tip: "Put it in the document (Return)", label: "Insert") { [weak self] in
            self?.insertBuilt()
            self?.refresh()
        }
        insertButton.filled = true
        copyButton = BubbleButton(glyph: "Copy", glyphSize: 13, tip: "Copy the stack", label: "Copy") { [weak self] in
            guard let b = self?.model.built else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(b.text, forType: .string)
            self?.model.setHint("Copied \(b.text).")
            self?.refresh()
        }
        clearButton = BubbleButton(glyph: "Clear", glyphSize: 13, tip: "Start over", label: "Clear") { [weak self] in
            self?.model.clear()
            self?.refresh()
        }
        buttonsRow = NSStackView(views: [insertButton, copyButton, clearButton])
        buttonsRow.distribution = .fillEqually
        buttonsRow.spacing = 6
        for (b, w) in zip([insertButton!, copyButton!, clearButton!], [104, 104, 104] as [CGFloat]) {
            b.heightAnchor.constraint(equalToConstant: 32).isActive = true
            let c = b.widthAnchor.constraint(equalToConstant: w)
            compactOnly.append(c)
        }
        let inner = Self.columnWidth - 24
        let buttonsFill = buttonsRow.widthAnchor.constraint(equalToConstant: inner)
        wideOnly.append(buttonsFill)

        // "Start from" chips: two lines of four when wide, one line when compact.
        presetLabel = label("Start from", 10)
        for p in StackerModel.presets {
            let b = BubbleButton(glyph: p.label, glyphSize: 12, tip: "Start from \(p.label)", label: "Start from \(p.label)") { [weak self] in
                self?.model.usePreset(p.letters)
                self?.refresh()
            }
            let h = b.heightAnchor.constraint(equalToConstant: 30)
            h.isActive = true
            presetHeights.append(h)
            presetButtons.append(b)
        }
        for _ in stride(from: 0, to: presetButtons.count, by: 4) {
            let s = NSStackView()
            s.distribution = .fillEqually
            s.spacing = 4
            presetLines.append(s)
            wideOnly.append(s.widthAnchor.constraint(equalToConstant: inner))
        }
        presetsWide.orientation = .vertical
        presetsWide.alignment = .leading
        presetsWide.spacing = 4
        wideOnly.append(presetsWide.widthAnchor.constraint(equalToConstant: inner))
        presetChips.distribution = .fillEqually
        presetChips.spacing = 4
        presetsCompact.orientation = .horizontal
        presetsCompact.alignment = .centerY
        presetsCompact.spacing = 8

        let typeRow = NSStackView(views: [label("type", 10), shortestLabel])
        typeRow.setContentHuggingPriority(.required, for: .horizontal)
        typeRowView = typeRow
        typeRow.alignment = .lastBaseline
        typeRow.spacing = 6
        previewRow = NSStackView(views: [layersRow, preview])
        previewRow.orientation = .horizontal
        previewRow.alignment = .top
        previewRow.spacing = 6
        layersRow.setContentHuggingPriority(.required, for: .horizontal)
        preview.setContentHuggingPriority(.init(1), for: .horizontal)
        previewRowWidth = previewRow.widthAnchor.constraint(equalToConstant: inner)
        previewRowWidth.isActive = true

        cardStack.orientation = .vertical
        cardStack.alignment = .centerX
        cardStack.spacing = 4
        cardStack.edgeInsets = NSEdgeInsets(top: 10, left: 12, bottom: 12, right: 12)
        cardStack.translatesAutoresizingMaskIntoConstraints = false

        let box = NSView()
        box.wantsLayer = true
        box.layer?.backgroundColor = Theme.current.brutal ? NSColor.clear.cgColor : NSColor.white.withAlphaComponent(0.7).cgColor
        box.layer?.cornerRadius = Theme.current.brutal ? 0 : 20
        box.layer?.borderWidth = Theme.current.brutal ? 0 : 2
        box.layer?.borderColor = Self.pinkStrong.cgColor
        box.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(cardStack)
        cardWidth = box.widthAnchor.constraint(equalToConstant: Self.columnWidth)
        cardMinHeight = box.heightAnchor.constraint(greaterThanOrEqualToConstant: 250)
        NSLayoutConstraint.activate([
            cardWidth, cardMinHeight,
            cardStack.leadingAnchor.constraint(equalTo: box.leadingAnchor),
            cardStack.trailingAnchor.constraint(equalTo: box.trailingAnchor),
            cardStack.topAnchor.constraint(equalTo: box.topAnchor),
            cardStack.bottomAnchor.constraint(equalTo: box.bottomAnchor),
        ])
        return box
    }

    private func label(_ s: String, _ size: CGFloat) -> NSTextField {
        let l = NSTextField(labelWithString: s)
        l.font = NSFont.systemFont(ofSize: size, weight: .semibold)
        l.textColor = Theme.current.ink.withAlphaComponent(0.75)
        return l
    }

    // MARK: One column or two

    /// Arranges the shared views for `compact`. Views move between stacks; the
    /// constraints that tie them to a neighbour are all constants, so nothing is
    /// lost on the way.
    private func applyLayout() {
        let c = compact
        // The one-column width is that of the widest block of letters.
        let contentWidth = ceil(max(grid.fittingSize.width, vowelSection.fittingSize.width, marksSection.fittingSize.width))
        headerWidth.constant = contentWidth
        typedRowWidth.constant = contentWidth

        let artW: CGFloat = c ? 146 : Self.columnWidth
        artWidth.constant = artW
        artHeight.constant = (artW * artRatio).rounded()
        cardWidth.constant = c ? contentWidth - artW - 104 - 2 * topRow.spacing : Self.columnWidth
        cardMinHeight.constant = c ? artHeight.constant : 250
        previewRowWidth.constant = cardWidth.constant - 24
        wideOnly.forEach { $0.isActive = !c }
        compactOnly.forEach { $0.isActive = c }
        cellHeights.forEach { $0.constant = c ? 34 : 38 }
        presetHeights.forEach { $0.constant = c ? 26 : 30 }
        for b in presetButtons { b.glyphSize = c ? 11 : 12; b.paint() }
        preview.font = TibetanFont.font(c ? 40 : 46)
        layersRow.spacing = c ? 2 : 3
        tagline.isHidden = c && !Theme.current.brutal
        // Compact: the buttons stand in a column beside the answer.
        buttonsRow.orientation = c ? .vertical : .horizontal
        buttonsRow.distribution = c ? .fill : .fillEqually
        hintLabel.preferredMaxLayoutWidth = c ? contentWidth - 100 : Self.columnWidth - 24
        hintLabel.maximumNumberOfLines = c ? 1 : 0
        hintLabel.lineBreakMode = c ? .byTruncatingTail : .byWordWrapping
        hintLabel.setContentCompressionResistancePriority(c ? .init(250) : .defaultHigh, for: .horizontal)

        if c {
            presetChips.arrange(presetButtons)
            presetsCompact.arrange([presetLabel, presetChips])
            for line in presetLines { line.arrange([]) }
            presetsWide.arrange([])
            typedRow.arrange([typedLabel, hintLabel])
            cardStack.arrange([previewRow, typeRowView!])
            root.arrange([header, topRow, typedRow, presetsCompact, grid, vowelSection, marksSection])
            topRow.arrange([art, card, buttonsRow])
            leftColumn.arrange([])
            rightColumn.arrange([])
            root.orientation = .vertical
            root.alignment = .leading
            root.spacing = 9
        } else {
            for (i, line) in presetLines.enumerated() {
                line.arrange(Array(presetButtons[i * 4..<min(i * 4 + 4, presetButtons.count)]))
            }
            presetsWide.arrange([presetLabel] + presetLines)
            presetChips.arrange([])
            presetsCompact.arrange([])
            cardStack.arrange([previewRow, typeRowView!, canonicalLabel, codesLabel, notesLabel, hintLabel, buttonsRow, presetsWide])
            cardStack.setCustomSpacing(10, after: hintLabel)
            cardStack.setCustomSpacing(12, after: buttonsRow)
            typedRow.arrange([])
            leftColumn.arrange([art, card])
            rightColumn.arrange([header, layersBox, typedLabel, grid, vowelSection, marksSection, flexible])
            rightColumn.setCustomSpacing(4, after: layersBox)
            topRow.arrange([])
            root.arrange([leftColumn, rightColumn])
            root.orientation = .horizontal
            root.alignment = .top
            root.spacing = 20
        }
    }

    private func setCompact(_ c: Bool) {
        guard c != compact else { return }
        compact = c
        PanelTabs.compact = c
        applyLayout()
        refresh()
    }

    /// The size the window takes for a drag to `wanted`: one of two, because the
    /// letters have a fixed size. The grip calls this as the mouse moves.
    private func proposedSize(_ wanted: NSSize) -> NSSize {
        setCompact(wanted.width < Self.singleColumnBelow)
        return container.fittingSize
    }

    // MARK: Drawing the state

    func refresh() {
        guard panel != nil else { return }
        // Chosen letters, top to bottom; clicking one removes it.
        for v in layersRow.arrangedSubviews { layersRow.removeArrangedSubview(v); v.removeFromSuperview() }
        let example = Dictionary(uniqueKeysWithValues: (model.alphabet.consonants + model.alphabet.subjoinedOnly).map { ($0.key, $0.example) })
        for (i, key) in model.layers.enumerated() {
            let b = BubbleButton(glyph: example[key] ?? key, caption: key, glyphSize: compact ? 15 : 17,
                                 tip: "Remove \(key)", label: "Remove \(key), position \(i + 1)") { [weak self] in
                self?.model.removeLayer(at: i)
                self?.refresh()
            }
            b.filled = true
            b.inlineCaption = true
            b.paint()
            b.widthAnchor.constraint(equalToConstant: compact ? 58 : 66).isActive = true
            b.heightAnchor.constraint(equalToConstant: compact ? 22 : 30).isActive = true
            layersRow.addArrangedSubview(b)
        }
        layersRow.isHidden = model.layers.isEmpty
        typedLabel.stringValue = model.typed.isEmpty ? " " : "typing: \(model.typed)▏"

        for (key, b) in cells {
            b.isEnabled = !(model.alphabet.subjoinedOnly.contains { $0.key == key } && model.layers.isEmpty)
            b.alphaValue = !b.isEnabled ? 0.4 : (model.matches(key) ? 1 : 0.25)
            b.filled = model.typedKey == key
        }
        for (v, b) in vowelButtons { b.filled = v == model.vowel }
        for (m, b) in markButtons { b.filled = model.marks.contains(m) }

        var shortest = "", canonical = "", codes = "", notes = "", shown = ""
        switch model.result {
        case .empty:
            shown = "ཀྵ"
            preview.textColor = Theme.current.ink.withAlphaComponent(0.25)
        case .built(let b):
            shown = b.text; shortest = b.shortest
            canonical = b.shortest == b.canonical ? "" : "full: \(b.canonical)"
            codes = b.codePoints
            notes = b.notes.prefix(2).joined(separator: "\n")
            preview.textColor = Theme.current.ink
        case .failed(let why):
            shown = "∅"; notes = why
            preview.textColor = Theme.current.ink.withAlphaComponent(0.25)
        }
        preview.stringValue = shown
        shortestLabel.stringValue = shortest
        canonicalLabel.stringValue = canonical
        codesLabel.stringValue = codes
        notesLabel.stringValue = notes
        let hint = model.hint.isEmpty && model.result == .empty
            ? "Type a letter, Space adds it, Return inserts, Esc closes." : model.hint
        // Compact has no room for the notes in the card: a warning takes the hint's place.
        hintLabel.stringValue = compact && !notes.isEmpty ? notes.replacingOccurrences(of: "\n", with: " ") : hint
        hintLabel.toolTip = hintLabel.stringValue
        for l in [canonicalLabel, codesLabel, notesLabel] { l.isHidden = l.stringValue.isEmpty }
        typeRowView?.isHidden = shortest.isEmpty
        insertButton.isEnabled = model.built != nil
        copyButton.isEnabled = model.built != nil
        clearButton.isEnabled = !(model.layers.isEmpty && model.vowel.isEmpty && model.marks.isEmpty)
        panel?.invalidateShadow()
    }

    // MARK: Position

    @objc private func panelMoved(_ note: Notification) {
        guard let panel = panel else { return }
        PanelTabs.save(panel, key: Self.originKey)
    }
}
