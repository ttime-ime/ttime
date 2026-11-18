import Cocoa

/// A pink, bubbly button. Layer-backed and borderless: a native bezel would draw
/// grey in this window, which never becomes key.
final class BubbleButton: NSButton {
    var onClick: (() -> Void)?
    var glyph = ""
    var caption = ""
    var glyphSize: CGFloat = 18
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

    @objc private func fire() { onClick?() }
    override var acceptsFirstResponder: Bool { false }

    override var isEnabled: Bool {
        didSet { alphaValue = isEnabled ? 1 : 0.4 }
    }

    func paint() {
        layer?.backgroundColor = (filled ? Toolbar.plum : Toolbar.cream.withAlphaComponent(0.85)).cgColor
        layer?.borderColor = (filled ? Toolbar.plum : StackerPanel.pinkStrong).cgColor
        let ink = filled ? NSColor.white : Toolbar.plum
        let para = NSMutableParagraphStyle()
        para.alignment = .center
        let text = NSMutableAttributedString(string: glyph, attributes: [
            .font: NSFont.systemFont(ofSize: glyphSize, weight: caption.isEmpty ? .semibold : .regular),
            .foregroundColor: ink, .paragraphStyle: para,
        ])
        if !caption.isEmpty {
            text.append(NSAttributedString(string: "\n" + caption, attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 9, weight: .medium),
                .foregroundColor: ink.withAlphaComponent(0.75), .paragraphStyle: para,
            ]))
        }
        attributedTitle = text
        setAccessibilityValue(filled ? "selected" : "not selected")
    }
}

/// The stacker window: pink, bubbly, with the flatbread tower and the yak.
/// Choose letters top to bottom (click, or type their EWTS); the engine builds
/// the stack, and the window shows what to type for it next time.
///
/// A non-activating panel like the toolbar, so the document keeps focus and the
/// keys go through the input method (see `handle`).
final class StackerPanel: NSObject {
    static let shared = StackerPanel()

    static let pink = NSColor(srgbRed: 0xFC / 255, green: 0xE7 / 255, blue: 0xE9 / 255, alpha: 1)
    static let pinkStrong = NSColor(srgbRed: 0xEA / 255, green: 0x87 / 255, blue: 0x98 / 255, alpha: 1)

    let model = StackerModel()
    /// Puts text into the focused document; set by the active controller.
    var insert: ((String) -> Void)?

    private static let originKey = "StackerOrigin"
    private static let columnWidth: CGFloat = 264

    private var panel: NSPanel?
    private var pendingClose: DispatchWorkItem?

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

    var isOpen: Bool { panel?.isVisible ?? false }
    /// The panel's content, for rendering without showing it.
    var contentView: NSView? { ensurePanel().contentView }

    // MARK: Showing

    /// Tab: the symbols window takes over, in the same place.
    private func switchToSymbols() {
        let center = panel.map { NSPoint(x: $0.frame.midX, y: $0.frame.midY) }
        close()
        SymbolsPanel.shared.open(centeredOn: center)
    }

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
            switchToSymbols()
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
        let alphabet = model.alphabet

        // Left: the illustration, dominant, and the answer under it.
        let art = NSImageView()
        if let url = Bundle.main.url(forResource: "stacker-art", withExtension: "webp") {
            art.image = NSImage(contentsOf: url)
        }
        art.imageScaling = .scaleProportionallyUpOrDown
        art.setAccessibilityLabel("A cat-maid carrying a tower of flatbreads, and a yak with books")
        art.translatesAutoresizingMaskIntoConstraints = false
        art.widthAnchor.constraint(equalToConstant: Self.columnWidth).isActive = true
        art.heightAnchor.constraint(equalToConstant: Self.columnWidth * 1050 / 960).isActive = true

        let card = resultCard()
        let left = NSStackView(views: [art, card])
        left.orientation = .vertical
        left.alignment = .centerX
        left.spacing = 10

        // Right: layers, typing, letter grid, vowels, marks, presets.
        let title = NSTextField(labelWithString: "Stacker")
        title.font = NSFont.systemFont(ofSize: 24, weight: .heavy)
        title.textColor = Toolbar.plum
        let tagline = NSTextField(labelWithString: "stack up Sanskrit letters")
        tagline.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        tagline.textColor = Toolbar.plum.withAlphaComponent(0.7)
        let spacer = NSView()
        let closeButton = BubbleButton(glyph: "✕", glyphSize: 13, tip: "Close (Esc)", label: "Close") { [weak self] in
            self?.close()
        }
        closeButton.widthAnchor.constraint(equalToConstant: 30).isActive = true
        closeButton.heightAnchor.constraint(equalToConstant: 30).isActive = true
        let header = NSStackView(views: [title, tagline, spacer, closeButton])
        header.alignment = .lastBaseline
        header.spacing = 8
        header.setHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentHuggingPriority(.init(1), for: .horizontal)

        layersRow.orientation = .horizontal
        layersRow.spacing = 6
        layersRow.alignment = .centerY
        emptyHint.font = NSFont.systemFont(ofSize: 12)
        emptyHint.textColor = Toolbar.plum.withAlphaComponent(0.7)
        let layersBox = NSView()
        layersBox.translatesAutoresizingMaskIntoConstraints = false
        layersBox.heightAnchor.constraint(equalToConstant: 52).isActive = true
        for v in [layersRow, emptyHint] {
            v.translatesAutoresizingMaskIntoConstraints = false
            layersBox.addSubview(v)
            v.leadingAnchor.constraint(equalTo: layersBox.leadingAnchor).isActive = true
            v.centerYAnchor.constraint(equalTo: layersBox.centerYAnchor).isActive = true
        }

        typedLabel.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .semibold)
        typedLabel.textColor = Toolbar.plum

        let grid = NSStackView()
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
            let label = NSTextField(labelWithString: name)
            label.font = NSFont.systemFont(ofSize: 10, weight: .semibold)
            label.textColor = Toolbar.plum.withAlphaComponent(0.75)
            label.translatesAutoresizingMaskIntoConstraints = false
            label.widthAnchor.constraint(equalToConstant: 82).isActive = true
            var buttons: [NSView] = [label]
            for key in keys {
                let b = BubbleButton(glyph: example[key] ?? key, caption: key, glyphSize: 17,
                                     tip: "Add \(key)", label: "Add \(key)") { [weak self] in
                    self?.model.addLayer(key)
                    self?.refresh()
                }
                b.widthAnchor.constraint(equalToConstant: 38).isActive = true
                b.heightAnchor.constraint(equalToConstant: 38).isActive = true
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
            b.widthAnchor.constraint(greaterThanOrEqualToConstant: 34).isActive = true
            b.heightAnchor.constraint(equalToConstant: 34).isActive = true
        }

        let right = NSStackView(views: [
            header, layersBox, typedLabel, grid,
            section("Vowel", vowelRow, perRow: 8), section("Marks", markRow, perRow: 9),
        ])
        right.orientation = .vertical
        right.alignment = .leading
        right.spacing = 9
        right.setCustomSpacing(4, after: layersBox)

        let root = NSStackView(views: [left, right])
        root.orientation = .horizontal
        root.alignment = .top
        root.spacing = 20
        root.edgeInsets = NSEdgeInsets(top: 18, left: 20, bottom: 20, right: 22)
        root.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = Self.pink.cgColor
        container.layer?.cornerRadius = 28
        container.layer?.borderWidth = 3
        container.layer?.borderColor = Self.pinkStrong.cgColor
        container.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            root.topAnchor.constraint(equalTo: container.topAnchor),
            root.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            root.bottomAnchor.constraint(equalTo: container.bottomAnchor),
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
        panel.setAccessibilityLabel("T-Time stacker")
        NotificationCenter.default.addObserver(self, selector: #selector(panelMoved),
                                               name: NSWindow.didMoveNotification, object: panel)
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
        let label = NSTextField(labelWithString: name)
        label.font = NSFont.systemFont(ofSize: 10, weight: .semibold)
        label.textColor = Toolbar.plum.withAlphaComponent(0.75)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(equalToConstant: 82).isActive = true
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

    private func resultCard() -> NSView {
        preview.font = NSFont.systemFont(ofSize: 56)
        preview.textColor = Toolbar.plum
        preview.alignment = .center
        preview.lineBreakMode = .byTruncatingTail
        shortestLabel.font = NSFont.monospacedSystemFont(ofSize: 17, weight: .bold)
        shortestLabel.textColor = Toolbar.plum
        canonicalLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        canonicalLabel.textColor = Toolbar.plum.withAlphaComponent(0.8)
        for l in [codesLabel, notesLabel, hintLabel] {
            l.preferredMaxLayoutWidth = Self.columnWidth - 24
        }
        codesLabel.font = NSFont.monospacedSystemFont(ofSize: 9.5, weight: .regular)
        codesLabel.textColor = Toolbar.plum.withAlphaComponent(0.7)
        notesLabel.font = NSFont.systemFont(ofSize: 10.5)
        notesLabel.textColor = Toolbar.plum.withAlphaComponent(0.85)
        hintLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        hintLabel.textColor = Toolbar.plum

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
        let buttons = NSStackView(views: [insertButton, copyButton, clearButton])
        buttons.distribution = .fillEqually
        buttons.spacing = 6
        for b in [insertButton!, copyButton!, clearButton!] {
            b.heightAnchor.constraint(equalToConstant: 32).isActive = true
        }

        var presetRow: [NSView] = []
        for p in StackerModel.presets {
            let b = BubbleButton(glyph: p.label, glyphSize: 12, tip: "Start from \(p.label)", label: "Start from \(p.label)") { [weak self] in
                self?.model.usePreset(p.letters)
                self?.refresh()
            }
            b.heightAnchor.constraint(equalToConstant: 30).isActive = true
            presetRow.append(b)
        }
        let presetLines = stride(from: 0, to: presetRow.count, by: 4).map { i -> NSView in
            let s = NSStackView(views: Array(presetRow[i..<min(i + 4, presetRow.count)]))
            s.distribution = .fillEqually
            s.spacing = 4
            return s
        }
        let presets = NSStackView(views: [label("Start from", 10)] + presetLines)
        presets.orientation = .vertical
        presets.alignment = .leading
        presets.spacing = 4

        let typeRow = NSStackView(views: [label("type", 10), shortestLabel])
        typeRow.setContentHuggingPriority(.required, for: .horizontal)
        typeRowView = typeRow
        typeRow.alignment = .lastBaseline
        typeRow.spacing = 6
        let stack = NSStackView(views: [preview, typeRow, canonicalLabel, codesLabel, notesLabel, hintLabel, buttons, presets])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 4
        stack.setCustomSpacing(10, after: hintLabel)
        stack.setCustomSpacing(12, after: buttons)
        stack.edgeInsets = NSEdgeInsets(top: 10, left: 12, bottom: 12, right: 12)
        stack.translatesAutoresizingMaskIntoConstraints = false
        buttons.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -24).isActive = true
        presets.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -24).isActive = true
        for l in presetLines { l.widthAnchor.constraint(equalTo: presets.widthAnchor).isActive = true }
        preview.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -24).isActive = true

        let box = NSView()
        box.wantsLayer = true
        box.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.7).cgColor
        box.layer?.cornerRadius = 20
        box.layer?.borderWidth = 2
        box.layer?.borderColor = Self.pinkStrong.cgColor
        box.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(stack)
        NSLayoutConstraint.activate([
            box.widthAnchor.constraint(equalToConstant: Self.columnWidth),
            box.heightAnchor.constraint(greaterThanOrEqualToConstant: 250),
            stack.leadingAnchor.constraint(equalTo: box.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: box.trailingAnchor),
            stack.topAnchor.constraint(equalTo: box.topAnchor),
        ])
        return box
    }

    private func label(_ s: String, _ size: CGFloat) -> NSTextField {
        let l = NSTextField(labelWithString: s)
        l.font = NSFont.systemFont(ofSize: size, weight: .semibold)
        l.textColor = Toolbar.plum.withAlphaComponent(0.75)
        return l
    }

    // MARK: Drawing the state

    func refresh() {
        guard panel != nil else { return }
        // Chosen letters, top to bottom; clicking one removes it.
        for v in layersRow.arrangedSubviews { layersRow.removeArrangedSubview(v); v.removeFromSuperview() }
        let example = Dictionary(uniqueKeysWithValues: (model.alphabet.consonants + model.alphabet.subjoinedOnly).map { ($0.key, $0.example) })
        for (i, key) in model.layers.enumerated() {
            let b = BubbleButton(glyph: example[key] ?? key, caption: key, glyphSize: 20,
                                 tip: "Remove \(key)", label: "Remove \(key), position \(i + 1)") { [weak self] in
                self?.model.removeLayer(at: i)
                self?.refresh()
            }
            b.filled = true
            b.widthAnchor.constraint(equalToConstant: 42).isActive = true
            b.heightAnchor.constraint(equalToConstant: 48).isActive = true
            layersRow.addArrangedSubview(b)
        }
        layersRow.isHidden = model.layers.isEmpty
        emptyHint.isHidden = !model.layers.isEmpty
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
            preview.textColor = Toolbar.plum.withAlphaComponent(0.25)
        case .built(let b):
            shown = b.text; shortest = b.shortest
            canonical = b.shortest == b.canonical ? "" : "full: \(b.canonical)"
            codes = b.codePoints
            notes = b.notes.prefix(2).joined(separator: "\n")
            preview.textColor = Toolbar.plum
        case .failed(let why):
            shown = "∅"; notes = why
            preview.textColor = Toolbar.plum.withAlphaComponent(0.25)
        }
        preview.stringValue = shown
        shortestLabel.stringValue = shortest
        canonicalLabel.stringValue = canonical
        codesLabel.stringValue = codes
        notesLabel.stringValue = notes
        hintLabel.stringValue = model.hint.isEmpty && model.result == .empty
            ? "Type a letter, Space adds it, Return inserts, Esc closes." : model.hint
        for l in [canonicalLabel, codesLabel, notesLabel] { l.isHidden = l.stringValue.isEmpty }
        typeRowView?.isHidden = shortest.isEmpty
        insertButton.isEnabled = model.built != nil
        copyButton.isEnabled = model.built != nil
        clearButton.isEnabled = !(model.layers.isEmpty && model.vowel.isEmpty && model.marks.isEmpty)
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
