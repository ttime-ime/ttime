import AppKit
import CoreText

/// Shared-baseline layout for Tibetan glyph + Roman caption cells (Brutalist).
/// Measures shaped `CTLine` ink via `CTLineGetImageBounds` so Sanskrit stacks stay intact.
enum GlyphCaptionLayout {
    struct InkEnvelope: Equatable {
        /// Max ink above the typographic baseline (Core Text y-up).
        var above: CGFloat
        /// Max ink below the baseline (positive downward).
        var below: CGFloat
        var width: CGFloat
    }

    struct Spec {
        var cellSize: CGSize
        var glyphSize: CGFloat
        var captionSize: CGFloat
        var pad: CGFloat = 2
        var centerEnvelope: Bool = true
    }

    struct Plan {
        var captionBand: CGFloat
        /// Baseline Y from the cell's bottom edge (AppKit y-up).
        var baselineY: CGFloat
        var envelope: InkEnvelope
        var fits: Bool
        var minCellHeight: CGFloat
    }

    /// Which inventory's cached envelope a cell should use.
    enum Inventory {
        /// Full stacker inventory (legacy / complex stress).
        case stacker
        /// Ordinary consonants: smaller envelope → tighter glyph–caption clearance.
        case stackerConsonant
        /// Vowels, marks, subjoined tiles.
        case stackerTile
        case symbols
    }

    private static var stackerEnvelope: InkEnvelope?
    private static var stackerConsonantEnvelope: InkEnvelope?
    private static var stackerTileEnvelope: InkEnvelope?
    private static var symbolsEnvelope: InkEnvelope?

    static func didot(_ size: CGFloat) -> NSFont {
        NSFont(name: "Didot", size: size)
            ?? NSFont(name: "Georgia", size: size)
            ?? .systemFont(ofSize: size)
    }

    static func tibetan(_ size: CGFloat) -> NSFont {
        TibetanFont.font(size)
    }

    static func inkBounds(for glyph: String, font: NSFont) -> CGRect {
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: glyph, attributes: [
            .font: font, .foregroundColor: NSColor.black,
        ]))
        var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
        let width = CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
        let w = max(ceil(width) + 80, 120)
        let h = max(ceil(ascent + descent) + 80, 120)
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(w * 2), pixelsHigh: Int(h * 2),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return .zero }
        rep.size = NSSize(width: w, height: h)
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        guard let gc = NSGraphicsContext(bitmapImageRep: rep) else { return .zero }
        NSGraphicsContext.current = gc
        let ctx = gc.cgContext
        ctx.scaleBy(x: 2, y: 2)
        ctx.textMatrix = .identity
        ctx.translateBy(x: 40, y: descent + 20)
        return CTLineGetImageBounds(line, ctx)
    }

    static func envelope(glyphs: [String], glyphSize: CGFloat) -> InkEnvelope {
        let font = tibetan(glyphSize)
        var above: CGFloat = 0, below: CGFloat = 0, width: CGFloat = 0
        for g in glyphs where !g.isEmpty {
            let b = inkBounds(for: g, font: font)
            above = max(above, b.maxY)
            below = max(below, -b.minY)
            width = max(width, b.width)
        }
        return InkEnvelope(above: above, below: below, width: width)
    }

    static func captionBandHeight(captionSize: CGFloat, pad: CGFloat) -> CGFloat {
        let font = didot(captionSize)
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: "rgya", attributes: [.font: font]))
        var a: CGFloat = 0, d: CGFloat = 0, l: CGFloat = 0
        _ = CTLineGetTypographicBounds(line, &a, &d, &l)
        return ceil(a + d + l + pad + 1)
    }

    static func minCellHeight(envelope: InkEnvelope, captionSize: CGFloat, pad: CGFloat = 2) -> CGFloat {
        let band = captionBandHeight(captionSize: captionSize, pad: pad)
        return ceil(band + envelope.above + envelope.below + 2 * pad)
    }

    static func plan(spec: Spec, envelope: InkEnvelope) -> Plan {
        let band = captionBandHeight(captionSize: spec.captionSize, pad: spec.pad)
        let minH = minCellHeight(envelope: envelope, captionSize: spec.captionSize, pad: spec.pad)
        let glyphBand = spec.cellSize.height - band
        let need = envelope.above + envelope.below + 2 * spec.pad
        let slack = glyphBand - need
        // Bias slack upward (28% below the envelope instead of 50%) so ordinary consonants
        // sit closer to their captions while tall Sanskrit stacks keep ≥ pad clearance.
        let baseline: CGFloat
        if spec.centerEnvelope, slack > 0 {
            baseline = band + spec.pad + envelope.below + slack * 0.28
        } else {
            baseline = band + spec.pad + envelope.below
        }
        return Plan(captionBand: band, baselineY: baseline, envelope: envelope,
                    fits: slack >= 0, minCellHeight: minH)
    }

    static func baselineX(for glyph: String, font: NSFont, cellWidth: CGFloat) -> CGFloat {
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: glyph, attributes: [.font: font]))
        var a: CGFloat = 0, d: CGFloat = 0, l: CGFloat = 0
        let w = CTLineGetTypographicBounds(line, &a, &d, &l)
        return (cellWidth - w) / 2
    }

    /// Cache envelopes for the live alphabets (call once when a panel builds).
    static func warmStacker(alphabet: StackAlphabet, glyphSize: CGFloat) {
        let consonants = alphabet.consonants.map(\.example)
        let subjoined = alphabet.subjoinedOnly.map(\.example)
        let tiles = alphabet.vowels.map(\.example) + alphabet.marks.map(\.example) + subjoined
        // Stress strings beyond single-letter examples (full envelope).
        let stress = ["རྒྱ", "རྒྱི", "རྒྱུ", "བརྒྱ", "སྟྲི", "ཀྵ", "ཀྵི", "ཀྵཻ", "ཀྵཽ", "རྐྱཻ", "ཨཻ", "ཨཽ"]
        stackerEnvelope = envelope(glyphs: consonants + tiles + stress, glyphSize: glyphSize)
        // Ordinary consonants only — drops tall Sanskrit stacks from the clearance budget.
        stackerConsonantEnvelope = envelope(glyphs: consonants + ["ཀ", "ཁ", "ག", "ང", "ཅ", "ཏ", "པ", "མ", "ཡ", "ར", "ལ", "ཤ", "ས", "ཧ"],
                                            glyphSize: glyphSize)
        stackerTileEnvelope = envelope(glyphs: tiles + ["ཀི", "ཀུ", "ཀེ", "ཀོ", "ཀཱ", "ཀྃ", "ཀཿ"], glyphSize: glyphSize)
    }

    static func warmSymbols(entries: [SymbolEntry], glyphSize: CGFloat) {
        let glyphs = entries.map(\.display)
        symbolsEnvelope = envelope(glyphs: glyphs, glyphSize: glyphSize)
    }

    static func cached(_ inventory: Inventory) -> InkEnvelope? {
        switch inventory {
        case .stacker: return stackerEnvelope
        case .stackerConsonant: return stackerConsonantEnvelope ?? stackerEnvelope
        case .stackerTile: return stackerTileEnvelope ?? stackerEnvelope
        case .symbols: return symbolsEnvelope
        }
    }

    static func clearCaches() {
        stackerEnvelope = nil
        stackerConsonantEnvelope = nil
        stackerTileEnvelope = nil
        symbolsEnvelope = nil
    }
}
