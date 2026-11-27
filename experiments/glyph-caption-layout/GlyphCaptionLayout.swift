import AppKit
import CoreText

/// Prototype layout helper for Tibetan glyph + Roman caption cells.
/// Intended future use from `BubbleButton` when the Brutalist theme is active.
/// Bubblegum should keep its existing fixed-offset NSTextField layout.
///
/// Measurement uses shaped `CTLine` ink via `CTLineGetImageBounds` (not the
/// typographic line box, and not per-codepoint paths — so Sanskrit stacks stay shaped).
enum GlyphCaptionLayout {
    struct InkEnvelope: Equatable {
        /// Max ink extent above the typographic baseline (Core Text y-up).
        var above: CGFloat
        /// Max ink extent below the typographic baseline (positive downward).
        var below: CGFloat
        var width: CGFloat
    }

    struct Spec {
        var cellSize: CGSize
        var glyphSize: CGFloat
        var captionSize: CGFloat
        /// Extra air between ink and caption band / cell edges.
        var pad: CGFloat = 2
        /// When true, centre the shared ink envelope in the glyph band (same baseline
        /// for every cell; only the vertical origin of that baseline moves as a set).
        var centerEnvelope: Bool = true
    }

    struct Plan {
        var captionBand: CGFloat
        var baselineY: CGFloat          // from cell bottom
        var envelope: InkEnvelope
        var fits: Bool
        var minCellHeight: CGFloat
    }

    static func didot(_ size: CGFloat) -> NSFont {
        NSFont(name: "Didot", size: size)
            ?? NSFont(name: "Georgia", size: size)
            ?? .systemFont(ofSize: size)
    }

    static func tibetan(_ size: CGFloat) -> NSFont {
        if let f = NSFont(name: "NotoSerifTibetan-Regular", size: size) { return f }
        return .systemFont(ofSize: size)
    }

    /// Shaped ink relative to the typographic baseline.
    static func inkBounds(for glyph: String, font: NSFont) -> CGRect {
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: glyph, attributes: [
            .font: font, .foregroundColor: NSColor.black,
        ]))
        var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
        let width = CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
        let w = max(ceil(width) + 80, 120)
        let h = max(ceil(ascent + descent) + 80, 120)
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(w * 2), pixelsHigh: Int(h * 2),
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else {
            return .zero
        }
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
        for g in glyphs {
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

    /// Minimum cell height that fits the envelope + caption band + padding.
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
        let baseline: CGFloat
        if spec.centerEnvelope, slack > 0 {
            baseline = band + spec.pad + envelope.below + slack / 2
        } else {
            baseline = band + spec.pad + envelope.below
        }
        return Plan(captionBand: band, baselineY: baseline, envelope: envelope,
                    fits: slack >= 0, minCellHeight: minH)
    }

    /// Baseline origin for one cell (AppKit y-up, cell origin bottom-left).
    static func baselinePoint(for glyph: String, font: NSFont, cellWidth: CGFloat, baselineY: CGFloat) -> CGPoint {
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: glyph, attributes: [.font: font]))
        var a: CGFloat = 0, d: CGFloat = 0, l: CGFloat = 0
        let w = CTLineGetTypographicBounds(line, &a, &d, &l)
        return CGPoint(x: (cellWidth - w) / 2, y: baselineY)
    }
}
