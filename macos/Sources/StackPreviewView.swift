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

    override func viewDidChangeEffectiveAppearance() { needsDisplay = true }
    override func viewDidMoveToWindow() { needsDisplay = true }

    override func draw(_ dirtyRect: NSRect) {
        let t = Theme.current
        // Cream display case for Bubblegum; clear for Brutalist.
        if t.bubblegum {
            let path = NSBezierPath(roundedRect: bounds, xRadius: 16, yRadius: 16)
            t.surface.setFill()
            path.fill()
            t.controlBorder.setStroke()
            path.lineWidth = 1
            path.stroke()
        }
        guard !text.isEmpty, let ctx = NSGraphicsContext.current?.cgContext else { return }
        let area = bounds.insetBy(dx: pad + (t.bubblegum ? 4 : 0), dy: pad + (t.bubblegum ? 4 : 0))
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
        // Ink bounds relative to the typographic origin (baseline at 0,0), measured offscreen.
        let inkRect = measureInkRect(text, size: best)
        let slack = max(0, area.height - inkRect.height)
        // Bubblegum: slight optical lift so stacks don't sit heavy in the cream case.
        // Brutalist: bias down toward the typographic weight of Tibetan stacks.
        let opticalDown: CGFloat
        if t.bubblegum {
            opticalDown = -min(8, max(3, slack * 0.08))
        } else {
            opticalDown = min(slack * 0.42, max(6, slack * 0.35))
        }
        // Place typographic origin so the ink rectangle's centre sits on the area centre.
        let originX = area.midX - inkRect.midX
        let originY = area.midY - opticalDown - inkRect.midY
        ctx.saveGState()
        ctx.textMatrix = .identity
        ctx.translateBy(x: originX, y: originY)
        CTLineDraw(line, ctx)
        ctx.restoreGState()
    }

    /// Ink image bounds relative to baseline origin (0,0) in an identity CTM.
    private func measureInkRect(_ s: String, size: CGFloat) -> CGRect {
        let font = TibetanFont.font(size)
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: s, attributes: [
            .font: font, .foregroundColor: NSColor.black,
        ]))
        let w = max(ceil(size * 8), 160)
        let h = max(ceil(size * 6), 160)
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
        // Baseline at a known point; return bounds relative to that point.
        let ox = w * 0.5, oy = h * 0.45
        ctx.translateBy(x: ox, y: oy)
        let b = CTLineGetImageBounds(line, ctx)
        return CGRect(x: b.minX, y: b.minY, width: b.width, height: b.height)
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
