import Cocoa
import CoreText

/// Fixed-size Tibetan stack preview for the Brutalist composition column.
/// Shapes the full string as one CTLine, measures ink with `CTLineGetImageBounds`,
/// and scales the font down until the ink fits — so tall Sanskrit stacks never clip
/// and never change the surrounding layout.
final class StackPreviewView: NSView {
    var text = "" {
        didSet { if text != oldValue { needsDisplay = true } }
    }
    var ink = NSColor.black {
        didSet { needsDisplay = true }
    }
    /// Starting point size; reduced only when ink would overflow.
    var nominalSize: CGFloat = 56
    var pad: CGFloat = 4

    /// Last fitted point size (for diagnostics).
    private(set) var fittedSize: CGFloat = 52
    /// Last measured ink size at the fitted point size.
    private(set) var fittedInk: CGSize = .zero

    override var isOpaque: Bool { false }
    override var isFlipped: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        guard !text.isEmpty, let ctx = NSGraphicsContext.current?.cgContext else { return }
        let area = bounds.insetBy(dx: pad, dy: pad)
        guard area.width > 4, area.height > 4 else { return }

        var lo: CGFloat = 10
        var hi = nominalSize
        var best = lo
        for _ in 0..<12 {
            let mid = (lo + hi) / 2
            let inkSize = measureInk(text, size: mid)
            if inkSize.width <= area.width && inkSize.height <= area.height {
                best = mid
                lo = mid
            } else {
                hi = mid
            }
        }
        // Final check at `best` (binary search leaves a slight gap).
        var inkSize = measureInk(text, size: best)
        while (inkSize.width > area.width || inkSize.height > area.height) && best > 10 {
            best -= 0.5
            inkSize = measureInk(text, size: best)
        }
        fittedSize = best
        fittedInk = inkSize

        let font = TibetanFont.font(best)
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [
            .font: font, .foregroundColor: ink,
        ]))
        let image = CTLineGetImageBounds(line, ctx)
        // Centre ink optically; bias downward so the placeholder sits nearer the actions.
        let slack = max(0, area.height - inkSize.height)
        let opticalDown = min(slack * 0.42, max(6, slack * 0.35))
        let originX = area.midX - image.midX
        let originY = area.midY - image.midY - opticalDown
        ctx.saveGState()
        ctx.textMatrix = .identity
        ctx.translateBy(x: originX, y: originY)
        CTLineDraw(line, ctx)
        ctx.restoreGState()
    }

    private func measureInk(_ s: String, size: CGFloat) -> CGSize {
        let font = TibetanFont.font(size)
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: s, attributes: [
            .font: font, .foregroundColor: NSColor.black,
        ]))
        // Offscreen context so image bounds are meaningful.
        let w = max(ceil(size * 8), 120)
        let h = max(ceil(size * 6), 120)
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
        ctx.translateBy(x: w / 2, y: h / 2)
        let b = CTLineGetImageBounds(line, ctx)
        return CGSize(width: ceil(b.width), height: ceil(b.height))
    }
}
