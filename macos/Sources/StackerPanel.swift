import Cocoa
import CoreText

/// Top-left origin host for the alphabet document inside `NSScrollView`.
private final class FlippedHostView: NSView {
    override var isFlipped: Bool { true }
}

/// Layer-backed borderless button. Native bezels draw grey in non-key panels.
final class BubbleButton: NSButton {
    var onClick: (() -> Void)?
    var glyph = ""
    var caption = ""
    var glyphSize: CGFloat = 18
    /// The caption goes beside the glyph instead of under it (compact chips).
    var inlineCaption = false
    var filled = false { didSet { paint() } }
    /// Which ink envelope to share when Brutalist lays out a glyph+caption cell.
    var inventory: GlyphCaptionLayout.Inventory = .stackerConsonant
    /// Dimmed but enabled (typing prefix mismatch). Distinct from `isEnabled == false`.
    var dimmed = false {
        didSet { paint() }
    }
    /// Use the tighter preset radius (Brutalist) instead of the action radius.
    var presetChrome = false
    /// Borderless, clear chrome (Brutalist close control).
    var quietChrome = false

    convenience init(glyph: String, caption: String = "", glyphSize: CGFloat = 18, tip: String, label: String,
                     onClick: @escaping () -> Void) {
        self.init(frame: .zero)
        self.glyph = glyph
        self.caption = caption
        self.glyphSize = glyphSize
        self.onClick = onClick
        isBordered = false
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        layer?.cornerRadius = 12
        layer?.borderWidth = 1.5
        toolTip = tip
        setAccessibilityLabel(label)
        // A click fires on mouseDown (below); the action stays for keyboard and
        // VoiceOver presses, which go through performClick and never reach mouseDown.
        target = self
        action = #selector(fire)
        translatesAutoresizingMaskIntoConstraints = false
        paint()
    }

    /// Fires on mouseDown, not the usual mouseUp action: Stacker/Symbols are windows of
    /// the IME process, and by mouseUp macOS has often already deactivated the input
    /// method for TextEdit, so insertText would be ignored. A press cannot be cancelled by
    /// dragging off the button. super is not called, so the action does not fire as well.
    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        onClick?()
    }

    private var glyphLabel: NSTextField?
    private var captionLabel: NSTextField?
    /// Shared-baseline cells, plus text-only tiles (inherent “a”).
    private var usesSharedBaseline: Bool {
        Theme.current.usesSharedBaselineCells && (isCell || (look == .tile && !glyph.isEmpty))
    }

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

    override func hitTest(_ point: NSPoint) -> NSView? {
        // Non-activating panels: keep the whole control clickable (including heading tabs).
        guard !isHidden, isEnabled else { return nil }
        return frame.contains(point) ? self : nil
    }

    @objc private func fire() { onClick?() }
    override var acceptsFirstResponder: Bool { false }

    override var isEnabled: Bool {
        didSet { paint() }
    }

    private func applyAlpha() {
        // Both refined themes encode state in fill/ink colour, not opacity.
        alphaValue = 1
    }

    /// `soft`: ordinary button. `tile`: vowel/mark wash. `heading`: Brutalist tabs.
    enum Look { case soft, tile, heading }
    var look = Look.soft { didSet { paint() } }

    private var isCell: Bool { !caption.isEmpty && !inlineCaption }

    override func viewDidMoveToWindow() { paint() }
    override func viewDidChangeEffectiveAppearance() { paint() }

    override func layout() {
        super.layout()
        let t = Theme.current
        switch look {
        case .heading:
            if t.bubblegum { layer?.cornerRadius = 13 }
        case .tile: layer?.cornerRadius = t.tileRadius
        case .soft:
            if isCell { layer?.cornerRadius = t.cellRadius }
            else { layer?.cornerRadius = presetChrome ? t.presetRadius : t.actionRadius }
        }
        needsDisplay = true
    }

    override var isFlipped: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        // Layer paints the chrome; Brutalist cells draw shaped Tibetan + Didot here
        // so positioning uses ink baselines, not NSTextField line boxes.
        guard usesSharedBaseline, let ctx = NSGraphicsContext.current?.cgContext else {
            super.draw(dirtyRect)
            return
        }
        let t = Theme.current
        if filled, t.brutal {
            // Asymmetric inset: keep ~5 pt below the caption inside the selection fill.
            // Bubblegum selection is the layer fill (same outer size as unselected tiles).
            let inset = NSRect(x: bounds.minX + 3, y: bounds.minY + 1,
                               width: bounds.width - 6, height: bounds.height - 4)
            let path = NSBezierPath(roundedRect: inset, xRadius: t.cellRadius, yRadius: t.cellRadius)
            t.selection.setFill()
            path.fill()
        } else if t.bubblegum, Theme.bubblegumBiscuitEdge, !filled, isCell || look == .tile {
            // Optional: 1.5 pt darker lower edge suggesting biscuit thickness (harness experiment).
            let edgeInk = t.controlBorder.blended(withFraction: 0.28, of: t.ink) ?? t.controlBorder
            let path = NSBezierPath()
            let insetX = t.cellRadius * 0.35
            path.move(to: NSPoint(x: bounds.minX + insetX, y: bounds.minY + 1.2))
            path.line(to: NSPoint(x: bounds.maxX - insetX, y: bounds.minY + 1.2))
            edgeInk.setStroke()
            path.lineWidth = 1.5
            path.stroke()
        }
        let ink: NSColor
        let captionInk: NSColor
        if filled {
            ink = t.selectedInk
            captionInk = t.selectedCaption
        } else if !isEnabled {
            ink = t.mutedText
            captionInk = t.mutedText
        } else if dimmed {
            ink = t.secondaryText
            captionInk = t.mutedText
        } else {
            ink = t.ink
            captionInk = t.glyphCaption
        }
        let font: NSFont
        if TibetanFont.contains(glyph) {
            font = TibetanFont.font(glyphSize)
        } else if caption.isEmpty {
            font = t.bubblegum ? BubblegumFonts.ui(glyphSize, weight: .bold) : t.serif(glyphSize)
        } else {
            font = GlyphCaptionLayout.tibetan(glyphSize)
        }
        let gLine = CTLineCreateWithAttributedString(NSAttributedString(string: glyph, attributes: [
            .font: font, .foregroundColor: ink,
        ]))

        if caption.isEmpty {
            // Inherent “a”: centre the Roman ink inside the selection inset (≈5 pt pad).
            let area = NSRect(x: bounds.minX + 3, y: bounds.minY + 5,
                              width: bounds.width - 6, height: bounds.height - 8)
            var a: CGFloat = 0, d: CGFloat = 0, l: CGFloat = 0
            let tw = CTLineGetTypographicBounds(gLine, &a, &d, &l)
            let inkH = a + d
            ctx.saveGState()
            ctx.textMatrix = .identity
            ctx.translateBy(x: area.midX - tw / 2,
                            y: area.minY + (area.height - inkH) / 2 + d)
            CTLineDraw(gLine, ctx)
            ctx.restoreGState()
            return
        }

        let env = GlyphCaptionLayout.cached(inventory)
            ?? GlyphCaptionLayout.InkEnvelope(above: glyphSize * 1.15, below: glyphSize * 0.55, width: glyphSize)
        // Bubblegum: slightly larger pad so captions keep ~4–5 pt optical air above the tile edge.
        let layoutPad: CGFloat = t.bubblegum ? 3.5 : 2
        let spec = GlyphCaptionLayout.Spec(
            cellSize: bounds.size, glyphSize: glyphSize,
            captionSize: t.glyphCaptionSize, pad: layoutPad, centerEnvelope: true)
        let plan = GlyphCaptionLayout.plan(spec: spec, envelope: env)
        let bx = GlyphCaptionLayout.baselineX(for: glyph, font: font, cellWidth: bounds.width)
        ctx.saveGState()
        ctx.textMatrix = .identity
        ctx.translateBy(x: bx, y: plan.baselineY)
        CTLineDraw(gLine, ctx)
        ctx.restoreGState()

        var capSize = t.glyphCaptionSize
        var capLine = CTLineCreateWithAttributedString(NSAttributedString(string: caption, attributes: [
            .font: GlyphCaptionLayout.captionFont(capSize), .foregroundColor: captionInk,
        ]))
        var a: CGFloat = 0, d: CGFloat = 0, l: CGFloat = 0
        var cw = CTLineGetTypographicBounds(capLine, &a, &d, &l)
        // A long caption (the digits, "0123456789") is shrunk to fit its cell, not clipped.
        let room = bounds.width - 6
        if cw > room {
            capSize = max(6.5, capSize * room / cw)
            capLine = CTLineCreateWithAttributedString(NSAttributedString(string: caption, attributes: [
                .font: GlyphCaptionLayout.captionFont(capSize), .foregroundColor: captionInk,
            ]))
            cw = CTLineGetTypographicBounds(capLine, &a, &d, &l)
        }
        // Brutalist: ~5 pt under captions inside inset selection.
        // Bubblegum: keep caption ink ≥ ~4.5 pt above the tile edge (baseline − descent).
        let bottomClearance: CGFloat = t.bubblegum ? 4.5 : 5
        let centered = (plan.captionBand - (a + d + l)) / 2 + d
        let capBaseline = t.bubblegum ? max(bottomClearance + d, centered) : max(5, centered)
        ctx.saveGState()
        ctx.textMatrix = .identity
        ctx.translateBy(x: (bounds.width - cw) / 2, y: min(capBaseline, plan.captionBand - a - 1))
        CTLineDraw(capLine, ctx)
        ctx.restoreGState()
    }

    func paint() {
        let t = Theme.current
        let ink: NSColor
        let captionFont = GlyphCaptionLayout.captionFont(t.glyphCaptionSize)
        var labelFont: NSFont? = nil

        if look == .heading {
            if t.brutal {
                ink = filled ? t.ink : t.secondaryText
                layer?.cornerRadius = 0
                layer?.backgroundColor = NSColor.clear.cgColor
                layer?.borderWidth = 0
                labelFont = t.serif(16)
            } else {
                // Confectionery tab pills: raspberry selected, cream inactive.
                ink = filled ? t.selectedInk : t.ink
                layer?.cornerRadius = 13
                layer?.backgroundColor = resolved(filled ? t.selection : t.surface)
                layer?.borderWidth = filled ? 0 : 1
                layer?.borderColor = resolved(t.controlBorder)
                labelFont = BubblegumFonts.ui(13, weight: .bold)
            }
        } else if filled {
            ink = isEnabled ? t.selectedInk : t.disabledActionInk
        } else if !isEnabled {
            ink = t.disabledActionInk
        } else if dimmed {
            ink = t.secondaryText
        } else {
            ink = t.ink
        }

        if look != .heading {
            switch look {
            case .heading: break
            case .tile:
                layer?.cornerRadius = t.tileRadius
                if filled {
                    if t.brutal {
                        // Inset selection drawn in `draw(_:)`.
                        layer?.backgroundColor = NSColor.clear.cgColor
                        layer?.borderWidth = 0
                    } else {
                        layer?.masksToBounds = true
                        layer?.backgroundColor = resolved(t.selection)
                        layer?.borderWidth = 1
                        layer?.borderColor = resolved(t.selection)
                    }
                } else if t.brutal {
                    layer?.backgroundColor = dimmed ? resolved(t.dimmedFill) : NSColor.clear.cgColor
                    layer?.borderWidth = 0
                } else if !isEnabled {
                    layer?.backgroundColor = resolved(t.unavailableFill)
                    layer?.borderWidth = 1
                    layer?.borderColor = resolved(t.separator)
                } else if dimmed {
                    layer?.backgroundColor = resolved(t.dimmedFill)
                    layer?.borderWidth = 1
                    layer?.borderColor = resolved(t.controlBorder)
                } else {
                    layer?.backgroundColor = resolved(t.tile)
                    layer?.borderWidth = 1
                    layer?.borderColor = resolved(t.controlBorder)
                }
            case .soft:
                layer?.cornerRadius = isCell ? t.cellRadius : (presetChrome ? t.presetRadius : t.actionRadius)
                if filled && isCell {
                    if t.brutal {
                        layer?.backgroundColor = NSColor.clear.cgColor
                        layer?.borderWidth = 0
                    } else {
                        // Match unselected outer chrome exactly (1 pt border, full bounds fill).
                        layer?.masksToBounds = true
                        layer?.backgroundColor = resolved(t.selection)
                        layer?.borderWidth = 1
                        layer?.borderColor = resolved(t.selection)
                    }
                } else if filled {
                    layer?.backgroundColor = resolved(isEnabled ? t.selection : t.disabledActionFill)
                    layer?.borderWidth = 0
                } else if isCell {
                    if t.brutal {
                        layer?.backgroundColor = dimmed ? resolved(t.dimmedFill) : NSColor.clear.cgColor
                        layer?.borderWidth = 0
                    } else if !isEnabled {
                        layer?.backgroundColor = resolved(t.unavailableFill)
                        layer?.borderWidth = 1
                        layer?.borderColor = resolved(t.separator)
                    } else if dimmed {
                        layer?.backgroundColor = resolved(t.dimmedFill)
                        layer?.borderWidth = 1
                        layer?.borderColor = resolved(t.controlBorder)
                    } else {
                        layer?.backgroundColor = resolved(t.tile)
                        layer?.borderWidth = 1
                        layer?.borderColor = resolved(t.controlBorder)
                    }
                } else if quietChrome {
                    layer?.backgroundColor = NSColor.clear.cgColor
                    layer?.borderWidth = 0
                } else if !isEnabled {
                    layer?.backgroundColor = resolved(t.disabledActionFill)
                    layer?.borderWidth = t.bubblegum ? 1 : 0
                    layer?.borderColor = resolved(t.separator)
                } else if t.brutal {
                    layer?.backgroundColor = NSColor.clear.cgColor
                    layer?.borderWidth = 1
                    layer?.borderColor = resolved(t.controlBorder)
                } else {
                    // Cream secondary actions / presets.
                    layer?.backgroundColor = resolved(t.tile)
                    layer?.borderWidth = 1
                    layer?.borderColor = resolved(t.controlBorder)
                }
            }
        }
        applyAlpha()

        let font: NSFont
        if TibetanFont.contains(glyph) {
            font = TibetanFont.font(glyphSize)
        } else if let labelFont {
            font = labelFont
        } else if look == .tile && caption.isEmpty {
            font = t.bubblegum ? BubblegumFonts.ui(glyphSize, weight: .bold) : t.serif(glyphSize)
        } else if t.bubblegum {
            font = BubblegumFonts.ui(glyphSize, weight: caption.isEmpty || inlineCaption ? .semibold : .medium)
        } else {
            font = NSFont.systemFont(ofSize: glyphSize, weight: caption.isEmpty || inlineCaption ? .medium : .regular)
        }
        let para = NSMutableParagraphStyle()
        para.alignment = .center
        if usesSharedBaseline {
            attributedTitle = NSAttributedString(string: "")
            glyphLabel?.isHidden = true
            captionLabel?.isHidden = true
            needsDisplay = true
        } else if caption.isEmpty || inlineCaption {
            let text = NSMutableAttributedString(string: glyph, attributes: [
                .font: font, .foregroundColor: ink, .paragraphStyle: para])
            if inlineCaption {
                let capColor = filled ? t.selectedCaption.withAlphaComponent(0.9) : t.secondaryText
                text.append(NSAttributedString(string: "  " + caption, attributes: [
                    .font: captionFont, .foregroundColor: capColor, .paragraphStyle: para]))
            }
            attributedTitle = text
            glyphLabel?.isHidden = true
            captionLabel?.isHidden = true
        } else {
            attributedTitle = NSAttributedString(string: "")
            let g = ensureLabels()
            g.0.isHidden = false
            g.1.isHidden = false
            g.0.attributedStringValue = NSAttributedString(string: glyph, attributes: [
                .font: font, .foregroundColor: ink, .paragraphStyle: para])
            g.1.attributedStringValue = NSAttributedString(string: caption, attributes: [
                .font: captionFont,
                .foregroundColor: t.glyphCaption, .paragraphStyle: para])
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

    private static let originKey = PanelTabs.originKey
    private static let columnWidth: CGFloat = 264
    /// Dragged narrower than this, the window becomes one column.
    private static let singleColumnBelow: CGFloat = 620

    /// Height over width of the picture.
    private var artRatio: CGFloat {
        guard let s = art?.image?.size, s.width > 0 else { return 1050.0 / 960 }
        return s.height / s.width
    }

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
    /// Brutalist Core Text preview; Bubblegum keeps `preview` (NSTextField).
    private let stackPreview = StackPreviewView()
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
    private var typedRowWidth: NSLayoutConstraint!
    private var previewRowWidth: NSLayoutConstraint!
    private var cellHeights: [NSLayoutConstraint] = []
    private var presetHeights: [NSLayoutConstraint] = []
    private var wideOnly: [NSLayoutConstraint] = []     // controls that fill the card
    private var compactOnly: [NSLayoutConstraint] = []  // controls in the footer
    private let lettersColumn = NSStackView()
    private let lettersScroll = NSScrollView()
    private var lettersScrollHeight: NSLayoutConstraint?
    private var brutalButtonsWidth: NSLayoutConstraint?
    private var previewHeight: NSLayoutConstraint?
    private var typeRowHeight: NSLayoutConstraint?
    private var typeRowWidth: NSLayoutConstraint?
    private var composeHeightConstraint: NSLayoutConstraint?
    private var gridRule: RuleView?
    private let composeColumn = NSStackView()
    private let layersScroll = NSScrollView()
    private let lettersDocument = FlippedHostView()
    private var typedRowHidden = false

    var isOpen: Bool { panel?.isVisible ?? false }
    var window: NSPanel? { panel }
    /// The panel's content, for rendering without showing it.
    var contentView: NSView? { ensurePanel().contentView }

    // MARK: Showing

    func open(topLeft: NSPoint? = nil) {
        model.precomposed = Prefs.precomposed
        pendingClose?.cancel()
        let panel = ensurePanel()
        PanelTabs.fit(toNavigator: panel, tab: .stacker)
        adaptLettersHeight(panelHeight: panel.frame.height)
        refresh()
        scrollAlphabetToStart()
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
        if Theme.current.brutal {
            // Prefer the dedicated 4:3 PNG; fall back to the older webp.
            if let url = Bundle.main.url(forResource: "stacker-art-brutal", withExtension: "png")
                ?? Bundle.main.url(forResource: "stacker-art-brutal", withExtension: "webp") {
                art.image = NSImage(contentsOf: url)
            }
            art.imageScaling = .scaleProportionallyUpOrDown
            art.wantsLayer = true
            art.layer?.cornerRadius = Theme.current.artRadius
            art.layer?.masksToBounds = true
            art.setAccessibilityLabel("A stencil of a Tibetan vessel on weathered concrete panels")
        } else if let url = Bundle.main.url(forResource: "stacker-art", withExtension: "webp") {
            art.image = NSImage(contentsOf: url)
            art.imageScaling = .scaleProportionallyUpOrDown
            art.wantsLayer = true
            art.layer?.cornerRadius = Theme.current.artRadius
            art.layer?.masksToBounds = true
            art.setAccessibilityLabel("A cat-maid carrying a tower of flatbreads, and a yak with books")
        }
        art.translatesAutoresizingMaskIntoConstraints = false
        artWidth = art.widthAnchor.constraint(equalToConstant: Self.columnWidth)
        artHeight = art.heightAnchor.constraint(equalToConstant: Self.columnWidth * artRatio)
        NSLayoutConstraint.activate([artWidth, artHeight])

        card = resultCard()

        // The same title, tabs and close button as the other panels.
        header = PanelTabs.makeHeader(selected: .stacker, panel: { [weak self] in self?.panel }) { [weak self] in self?.close() }
        typedRowWidth = typedRow.widthAnchor.constraint(equalToConstant: 100)
        typedRowWidth.isActive = true

        // Bubblegum: vertical stack of chips. Brutalist: horizontal chip strip.
        layersRow.orientation = Theme.current.usesComposeLayout ? .horizontal : .vertical
        layersRow.spacing = Theme.current.usesComposeLayout ? 4 : 3
        layersRow.alignment = Theme.current.usesComposeLayout ? .centerY : .centerX
        emptyHint.stringValue = "Add letters top to bottom: the first goes on top."
        emptyHint.font = Theme.current.bubblegum
            ? BubblegumFonts.ui(10, weight: .medium)
            : NSFont.systemFont(ofSize: 10)
        emptyHint.textColor = Theme.current.mutedText
        layersBox = NSView()
        layersBox.translatesAutoresizingMaskIntoConstraints = false
        layersBox.heightAnchor.constraint(equalToConstant: 20).isActive = true
        for v in [emptyHint] {
            v.translatesAutoresizingMaskIntoConstraints = false
            layersBox.addSubview(v)
            v.leadingAnchor.constraint(equalTo: layersBox.leadingAnchor).isActive = true
            v.centerYAnchor.constraint(equalTo: layersBox.centerYAnchor).isActive = true
        }
        layersScroll.drawsBackground = false
        layersScroll.hasVerticalScroller = false
        layersScroll.hasHorizontalScroller = true
        layersScroll.autohidesScrollers = true
        layersScroll.scrollerStyle = .overlay
        layersScroll.borderType = .noBorder
        layersScroll.translatesAutoresizingMaskIntoConstraints = false
        layersScroll.heightAnchor.constraint(equalToConstant: 24).isActive = true
        layersScroll.documentView = layersRow

        typedLabel.font = Theme.current.usesComposeLayout
            ? NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
            : NSFont.monospacedSystemFont(ofSize: 13, weight: .semibold)
        typedLabel.textColor = Theme.current.secondaryText
        typedLabel.alignment = Theme.current.usesComposeLayout ? .center : .natural

        stackPreview.translatesAutoresizingMaskIntoConstraints = false
        stackPreview.nominalSize = Theme.current.previewNominalSize
        stackPreview.ink = Theme.current.ink

        let t = Theme.current
        GlyphCaptionLayout.warmStacker(alphabet: alphabet, glyphSize: t.stackerGlyphSize)
        let cell = t.stackerCell
        grid = NSStackView()
        grid.orientation = .vertical
        grid.alignment = .leading
        grid.spacing = t.stackerGapY
        let known = Set(alphabet.consonants.map(\.key))
        let example = Dictionary(uniqueKeysWithValues: (alphabet.consonants + alphabet.subjoinedOnly).map { ($0.key, $0.example) })
        var rows: [(String, [String])] = Self.rows.map { ($0.0, $0.1.filter { known.contains($0) }) }
        let placed = Set(Self.rows.flatMap(\.1))
        let rest = alphabet.consonants.map(\.key).filter { !placed.contains($0) }
        if !rest.isEmpty { rows.append(("More", rest)) }
        rows.append(("Subjoined", alphabet.subjoinedOnly.map(\.key)))
        for (name, keys) in rows where !keys.isEmpty {
            let label = Theme.current.railLabel(name, width: t.railWidth)
            var cellViews: [NSView] = []
            let isSubjoined = name == "Subjoined"
            for key in keys {
                let b = BubbleButton(glyph: example[key] ?? key, caption: key, glyphSize: t.stackerGlyphSize,
                                     tip: "Add \(key)", label: "Add \(key)") { [weak self] in
                    self?.model.addLayer(key)
                    self?.refresh()
                }
                b.inventory = isSubjoined ? .stackerTile : .stackerConsonant
                b.widthAnchor.constraint(equalToConstant: cell.width).isActive = true
                let h = b.heightAnchor.constraint(equalToConstant: cell.height)
                h.isActive = true
                cellHeights.append(h)
                cells[key] = b
                cellViews.append(b)
            }
            // Match vowel/marks section geometry: rail | gutter | cell strip (common column origin).
            let strip = NSStackView(views: cellViews)
            strip.spacing = t.stackerGapX
            if t.usesComposeLayout { strip.alignment = .centerY }
            let line = NSStackView(views: [label, strip])
            line.spacing = 8
            line.alignment = t.usesComposeLayout ? .centerY : .top
            grid.addArrangedSubview(line)
        }

        let vowelOrder = ["i", "I", "u", "U", "e", "o", "ai", "au", "A", "-i", "-I", "ui", "ue", "uo"]
        let rank = { (k: String) in vowelOrder.firstIndex(of: k) ?? vowelOrder.count }
        var vowelRow: [NSView] = []
        let inherent = BubbleButton(glyph: "a", glyphSize: t.stackerGlyphSize, tip: "Inherent vowel a (no sign)", label: "Vowel a") { [weak self] in
            self?.model.setVowel("")
            self?.refresh()
        }
        vowelButtons[""] = inherent
        vowelRow.append(inherent)
        for v in alphabet.vowels.sorted(by: { rank($0.key) < rank($1.key) }) {
            let b = BubbleButton(glyph: v.example, caption: v.key, glyphSize: t.stackerGlyphSize, tip: "Vowel \(v.key)", label: "Vowel \(v.key)") { [weak self] in
                self?.model.setVowel(v.key)
                self?.refresh()
            }
            b.inventory = .stackerTile
            vowelButtons[v.key] = b
            vowelRow.append(b)
        }
        var markRow: [NSView] = []
        for m in alphabet.marks {
            let b = BubbleButton(glyph: m.example, caption: m.key, glyphSize: t.stackerGlyphSize, tip: "Mark \(m.key)", label: "Mark \(m.key)") { [weak self] in
                self?.model.toggleMark(m.key)
                self?.refresh()
            }
            b.inventory = .stackerTile
            markButtons[m.key] = b
            markRow.append(b)
        }
        for b in (vowelRow + markRow) {
            guard let button = b as? BubbleButton else { continue }
            button.look = .tile
            b.widthAnchor.constraint(equalToConstant: cell.width).isActive = true
            b.heightAnchor.constraint(equalToConstant: cell.height).isActive = true
        }
        // Inherent "a" has no caption; match tile size for the row.
        inherent.look = .tile
        inherent.inventory = .stackerTile
        inherent.widthAnchor.constraint(equalToConstant: cell.width).isActive = true
        inherent.heightAnchor.constraint(equalToConstant: cell.height).isActive = true
        vowelSection = section("Vowel", vowelRow, perRow: 8)
        marksSection = section("Marks", markRow, perRow: 9)

        lettersColumn.orientation = .vertical
        lettersColumn.alignment = .leading
        lettersColumn.spacing = t.sectionSpacing
        lettersColumn.translatesAutoresizingMaskIntoConstraints = false
        lettersScroll.drawsBackground = false
        lettersScroll.hasVerticalScroller = true
        lettersScroll.autohidesScrollers = true
        lettersScroll.scrollerStyle = .overlay
        lettersScroll.borderType = .noBorder
        lettersScroll.translatesAutoresizingMaskIntoConstraints = false
        // Padding lives inside the flipped document (not contentInsets). Equal viewport/document
        // heights plus non-zero contentInsets permanently clip the first/last rows.
        lettersScroll.contentInsets = .init(top: 0, left: 0, bottom: 0, right: 0)
        lettersScroll.scrollerInsets = NSEdgeInsets(top: 0, left: 0, bottom: 8, right: 0)
        lettersScroll.automaticallyAdjustsContentInsets = false
        if t.usesComposeLayout {
            let rule = RuleView(vertical: false)
            gridRule = rule
            lettersDocument.translatesAutoresizingMaskIntoConstraints = false
            // Cap content width so Marks cannot force the panel past the content rectangle.
            for line in grid.arrangedSubviews {
                line.widthAnchor.constraint(lessThanOrEqualToConstant: PanelTabs.innerWidth).isActive = true
            }
            vowelSection.widthAnchor.constraint(lessThanOrEqualToConstant: PanelTabs.innerWidth).isActive = true
            marksSection.widthAnchor.constraint(lessThanOrEqualToConstant: PanelTabs.innerWidth).isActive = true
        }

        leftColumn.orientation = .vertical
        leftColumn.alignment = .centerX
        leftColumn.spacing = 10
        rightColumn.orientation = .vertical
        rightColumn.alignment = .leading
        rightColumn.spacing = t.rootSpacing
        flexible.setContentHuggingPriority(.init(1), for: .vertical)
        flexible.setContentCompressionResistancePriority(.init(1), for: .vertical)
        topRow.orientation = .horizontal
        topRow.alignment = .top
        topRow.spacing = 12
        typedRow.orientation = .horizontal
        typedRow.alignment = .firstBaseline
        typedRow.spacing = 10
        composeColumn.orientation = .vertical
        composeColumn.alignment = .leading
        composeColumn.spacing = 4
        composeColumn.translatesAutoresizingMaskIntoConstraints = false

        root.edgeInsets = PanelTabs.insets
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
        ("Labial", ["p", "ph", "b", "bh", "m"]), ("Affricates +", ["ts", "tsh", "dz", "w", "zh", "z"]),
        ("Others", ["'", "y", "r", "l", "sh", "Sh", "s", "h"]), ("Special", ["f", "v", "R"]),
    ]

    private func section(_ name: String, _ items: [NSView], perRow: Int) -> NSView {
        let t = Theme.current
        let label = t.railLabel(name, width: t.railWidth)
        let lines = stride(from: 0, to: items.count, by: perRow).map { i -> NSView in
            let s = NSStackView(views: Array(items[i..<min(i + perRow, items.count)]))
            s.spacing = t.stackerGapX
            // Align the rail with the first character row, not the section's top padding.
            if t.usesComposeLayout { s.alignment = .centerY }
            return s
        }
        let column = NSStackView(views: lines)
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = t.stackerGapY
        let row = NSStackView(views: [label, column])
        // Match consonant rows: 8 pt rail gutter so every glyph column shares an origin.
        row.spacing = 8
        // Centre the category label on the glyph row for compose layouts.
        row.alignment = t.usesComposeLayout ? .centerY : .top
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
        let meta = Theme.current
        codesLabel.font = NSFont.monospacedSystemFont(ofSize: 9.5, weight: .regular)
        codesLabel.textColor = meta.mutedText
        notesLabel.font = meta.bubblegum ? BubblegumFonts.ui(10, weight: .medium) : NSFont.systemFont(ofSize: 10)
        notesLabel.textColor = meta.secondaryText
        hintLabel.font = meta.bubblegum ? BubblegumFonts.ui(11, weight: .medium) : NSFont.systemFont(ofSize: 10, weight: .regular)
        hintLabel.textColor = meta.mutedText
        hintLabel.preferredMaxLayoutWidth = Self.columnWidth - 24
        if meta.usesComposeLayout {
            hintLabel.stringValue = "Type a letter · Space adds · Return inserts · Esc closes"
        }

        let actionSize: CGFloat = meta.usesComposeLayout ? (meta.bubblegum ? 12 : 10) : 13
        insertButton = BubbleButton(glyph: "Insert  ⏎", glyphSize: actionSize, tip: "Put it in the document (Return)", label: "Insert") { [weak self] in
            self?.insertBuilt()
            self?.refresh()
        }
        insertButton.filled = true
        copyButton = BubbleButton(glyph: "Copy", glyphSize: actionSize, tip: "Copy the stack", label: "Copy") { [weak self] in
            guard let b = self?.model.built else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(b.text, forType: .string)
            self?.model.setHint("Copied \(b.text).")
            self?.refresh()
        }
        clearButton = BubbleButton(glyph: "Clear", glyphSize: actionSize, tip: "Start over", label: "Clear") { [weak self] in
            self?.model.clear()
            self?.refresh()
        }
        buttonsRow = NSStackView(views: [insertButton, copyButton, clearButton])
        buttonsRow.distribution = .fillEqually
        buttonsRow.spacing = 6
        for (b, w) in zip([insertButton!, copyButton!, clearButton!], [104, 104, 104] as [CGFloat]) {
            // Brutalist composition wants equal-height actions without a tall Bubblegum strip.
            b.heightAnchor.constraint(equalToConstant: Theme.current.usesComposeLayout ? Theme.current.actionButtonHeight : 32).isActive = true
            let c = b.widthAnchor.constraint(equalToConstant: w)
            compactOnly.append(c)
        }
        let inner = Self.columnWidth - 24
        let buttonsFill = buttonsRow.widthAnchor.constraint(equalToConstant: inner)
        wideOnly.append(buttonsFill)

        // "Start from" chips: two lines of four when wide, one line when compact.
        presetLabel = label("Start from", 10)
        let presetGlyph: CGFloat = meta.usesComposeLayout ? 11 : 12
        for p in StackerModel.presets {
            let b = BubbleButton(glyph: p.label, glyphSize: presetGlyph, tip: "Start from \(p.label)", label: "Start from \(p.label)") { [weak self] in
                self?.model.usePreset(p.letters)
                self?.refresh()
            }
            b.presetChrome = true
            let h = b.heightAnchor.constraint(equalToConstant: meta.presetHeight)
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
        if Theme.current.usesComposeLayout {
            box.layer?.backgroundColor = NSColor.clear.cgColor
            box.layer?.cornerRadius = 0
            box.layer?.borderWidth = 0
        } else {
            box.layer?.backgroundColor = box.resolved(Theme.current.surface)
            box.layer?.cornerRadius = 18
            box.layer?.borderWidth = 1
            box.layer?.borderColor = box.resolved(Theme.current.controlBorder)
        }
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
        let t = Theme.current
        let l = NSTextField(labelWithString: s)
        l.font = t.bubblegum ? BubblegumFonts.ui(size, weight: .semibold) : NSFont.systemFont(ofSize: size, weight: t.brutal ? .regular : .semibold)
        l.textColor = t.secondaryText
        return l
    }

    // MARK: One column or two

    /// Arranges the shared views for `compact`. Views move between stacks; the
    /// constraints that tie them to a neighbour are all constants, so nothing is
    /// lost on the way.
    private func applyLayout() {
        let c = compact
        let t = Theme.current
        let brutalCompose = c && t.usesComposeLayout
        // Bubblegum may grow with the widest letter row; Brutalist stays inside the content rectangle.
        let measured = ceil(max(grid.fittingSize.width, vowelSection.fittingSize.width, marksSection.fittingSize.width))
        let contentWidth = brutalCompose ? PanelTabs.innerWidth : max(PanelTabs.innerWidth, measured)
        typedRowWidth.constant = contentWidth

        if brutalCompose {
            // 50:50 composition filling the content rectangle (Bubblegum 247|12|247; Brutalist 232|12|232).
            let col = t.composeColumnWidth
            let artH = t.stackerArtHeight
            // Explicit non-overlapping regions (siblings in cardStack — never nested):
            //   [chips?] + gap + [preview] + gap + [transliteration] + gap + [actions] = artH
            let regionGap: CGFloat = t.bubblegum ? 10 : 4
            // Dedicated transliteration band: clearance above Insert/Copy/Clear.
            let typeH: CGFloat = t.bubblegum ? 28 : 18
            topRow.spacing = t.composeGutter
            artWidth.constant = col
            artHeight.constant = artH
            art.imageScaling = .scaleProportionallyUpOrDown
            cardWidth.constant = col
            cardMinHeight.constant = artH
            cardMinHeight.isActive = true
            cardStack.edgeInsets = .init(top: 0, left: 0, bottom: 0, right: 0)
            cardStack.alignment = .centerX
            // Spacing is applied per-gap via setCustomSpacing after arrange.
            cardStack.spacing = regionGap
            preview.isHidden = true
            stackPreview.isHidden = false
            stackPreview.nominalSize = t.previewNominalSize
            stackPreview.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
            stackPreview.setContentHuggingPriority(.defaultLow, for: .vertical)
            if let typeRow = typeRowView {
                typeRow.setContentCompressionResistancePriority(.required, for: .vertical)
                typeRow.setContentHuggingPriority(.required, for: .vertical)
                typeRow.setContentCompressionResistancePriority(.required, for: .horizontal)
                if typeRowHeight == nil {
                    typeRowHeight = typeRow.heightAnchor.constraint(equalToConstant: typeH)
                    typeRowHeight?.isActive = true
                }
                typeRowHeight?.constant = typeH
                if typeRowWidth == nil {
                    typeRowWidth = typeRow.widthAnchor.constraint(equalToConstant: col)
                    typeRowWidth?.isActive = true
                }
                typeRowWidth?.constant = col
            }
            buttonsRow.setContentCompressionResistancePriority(.required, for: .vertical)
            buttonsRow.setContentHuggingPriority(.required, for: .vertical)
            if previewHeight == nil {
                previewHeight = stackPreview.heightAnchor.constraint(equalToConstant: 100)
            }
            // Empty state: no chips. Two stack gaps (preview↔type, type↔buttons).
            let residual = artH - typeH - t.actionButtonHeight - 2 * regionGap
            previewHeight?.constant = max(64, residual)
            previewHeight?.isActive = true
            layersRow.orientation = .horizontal
            layersRow.spacing = 4
            layersScroll.widthAnchor.constraint(equalToConstant: col).isActive = true
            buttonsRow.orientation = .horizontal
            buttonsRow.distribution = .fillEqually
            buttonsRow.spacing = t.bubblegum ? 6 : 5
            compactOnly.forEach { $0.isActive = false }
            wideOnly.forEach { $0.isActive = false }
            if brutalButtonsWidth == nil {
                brutalButtonsWidth = buttonsRow.widthAnchor.constraint(equalToConstant: col)
            }
            brutalButtonsWidth?.constant = col
            brutalButtonsWidth?.isActive = true
            previewRowWidth.constant = col
            if composeHeightConstraint == nil {
                composeHeightConstraint = topRow.heightAnchor.constraint(equalToConstant: artH)
            }
            composeHeightConstraint?.constant = artH
            composeHeightConstraint?.isActive = true
            hintLabel.preferredMaxLayoutWidth = contentWidth
            hintLabel.maximumNumberOfLines = 1
            hintLabel.lineBreakMode = .byTruncatingTail
            hintLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
            shortestLabel.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
            shortestLabel.textColor = t.secondaryText
            shortestLabel.alignment = .center
            shortestLabel.maximumNumberOfLines = 1
            shortestLabel.lineBreakMode = .byClipping
            shortestLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        } else {
            brutalButtonsWidth?.isActive = false
            previewHeight?.isActive = false
            composeHeightConstraint?.isActive = false
            preview.isHidden = false
            stackPreview.isHidden = true
            cardMinHeight.isActive = true
            let artW: CGFloat = c ? 146 : Self.columnWidth
            artWidth.constant = artW
            artHeight.constant = (artW * artRatio).rounded()
            cardWidth.constant = c ? contentWidth - artW - 104 - 2 * topRow.spacing : Self.columnWidth
            cardMinHeight.constant = c ? artHeight.constant : 250
            previewRowWidth.constant = cardWidth.constant - 24
            wideOnly.forEach { $0.isActive = !c }
            compactOnly.forEach { $0.isActive = c }
            preview.font = TibetanFont.font(c ? 40 : 46)
            layersRow.orientation = .vertical
            layersRow.spacing = c ? 2 : 3
            buttonsRow.orientation = c ? .vertical : .horizontal
            buttonsRow.distribution = c ? .fill : .fillEqually
            hintLabel.preferredMaxLayoutWidth = c ? contentWidth - 100 : Self.columnWidth - 24
            hintLabel.maximumNumberOfLines = c ? 1 : 0
            hintLabel.lineBreakMode = c ? .byTruncatingTail : .byWordWrapping
            hintLabel.setContentCompressionResistancePriority(c ? .init(250) : .defaultHigh, for: .horizontal)
            cardStack.edgeInsets = NSEdgeInsets(top: 10, left: 12, bottom: 12, right: 12)
        }

        let cellH = t.stackerCell.height
        cellHeights.forEach { $0.constant = cellH }
        presetHeights.forEach { $0.constant = t.presetHeight }
        for b in presetButtons {
            b.glyphSize = t.usesComposeLayout ? 11 : (c ? 11 : 12)
            b.presetChrome = true
            b.paint()
        }

        if c {
            presetChips.arrange(presetButtons)
            presetsCompact.arrange([presetLabel, presetChips])
            for line in presetLines { line.arrange([]) }
            presetsWide.arrange([])
            leftColumn.arrange([])
            rightColumn.arrange([])
            root.orientation = .vertical
            root.alignment = .leading
            root.spacing = t.rootSpacing

            if brutalCompose {
                // Right column: four sibling regions — chips · preview · type · actions.
                // Chips are NOT nested inside the preview row (avoids residual compression).
                let regionGap: CGFloat = t.bubblegum ? 10 : 4
                previewRow.orientation = .vertical
                previewRow.alignment = .centerX
                previewRow.spacing = 0
                previewRow.arrange([stackPreview])
                if let typeRow = typeRowView as? NSStackView {
                    // Compose shows only the transliteration, centred in its band.
                    typeRow.orientation = .horizontal
                    typeRow.alignment = .centerY
                    typeRow.arrange([shortestLabel])
                }
                var regions: [NSView] = []
                if !model.layers.isEmpty { regions.append(layersScroll) }
                regions.append(contentsOf: [previewRow, typeRowView!, buttonsRow])
                cardStack.arrange(regions)
                cardStack.spacing = regionGap
                if !model.layers.isEmpty {
                    cardStack.setCustomSpacing(regionGap, after: layersScroll)
                }
                cardStack.setCustomSpacing(regionGap, after: previewRow)
                cardStack.setCustomSpacing(regionGap, after: typeRowView!)
                composeColumn.arrange([card])
                composeColumn.alignment = .leading
                topRow.arrange([art, composeColumn])
                topRow.alignment = .top
                // Typing status sits with instructions, not inside the stable composition.
                typedRow.arrange([typedLabel])
                typedRow.isHidden = typedRowHidden
                // Alphabet blocks live in the scroll document (see syncLettersDocument).
                lettersColumn.arrange([])
                syncLettersDocument()
                if lettersScrollHeight == nil {
                    let h = lettersScroll.heightAnchor.constraint(equalToConstant: 220)
                    lettersScrollHeight = h
                    h.isActive = true
                }
                // Width is pinned once; avoid stacking duplicate constraints on re-layout.
                if lettersScroll.constraints.first(where: { $0.firstAttribute == .width }) == nil {
                    lettersScroll.widthAnchor.constraint(equalToConstant: PanelTabs.innerWidth).isActive = true
                }
                var body: [NSView] = [header, topRow, typedRow, hintLabel, presetsCompact]
                if let rule = gridRule { body.append(rule) }
                body.append(lettersScroll)
                root.arrange(body)
                let gum = t.bubblegum
                root.setCustomSpacing(gum ? 5 : 8, after: topRow)
                root.setCustomSpacing(2, after: typedRow)
                root.setCustomSpacing(gum ? 3 : 4, after: hintLabel)
                root.setCustomSpacing(gum ? 4 : 6, after: presetsCompact)
                if let rule = gridRule { root.setCustomSpacing(gum ? 3 : 4, after: rule) }
            } else {
                typedRow.arrange([typedLabel, hintLabel])
                typedRow.isHidden = false
                cardStack.arrange([previewRow, typeRowView!])
                root.arrange([header, topRow, typedRow, presetsCompact, grid, vowelSection, marksSection])
                topRow.arrange([art, card, buttonsRow])
                lettersScroll.documentView = nil
            }
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

    /// The size the window takes for a drag to `wanted`: the width is the
    /// navigator's. The grip calls this as the mouse moves.
    private func proposedSize(_ wanted: NSSize) -> NSSize {
        let size = PanelTabs.proposed(wanted, tab: .stacker)
        adaptLettersHeight(panelHeight: size.height)
        return size
    }

    private var lettersDocWidth: NSLayoutConstraint?
    private var lettersDocHeight: NSLayoutConstraint?
    /// Top padding inside the flipped alphabet document so Velar ink clears the clip edge.
    private static let lettersDocTopPad: CGFloat = 10
    /// Extra bottom pad so Marks captions clear the clip edge when scrolled to the end.
    private static let lettersDocBottomPad: CGFloat = 18

    /// Keep the alphabet document sized to its full content (independent of the viewport).
    ///
    /// Uses `lettersDocument` (flipped) as the scroll document so y=0 is the top.
    /// Embedding padding in the document — rather than `contentInsets` — avoids clipping
    /// when the viewport height equals the document height at natural panel size.
    private func syncLettersDocument() {
        guard Theme.current.usesComposeLayout, compact else { return }
        let w = PanelTabs.innerWidth
        let t = Theme.current
        let cellH = t.stackerCell.height
        let gridRows = max(grid.arrangedSubviews.count, Self.rows.count + 1)
        let contentH = CGFloat(gridRows) * cellH + CGFloat(max(gridRows - 1, 0)) * t.stackerGapY
            + 2 * cellH + t.stackerGapY + cellH + 2 * t.sectionSpacing
        let docH = contentH + Self.lettersDocTopPad + Self.lettersDocBottomPad

        lettersColumn.orientation = .vertical
        lettersColumn.alignment = .leading
        lettersColumn.spacing = t.sectionSpacing
        lettersColumn.translatesAutoresizingMaskIntoConstraints = false
        lettersColumn.arrange([grid, vowelSection, marksSection])
        grid.translatesAutoresizingMaskIntoConstraints = false
        vowelSection.translatesAutoresizingMaskIntoConstraints = false
        marksSection.translatesAutoresizingMaskIntoConstraints = false

        if lettersColumn.superview !== lettersDocument {
            lettersColumn.removeFromSuperview()
            lettersDocument.subviews.forEach { $0.removeFromSuperview() }
            lettersDocument.addSubview(lettersColumn)
            NSLayoutConstraint.activate([
                lettersColumn.leadingAnchor.constraint(equalTo: lettersDocument.leadingAnchor),
                lettersColumn.trailingAnchor.constraint(equalTo: lettersDocument.trailingAnchor),
                lettersColumn.topAnchor.constraint(equalTo: lettersDocument.topAnchor,
                                                   constant: Self.lettersDocTopPad),
            ])
        }
        if lettersScroll.documentView !== lettersDocument {
            lettersScroll.documentView = lettersDocument
        }
        if lettersDocWidth == nil {
            lettersDocWidth = lettersDocument.widthAnchor.constraint(equalToConstant: w)
            lettersDocWidth?.isActive = true
            lettersColumn.widthAnchor.constraint(equalTo: lettersDocument.widthAnchor).isActive = true
        }
        lettersDocWidth?.constant = w
        if lettersDocHeight == nil {
            lettersDocHeight = lettersDocument.heightAnchor.constraint(equalToConstant: docH)
            lettersDocHeight?.isActive = true
        }
        lettersDocHeight?.constant = docH
        lettersDocument.layoutSubtreeIfNeeded()
    }

    /// The width the widest block of letters needs.
    var naturalContentWidth: CGFloat {
        _ = ensurePanel()
        return ceil(max(grid.fittingSize.width, vowelSection.fittingSize.width, marksSection.fittingSize.width))
    }

    /// Full content height (alphabet fully expanded). Bubblegum never goes below this;
    /// Brutalist may, and then scrolls the alphabet.
    var naturalHeight: CGFloat {
        _ = ensurePanel()
        applyLayout()
        syncLettersDocument()
        container.layoutSubtreeIfNeeded()
        if Theme.current.usesComposeLayout, compact, lettersScroll.documentView != nil {
            syncLettersDocument()
            let lettersH = max(lettersDocHeight?.constant ?? 180, 180)
            lettersScrollHeight?.isActive = false
            let expand = lettersScroll.heightAnchor.constraint(equalToConstant: lettersH)
            expand.isActive = true
            container.layoutSubtreeIfNeeded()
            let h = ceil(container.fittingSize.height)
            expand.isActive = false
            lettersScrollHeight?.isActive = true
            return h
        }
        return ceil(container.fittingSize.height)
    }

    /// Chrome above/below the alphabet scroll (header, composition, presets, …).
    private var lettersChromeHeight: CGFloat {
        container.layoutSubtreeIfNeeded()
        lettersScrollHeight?.isActive = false
        let zero = lettersScroll.heightAnchor.constraint(equalToConstant: 0)
        zero.isActive = true
        container.layoutSubtreeIfNeeded()
        let chrome = ceil(container.fittingSize.height)
        zero.isActive = false
        lettersScrollHeight?.isActive = true
        return chrome
    }

    /// Shortest usable Brutalist height: composition chrome + a usable alphabet viewport.
    var minimumHeight: CGFloat {
        _ = ensurePanel()
        guard Theme.current.usesComposeLayout else { return naturalHeight }
        return ceil(lettersChromeHeight + 220)
    }

    /// Fits the letters scroll to the panel height (Brutalist).
    func adaptLettersHeight(panelHeight: CGFloat) {
        guard Theme.current.usesComposeLayout, compact else { return }
        syncLettersDocument()
        let chrome = lettersChromeHeight
        let available = max(160, panelHeight - chrome)
        // Viewport stays at the remaining window height; the document keeps its full height.
        lettersScrollHeight?.isActive = false
        let h = lettersScroll.heightAnchor.constraint(equalToConstant: available)
        lettersScrollHeight = h
        h.isActive = true
        container.layoutSubtreeIfNeeded()
        scrollAlphabetToStart()
    }

    /// Pin the clip view to the top of the flipped alphabet document (y = 0).
    func scrollAlphabetToStart() {
        guard Theme.current.usesComposeLayout, compact, lettersScroll.documentView != nil else { return }
        lettersScroll.layoutSubtreeIfNeeded()
        let clip = lettersScroll.contentView
        clip.scroll(to: NSPoint(x: 0, y: 0))
        lettersScroll.reflectScrolledClipView(clip)
    }

    /// Pin the clip view so the Marks row is fully visible.
    func scrollAlphabetToEnd() {
        guard Theme.current.usesComposeLayout, compact, lettersScroll.documentView != nil else { return }
        lettersScroll.layoutSubtreeIfNeeded()
        let clip = lettersScroll.contentView
        let maxY = max(0, lettersDocument.bounds.height - clip.bounds.height)
        clip.scroll(to: NSPoint(x: 0, y: maxY))
        lettersScroll.reflectScrolledClipView(clip)
    }

    /// Ensure a cell is fully visible inside the alphabet viewport (keyboard navigation).
    func revealAlphabetCell(_ view: NSView) {
        guard Theme.current.usesComposeLayout, compact else { return }
        var rect = view.convert(view.bounds, to: lettersDocument)
        rect = rect.insetBy(dx: 0, dy: -6)
        lettersDocument.scrollToVisible(rect)
    }

    // MARK: Drawing the state

    func refresh() {
        guard panel != nil else { return }
        // Chosen letters, top to bottom; clicking one removes it.
        for v in layersRow.arrangedSubviews { layersRow.removeArrangedSubview(v); v.removeFromSuperview() }
        let example = Dictionary(uniqueKeysWithValues: (model.alphabet.consonants + model.alphabet.subjoinedOnly).map { ($0.key, $0.example) })
        let compose = Theme.current.usesComposeLayout
        for (i, key) in model.layers.enumerated() {
            let b = BubbleButton(glyph: example[key] ?? key, caption: key, glyphSize: compose ? 12 : (compact ? 15 : 17),
                                 tip: "Remove \(key)", label: "Remove \(key), position \(i + 1)") { [weak self] in
                self?.model.removeLayer(at: i)
                self?.refresh()
            }
            // Compose themes: quiet cream chips; legacy Bubblegum filled chips.
            b.filled = !compose
            b.inlineCaption = true
            b.paint()
            b.widthAnchor.constraint(equalToConstant: compose ? 52 : (compact ? 58 : 66)).isActive = true
            b.heightAnchor.constraint(equalToConstant: compose ? 22 : (compact ? 22 : 30)).isActive = true
            layersRow.addArrangedSubview(b)
        }
        layersRow.isHidden = model.layers.isEmpty
        layersScroll.isHidden = compose && model.layers.isEmpty
        if compose {
            layersRow.frame = NSRect(x: 0, y: 0, width: max(layersRow.fittingSize.width, Theme.current.composeColumnWidth), height: 22)
            layersScroll.documentView = layersRow
        }
        typedRowHidden = model.typed.isEmpty
        typedLabel.stringValue = model.typed.isEmpty ? "" : (compose ? model.typed + "▏" : "typing: \(model.typed)▏")
        typedRow.isHidden = compose ? typedRowHidden : false

        for (key, b) in cells {
            b.isEnabled = !(model.alphabet.subjoinedOnly.contains { $0.key == key } && model.layers.isEmpty)
            b.dimmed = b.isEnabled && !model.matches(key)
            b.filled = model.typedKey == key
            b.paint()
            if compose, b.filled { revealAlphabetCell(b) }
        }
        for (v, b) in vowelButtons { b.filled = v == model.vowel; b.paint() }
        for (m, b) in markButtons { b.filled = model.marks.contains(m); b.paint() }

        var shortest = "", canonical = "", codes = "", notes = "", shown = ""
        var previewInk = Theme.current.ink
        switch model.result {
        case .empty:
            shown = "ཀྵ"
            previewInk = Theme.current.ink.withAlphaComponent(0.25)
        case .built(let b):
            shown = b.text; shortest = b.shortest
            canonical = b.shortest == b.canonical ? "" : "full: \(b.canonical)"
            codes = b.codePoints
            notes = b.notes.prefix(2).joined(separator: "\n")
            previewInk = Theme.current.ink
        case .failed(let why):
            shown = "∅"; notes = why
            previewInk = Theme.current.ink.withAlphaComponent(0.25)
        }
        preview.stringValue = shown
        preview.textColor = previewInk
        stackPreview.text = shown
        stackPreview.ink = previewInk
        stackPreview.needsDisplay = true
        shortestLabel.stringValue = shortest
        canonicalLabel.stringValue = canonical
        codesLabel.stringValue = codes
        notesLabel.stringValue = notes
        let defaultHint = compose
            ? "Type a letter · Space adds · Return inserts · Esc closes"
            : "Type a letter, Space adds it, Return inserts, Esc closes."
        let hint = model.hint.isEmpty && model.result == .empty ? defaultHint : model.hint
        // Compact has no room for the notes in the card: a warning takes the hint's place.
        hintLabel.stringValue = compact && !notes.isEmpty ? notes.replacingOccurrences(of: "\n", with: " ") : hint
        hintLabel.toolTip = hintLabel.stringValue
        for l in [canonicalLabel, codesLabel, notesLabel] { l.isHidden = l.stringValue.isEmpty }
        // Brutalist keeps the type row slot for height stability; hide only its text when empty.
        if compose {
            typeRowView?.isHidden = false
            shortestLabel.stringValue = shortest.isEmpty ? " " : shortest
            if let typeRow = typeRowView as? NSStackView {
                for v in typeRow.arrangedSubviews where v !== shortestLabel {
                    v.isHidden = shortest.isEmpty
                }
            }
        } else {
            typeRowView?.isHidden = shortest.isEmpty
        }
        insertButton.isEnabled = model.built != nil
        copyButton.isEnabled = model.built != nil
        clearButton.isEnabled = !(model.layers.isEmpty && model.vowel.isEmpty && model.marks.isEmpty)
        insertButton.paint()
        copyButton.paint()
        clearButton.paint()
        // Re-fit preview inside fixed compose height with non-overlapping sibling regions.
        if compose {
            let t = Theme.current
            let layersH: CGFloat = model.layers.isEmpty ? 0 : 24
            let regionGap: CGFloat = t.bubblegum ? 10 : 4
            let typeH: CGFloat = t.bubblegum ? 28 : 18
            // gaps: (chips↔preview)? + preview↔type + type↔actions
            let gapCount: CGFloat = model.layers.isEmpty ? 2 : 3
            // chips + gaps + preview + type + actions = artH
            let residual = t.stackerArtHeight - layersH - typeH - t.actionButtonHeight - gapCount * regionGap
            previewHeight?.constant = max(64, residual)
            typeRowHeight?.constant = typeH
            stackPreview.nominalSize = t.previewNominalSize
            previewRow.arrange([stackPreview])
            if let typeRow = typeRowView as? NSStackView {
                typeRow.arrange([shortestLabel])
            }
            var regions: [NSView] = []
            if !model.layers.isEmpty { regions.append(layersScroll) }
            regions.append(contentsOf: [previewRow, typeRowView!, buttonsRow])
            cardStack.arrange(regions)
            cardStack.spacing = regionGap
            if !model.layers.isEmpty {
                cardStack.setCustomSpacing(regionGap, after: layersScroll)
            }
            cardStack.setCustomSpacing(regionGap, after: previewRow)
            cardStack.setCustomSpacing(regionGap, after: typeRowView!)
        }
        // Composition height is fixed; re-fit the scroll viewport after state changes.
        if compose, let panel = panel {
            // Hidden harness panels often keep a stale frame; use the tab height then.
            let h = panel.isVisible ? panel.frame.height : PanelTabs.height(for: .stacker)
            adaptLettersHeight(panelHeight: max(h, minimumHeight))
        }
        panel?.invalidateShadow()
    }

    // MARK: Position

    @objc private func panelMoved(_ note: Notification) {
        guard let panel = panel else { return }
        PanelTabs.save(panel, key: Self.originKey)
    }
}
