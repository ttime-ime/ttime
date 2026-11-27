#!/usr/bin/env swift
/// Glyph/caption layout experiment for T-Time BubbleButton.
/// Measures Core Text typographic bounds vs ink (image) bounds for Noto Serif Tibetan,
/// prototypes several placement strategies, and writes PNG comparison sheets + JSON metrics.
///
/// Does not modify the IME app. Run:
///   cd experiments/glyph-caption-layout && swift measure_and_render.swift

import AppKit
import CoreText
import Foundation

// MARK: - Setup

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let outDir = root.appendingPathComponent("out", isDirectory: true)
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let fontURL = root
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("macos/Resources/NotoSerifTibetan.ttf")
precondition(CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil),
             "Could not register \(fontURL.path)")

func tibetan(_ size: CGFloat) -> NSFont {
    NSFont(name: "NotoSerifTibetan-Regular", size: size)!
}
func didot(_ size: CGFloat) -> NSFont {
    NSFont(name: "Didot", size: size)
        ?? NSFont(name: "Georgia", size: size)
        ?? .systemFont(ofSize: size)
}
func mono(_ size: CGFloat) -> NSFont {
    .monospacedSystemFont(ofSize: size, weight: .medium)
}

// MARK: - Samples

struct Sample: Codable {
    let key: String
    let glyph: String
    let kind: String  // ordinary | vowelish | stack | sanskrit
}

let samples: [Sample] = [
    Sample(key: "ka", glyph: "ཀ", kind: "ordinary"),
    Sample(key: "kha", glyph: "ཁ", kind: "ordinary"),
    Sample(key: "nga", glyph: "ང", kind: "ordinary"),
    Sample(key: "ya", glyph: "ཡ", kind: "ordinary"),
    Sample(key: "ra", glyph: "ར", kind: "ordinary"),
    Sample(key: "ha", glyph: "ཧ", kind: "ordinary"),
    Sample(key: "a+i", glyph: "ཨི", kind: "vowelish"),
    Sample(key: "a+u", glyph: "ཨུ", kind: "vowelish"),
    Sample(key: "a+o", glyph: "ཨོ", kind: "vowelish"),
    Sample(key: "a+ai", glyph: "ཨཻ", kind: "vowelish"),
    Sample(key: "a+au", glyph: "ཨཽ", kind: "vowelish"),
    Sample(key: "a+A", glyph: "ཨཱ", kind: "vowelish"),
    Sample(key: "rgya", glyph: "རྒྱ", kind: "stack"),
    Sample(key: "rgya+i", glyph: "རྒྱི", kind: "stack"),
    Sample(key: "rgyu", glyph: "རྒྱུ", kind: "stack"),
    Sample(key: "brgya", glyph: "བརྒྱ", kind: "stack"),
    Sample(key: "stri", glyph: "སྟྲི", kind: "stack"),
    Sample(key: "ksa", glyph: "ཀྵ", kind: "sanskrit"),
    Sample(key: "ksi", glyph: "ཀྵི", kind: "sanskrit"),
    Sample(key: "ksai", glyph: "ཀྵཻ", kind: "sanskrit"),
    Sample(key: "ksau", glyph: "ཀྵཽ", kind: "sanskrit"),
    Sample(key: "hPha", glyph: "ཧྵ", kind: "sanskrit"),
    Sample(key: "rkyai", glyph: "རྐྱཻ", kind: "sanskrit"),
    Sample(key: "tra", glyph: "ཏྲ", kind: "stack"),
    Sample(key: "gya", glyph: "གྱ", kind: "stack"),
]

// MARK: - Metrics

struct InkMetrics: Codable {
    let glyph: String
    let key: String
    let kind: String
    let size: CGFloat
    let typoAscent: CGFloat
    let typoDescent: CGFloat   // positive downward extent
    let typoLeading: CGFloat
    let typoWidth: CGFloat
    let typoLineHeight: CGFloat
    /// Ink relative to typographic baseline: y grows up (Core Text).
    let inkMinX: CGFloat
    let inkMaxX: CGFloat
    let inkMinY: CGFloat  // typically negative (below baseline)
    let inkMaxY: CGFloat  // above baseline
    let inkWidth: CGFloat
    let inkHeight: CGFloat
    let fontAscender: CGFloat
    let fontDescender: CGFloat  // negative in NSFont
    let fontLineHeight: CGFloat
}

/// Measure shaped run: typographic bounds + ink via CTLineGetImageBounds.
func measure(sample: Sample, size: CGFloat) -> InkMetrics {
    let font = tibetan(size)
    let attr = NSAttributedString(string: sample.glyph, attributes: [
        .font: font,
        .foregroundColor: NSColor.black,
    ])
    let line = CTLineCreateWithAttributedString(attr)

    var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
    let width = CTLineGetTypographicBounds(line, &ascent, &descent, &leading)

    // Image bounds need a context; origin is typographic baseline.
    let img = NSImage(size: NSSize(width: max(width, 1) + 80, height: ascent + descent + 80), flipped: false) { rect in
        guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
        ctx.translateBy(x: 40, y: descent + 40)
        CTLineDraw(line, ctx)
        return true
    }
    // Re-measure ink with an explicit context (same transform idea).
    let ink: CGRect = {
        let w = max(ceil(width) + 100, 200)
        let h = max(ceil(ascent + descent) + 100, 200)
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(w * 2), pixelsHigh: Int(h * 2),
                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        rep.size = NSSize(width: w, height: h)
        NSGraphicsContext.saveGraphicsState()
        let gc = NSGraphicsContext(bitmapImageRep: rep)!
        NSGraphicsContext.current = gc
        let ctx = gc.cgContext
        ctx.scaleBy(x: 2, y: 2) // retina-ish for stable bounds; image bounds in user space
        // User space: baseline at (50, descent+20)
        let baselineY = descent + 20
        ctx.textMatrix = .identity
        ctx.translateBy(x: 50, y: baselineY)
        let bounds = CTLineGetImageBounds(line, ctx)
        NSGraphicsContext.restoreGraphicsState()
        // bounds are in the translated user space (origin = baseline)
        return bounds
    }()

    _ = img // keep draw path warm / available for debugging

    return InkMetrics(
        glyph: sample.glyph, key: sample.key, kind: sample.kind, size: size,
        typoAscent: ascent, typoDescent: descent, typoLeading: leading, typoWidth: width,
        typoLineHeight: ascent + descent + leading,
        inkMinX: ink.minX, inkMaxX: ink.maxX, inkMinY: ink.minY, inkMaxY: ink.maxY,
        inkWidth: ink.width, inkHeight: ink.height,
        fontAscender: font.ascender, fontDescender: font.descender,
        fontLineHeight: font.ascender - font.descender + font.leading
    )
}

// MARK: - Layout strategies

enum Strategy: String, CaseIterable, Codable {
    case currentFixed       // BubbleButton today: glyph centerY-4, caption bottom-3
    case typoPack           // stack typographic line box above caption band
    case inkCenterEach      // centre each glyph's ink in the glyph band (per-cell)
    case sharedBaselineInk  // shared baseline pinned above caption band
    case sharedBaselineCentered // shared baseline; whole ink envelope centred in glyph band
}

struct LayoutPlan: Codable {
    let strategy: String
    let cellW: CGFloat
    let cellH: CGFloat
    let glyphSize: CGFloat
    let captionSize: CGFloat
    let captionBand: CGFloat
    let glyphBand: CGFloat
    let pad: CGFloat
    /// Baseline Y from cell bottom (AppKit y-up within cell).
    let baselineY: CGFloat
    let captionBaselineY: CGFloat
    let maxInkAbove: CGFloat
    let maxInkBelow: CGFloat
    let worstClearance: CGFloat  // min gap between ink bottom and caption top across samples; negative = overlap
    let fitsAll: Bool
    let notes: String
}

struct CellDraw {
    let sample: Sample
    let metrics: InkMetrics
    /// Where to draw the CTLine: baseline point in cell coordinates (origin bottom-left).
    let baseline: CGPoint
    let captionOrigin: CGPoint  // bottom-left of caption label frame
    let captionSize: CGSize
    let inkFrame: CGRect        // ink in cell coords
    let clearance: CGFloat      // ink.minY - caption.maxY; negative = overlap
}

func captionMetrics(font: NSFont, text: String) -> (lineH: CGFloat, width: CGFloat, ascent: CGFloat, descent: CGFloat) {
    let attr = NSAttributedString(string: text, attributes: [.font: font])
    let line = CTLineCreateWithAttributedString(attr)
    var a: CGFloat = 0, d: CGFloat = 0, l: CGFloat = 0
    let w = CTLineGetTypographicBounds(line, &a, &d, &l)
    return (a + d + l, w, a, d)
}

/// Shared worst-case ink extents at a glyph size (relative to Tibetan baseline).
func envelope(at size: CGFloat) -> (above: CGFloat, below: CGFloat, width: CGFloat) {
    var above: CGFloat = 0, below: CGFloat = 0, width: CGFloat = 0
    for s in samples {
        let m = measure(sample: s, size: size)
        above = max(above, m.inkMaxY)
        below = max(below, -m.inkMinY)
        width = max(width, m.inkWidth)
    }
    return (above, below, width)
}

func planLayout(strategy: Strategy, cellW: CGFloat, cellH: CGFloat,
                glyphSize: CGFloat, captionSize: CGFloat) -> (LayoutPlan, [CellDraw]) {
    let capFont = didot(captionSize)
    let pad: CGFloat = 2
    let capSample = captionMetrics(font: capFont, text: "rgya")
    // Caption band: padding + typographic caption height + padding under
    let captionBand = ceil(capSample.lineH + pad + 1)  // +1 optical air under letters
    let env = envelope(at: glyphSize)

    var baselineY: CGFloat = 0
    var glyphBand: CGFloat = 0
    var notes = ""

    switch strategy {
    case .currentFixed:
        // Match BubbleButton: glyph NSTextField centered at mid-4; we emulate by
        // placing typographic centre of the font line box at mid-4.
        let mid = cellH / 2
        let font = tibetan(glyphSize)
        // NSTextField centers its frame; frame height ≈ typo line height.
        // Approximate: baseline = centerY - (typo line mid offset from baseline).
        // For Noto, centre of [descender, ascender] relative to baseline:
        let lineMidFromBaseline = (font.ascender + font.descender) / 2  // descender negative
        baselineY = (mid - 4) - lineMidFromBaseline
        glyphBand = cellH - 3 - captionBand  // notational
        notes = "Emulates centerY-4 + bottom-3; uses typographic centre, not ink."

    case .typoPack:
        // Caption sits in bottom band; Tibetan baseline sits so full typo descent
        // clears caption, and typo ascent fits in remaining space if possible.
        let font = tibetan(glyphSize)
        let typoBelow = -font.descender
        baselineY = captionBand + pad + typoBelow
        glyphBand = cellH - captionBand
        notes = "Uses font ascender/descender line box (often taller than ink)."

    case .inkCenterEach:
        // Band above caption; each glyph's ink centred in that band (baselines wander).
        glyphBand = cellH - captionBand
        baselineY = captionBand + glyphBand / 2  // placeholder; per-cell in draw
        notes = "Per-cell ink centring — compact but baselines will not align across the row."

    case .sharedBaselineInk, .sharedBaselineCentered:
        // Reserve caption band; place a shared baseline from the max ink envelope.
        let need = env.above + env.below + 2 * pad
        glyphBand = cellH - captionBand
        let slack = glyphBand - need
        if strategy == .sharedBaselineCentered, slack > 0 {
            baselineY = captionBand + pad + env.below + slack / 2
            notes = "Shared baseline; ink envelope centred in glyph band (slack \(String(format: "%.1f", slack))pt)."
        } else {
            baselineY = captionBand + pad + env.below
            notes = "Shared baseline pinned above caption; band from max ink envelope."
        }
        if need > glyphBand {
            notes += " WARNING: need \(String(format: "%.1f", need))pt for ink+pad but glyphBand=\(String(format: "%.1f", glyphBand))."
        }
    }

    let captionBaselineY = pad + capSample.descent  // sitting on bottom padding

    var draws: [CellDraw] = []
    var worstClearance = CGFloat.greatestFiniteMagnitude

    for s in samples {
        let m = measure(sample: s, size: glyphSize)
        let cap = captionMetrics(font: capFont, text: s.key)
        let capW = min(cap.width, cellW - 2)
        let capH = cap.lineH
        let capX = (cellW - capW) / 2
        let capY: CGFloat = 1  // match ~ bottom-3 optical: small pad
        // For currentFixed, caption bottom is at 3 from cell bottom → frame y = 3 if height intrinsic…
        // BubbleButton uses bottomAnchor -3, so caption frame.minY ≈ 3.
        let captionOrigin: CGPoint
        let baseline: CGPoint

        switch strategy {
        case .currentFixed:
            captionOrigin = CGPoint(x: capX, y: 3)
            let font = tibetan(glyphSize)
            let lineMidFromBaseline = (font.ascender + font.descender) / 2
            let by = (cellH / 2 - 4) - lineMidFromBaseline
            let bx = (cellW - m.typoWidth) / 2
            baseline = CGPoint(x: bx, y: by)

        case .typoPack:
            captionOrigin = CGPoint(x: capX, y: (captionBand - capH) / 2)
            let font = tibetan(glyphSize)
            let by = captionBand + pad + (-font.descender)
            let bx = (cellW - m.typoWidth) / 2
            baseline = CGPoint(x: bx, y: by)

        case .inkCenterEach:
            captionOrigin = CGPoint(x: capX, y: (captionBand - capH) / 2)
            let bandMid = captionBand + (cellH - captionBand) / 2
            let inkMidFromBaseline = (m.inkMinY + m.inkMaxY) / 2
            let by = bandMid - inkMidFromBaseline
            let bx = (cellW - m.inkWidth) / 2 - m.inkMinX
            baseline = CGPoint(x: bx, y: by)

        case .sharedBaselineInk, .sharedBaselineCentered:
            captionOrigin = CGPoint(x: capX, y: (captionBand - capH) / 2)
            let bx = (cellW - m.typoWidth) / 2
            baseline = CGPoint(x: bx, y: baselineY)
        }

        let inkFrame = CGRect(x: baseline.x + m.inkMinX,
                              y: baseline.y + m.inkMinY,
                              width: m.inkWidth, height: m.inkHeight)
        let capFrame = CGRect(x: captionOrigin.x, y: captionOrigin.y, width: capW, height: capH)
        let clearance = inkFrame.minY - capFrame.maxY
        worstClearance = min(worstClearance, clearance)

        draws.append(CellDraw(sample: s, metrics: m, baseline: baseline,
                              captionOrigin: captionOrigin,
                              captionSize: CGSize(width: capW, height: capH),
                              inkFrame: inkFrame, clearance: clearance))
    }

    let topClip = draws.map { cellH - ($0.inkFrame.maxY) }.min() ?? 0
    let fits = worstClearance >= 0 && topClip >= 0

    let plan = LayoutPlan(
        strategy: strategy.rawValue, cellW: cellW, cellH: cellH,
        glyphSize: glyphSize, captionSize: captionSize, captionBand: captionBand,
        glyphBand: cellH - captionBand, pad: pad, baselineY: baselineY,
        captionBaselineY: captionBaselineY, maxInkAbove: env.above, maxInkBelow: env.below,
        worstClearance: worstClearance, fitsAll: fits, notes: notes
    )
    return (plan, draws)
}

// MARK: - Drawing

func drawSheet(title: String, strategy: Strategy, cellW: CGFloat, cellH: CGFloat,
               glyphSize: CGFloat, captionSize: CGFloat, showGuides: Bool) -> NSImage {
    let (plan, draws) = planLayout(strategy: strategy, cellW: cellW, cellH: cellH,
                                   glyphSize: glyphSize, captionSize: captionSize)
    let cols = 5
    let rows = Int(ceil(Double(draws.count) / Double(cols)))
    let gap: CGFloat = 10
    let header: CGFloat = 52
    let footer: CGFloat = 36
    let width = CGFloat(cols) * cellW + CGFloat(cols + 1) * gap
    let height = header + footer + CGFloat(rows) * cellH + CGFloat(rows + 1) * gap

    let image = NSImage(size: NSSize(width: width, height: height))
    image.lockFocus()
    defer { image.unlockFocus() }

    NSColor.white.setFill()
    NSRect(origin: .zero, size: image.size).fill()

    let titleAttr: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
        .foregroundColor: NSColor.black,
    ]
    let subAttr: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .regular),
        .foregroundColor: NSColor.darkGray,
    ]
    (title as NSString).draw(at: NSPoint(x: gap, y: height - 22), withAttributes: titleAttr)
    let summary = String(
        format: "%@ | cell %.0f×%.0f | glyph %.0f | Didot %.0f | captionBand %.1f | maxInk ↑%.1f ↓%.1f | worstClearance %.1f | %@",
        strategy.rawValue, cellW, cellH, glyphSize, captionSize, plan.captionBand,
        plan.maxInkAbove, plan.maxInkBelow, plan.worstClearance, plan.fitsAll ? "FITS" : "OVERFLOW"
    )
    (summary as NSString).draw(at: NSPoint(x: gap, y: height - 40), withAttributes: subAttr)
    (plan.notes as NSString).draw(at: NSPoint(x: gap, y: 12), withAttributes: subAttr)

    let capFont = didot(captionSize)
    let glyphFont = tibetan(glyphSize)

    for (i, d) in draws.enumerated() {
        let col = i % cols
        let row = i / cols
        let ox = gap + CGFloat(col) * (cellW + gap)
        let oy = footer + gap + CGFloat(rows - 1 - row) * (cellH + gap)

        // Cell background
        let cell = NSRect(x: ox, y: oy, width: cellW, height: cellH)
        NSColor(white: 0.96, alpha: 1).setFill()
        cell.fill()
        NSColor(white: 0.75, alpha: 1).setStroke()
        let path = NSBezierPath(roundedRect: cell, xRadius: 6, yRadius: 6)
        path.lineWidth = 1
        path.stroke()

        if showGuides {
            // Caption band
            NSColor.systemOrange.withAlphaComponent(0.12).setFill()
            NSRect(x: ox, y: oy, width: cellW, height: plan.captionBand).fill()
            // Ink rect
            NSColor.systemBlue.withAlphaComponent(0.18).setFill()
            NSRect(x: ox + d.inkFrame.minX, y: oy + d.inkFrame.minY,
                   width: d.inkFrame.width, height: d.inkFrame.height).fill()
            // Baseline
            NSColor.systemRed.withAlphaComponent(0.7).setStroke()
            let bl = NSBezierPath()
            bl.move(to: NSPoint(x: ox + 2, y: oy + d.baseline.y))
            bl.line(to: NSPoint(x: ox + cellW - 2, y: oy + d.baseline.y))
            bl.lineWidth = 0.6
            bl.stroke()
        }

        // Glyph (shaped)
        let gAttr: [NSAttributedString.Key: Any] = [
            .font: glyphFont, .foregroundColor: NSColor.black,
        ]
        let gLine = CTLineCreateWithAttributedString(NSAttributedString(string: d.sample.glyph, attributes: gAttr))
        if let ctx = NSGraphicsContext.current?.cgContext {
            ctx.saveGState()
            ctx.textMatrix = .identity
            ctx.translateBy(x: ox + d.baseline.x, y: oy + d.baseline.y)
            CTLineDraw(gLine, ctx)
            ctx.restoreGState()
        }

        // Caption
        let cAttr: [NSAttributedString.Key: Any] = [
            .font: capFont, .foregroundColor: NSColor.black.withAlphaComponent(0.75),
        ]
        (d.sample.key as NSString).draw(
            in: NSRect(x: ox + d.captionOrigin.x, y: oy + d.captionOrigin.y,
                       width: d.captionSize.width, height: d.captionSize.height),
            withAttributes: cAttr)

        // Tiny clearance badge
        let badge = String(format: "%.0f", d.clearance)
        let badgeColor: NSColor = d.clearance >= 1 ? .systemGreen
            : (d.clearance >= 0 ? .systemOrange : .systemRed)
        let bAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 8, weight: .medium),
            .foregroundColor: badgeColor,
        ]
        (badge as NSString).draw(at: NSPoint(x: ox + 3, y: oy + cellH - 12), withAttributes: bAttr)

        // Clip warning if ink outside cell
        if d.inkFrame.minY < 0 || d.inkFrame.maxY > cellH || d.inkFrame.minX < 0 || d.inkFrame.maxX > cellW {
            NSColor.systemRed.withAlphaComponent(0.35).setStroke()
            let warn = NSBezierPath(rect: cell.insetBy(dx: 1, dy: 1))
            warn.lineWidth = 2
            warn.stroke()
        }
    }

    return image
}

func savePNG(_ image: NSImage, name: String) {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let data = rep.representation(using: .png, properties: [:]) else { return }
    let url = outDir.appendingPathComponent(name)
    try? data.write(to: url)
    print("wrote \(url.path)")
}

// MARK: - Bubblegum control strip (prove we do not change its metrics path)

func drawBubblegumControl() -> NSImage {
    // Bubblegum uses monospaced 9 captions and cream/plum cells — same fixed offsets.
    let cellW: CGFloat = 38, cellH: CGFloat = 38, glyphSize: CGFloat = 15
    let capFont = mono(9)
    let subset = Array(samples.prefix(10))
    let gap: CGFloat = 8
    let width = gap + CGFloat(subset.count) * (cellW + gap)
    let height: CGFloat = 80
    let image = NSImage(size: NSSize(width: width, height: height))
    image.lockFocus()
    defer { image.unlockFocus() }
    NSColor(srgbRed: 0xFC/255, green: 0xE7/255, blue: 0xE9/255, alpha: 1).setFill()
    NSRect(origin: .zero, size: image.size).fill()
    ("Bubblegum control — fixed offsets, mono 9 captions (unchanged path)" as NSString)
        .draw(at: NSPoint(x: gap, y: 58), withAttributes: [
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: NSColor(srgbRed: 0xA8/255, green: 0x44/255, blue: 0x5F/255, alpha: 1),
        ])
    for (i, s) in subset.enumerated() {
        let ox = gap + CGFloat(i) * (cellW + gap)
        let oy: CGFloat = 10
        let cell = NSRect(x: ox, y: oy, width: cellW, height: cellH)
        NSColor(srgbRed: 0xFE/255, green: 0xE8/255, blue: 0xD4/255, alpha: 0.85).setFill()
        NSBezierPath(roundedRect: cell, xRadius: 12, yRadius: 12).fill()
        NSColor(srgbRed: 0xEA/255, green: 0x87/255, blue: 0x98/255, alpha: 1).setStroke()
        let bp = NSBezierPath(roundedRect: cell, xRadius: 12, yRadius: 12)
        bp.lineWidth = 1.5
        bp.stroke()

        let m = measure(sample: s, size: glyphSize)
        let font = tibetan(glyphSize)
        let lineMidFromBaseline = (font.ascender + font.descender) / 2
        let by = (cellH / 2 - 4) - lineMidFromBaseline
        let bx = (cellW - m.typoWidth) / 2
        let gLine = CTLineCreateWithAttributedString(NSAttributedString(string: s.glyph, attributes: [
            .font: font,
            .foregroundColor: NSColor(srgbRed: 0xA8/255, green: 0x44/255, blue: 0x5F/255, alpha: 1),
        ]))
        if let ctx = NSGraphicsContext.current?.cgContext {
            ctx.saveGState()
            ctx.translateBy(x: ox + bx, y: oy + by)
            CTLineDraw(gLine, ctx)
            ctx.restoreGState()
        }
        let cap = captionMetrics(font: capFont, text: s.key)
        (s.key as NSString).draw(
            in: NSRect(x: ox + (cellW - cap.width) / 2, y: oy + 3, width: cap.width, height: cap.lineH),
            withAttributes: [
                .font: capFont,
                .foregroundColor: NSColor(srgbRed: 0xA8/255, green: 0x44/255, blue: 0x5F/255, alpha: 0.75),
            ])
    }
    return image
}

// MARK: - Sweep + JSON

struct SweepRow: Codable {
    let strategy: String
    let cellH: CGFloat
    let captionSize: CGFloat
    let glyphSize: CGFloat
    let captionBand: CGFloat
    let maxInkAbove: CGFloat
    let maxInkBelow: CGFloat
    let inkNeed: CGFloat
    let worstClearance: CGFloat
    let minTopClearance: CGFloat
    let fitsAll: Bool
    let notes: String
}

var sweep: [SweepRow] = []
var allMetrics: [InkMetrics] = []

let glyphSizes: [CGFloat] = [15, 18]
for size in glyphSizes {
    for s in samples {
        allMetrics.append(measure(sample: s, size: size))
    }
}

let cellHeights: [CGFloat] = [34, 38, 42, 46]
let captionSizes: [CGFloat] = [10, 11]
let cellW: CGFloat = 42

for strategy in Strategy.allCases {
    for h in cellHeights {
        for cap in captionSizes {
            for gSize in [15.0, 18.0] as [CGFloat] {
                // Skip implausible combos (18pt glyph in 34pt cell)
                if gSize >= 18 && h < 42 { continue }
                let (plan, draws) = planLayout(strategy: strategy, cellW: cellW, cellH: h,
                                               glyphSize: gSize, captionSize: cap)
                let topClear = draws.map { h - $0.inkFrame.maxY }.min() ?? 0
                sweep.append(SweepRow(
                    strategy: strategy.rawValue, cellH: h, captionSize: cap, glyphSize: gSize,
                    captionBand: plan.captionBand, maxInkAbove: plan.maxInkAbove,
                    maxInkBelow: plan.maxInkBelow,
                    inkNeed: plan.maxInkAbove + plan.maxInkBelow + 2 * plan.pad + plan.captionBand,
                    worstClearance: plan.worstClearance, minTopClearance: topClear,
                    fitsAll: plan.fitsAll && topClear >= 0, notes: plan.notes
                ))
            }
        }
    }
}

// Recommended matrix sheets (guides on)
let focus: [(Strategy, CGFloat, CGFloat, CGFloat)] = [
    (.currentFixed, 38, 15, 11),
    (.currentFixed, 46, 18, 11),
    (.typoPack, 46, 15, 10),
    (.inkCenterEach, 42, 15, 10),
    (.inkCenterEach, 46, 15, 11),
    (.sharedBaselineInk, 42, 15, 10),
    (.sharedBaselineInk, 46, 15, 10),
    (.sharedBaselineInk, 46, 15, 11),
    (.sharedBaselineCentered, 46, 15, 10),
    (.sharedBaselineCentered, 46, 15, 11),
    (.sharedBaselineCentered, 46, 18, 10),
    (.sharedBaselineInk, 52, 18, 11),
]

for (i, f) in focus.enumerated() {
    let (st, h, gs, cs) = f
    let img = drawSheet(
        title: "T-Time glyph/caption experiment",
        strategy: st, cellW: cellW, cellH: h, glyphSize: gs, captionSize: cs, showGuides: true
    )
    savePNG(img, name: String(format: "%02d_%@__h%.0f_g%.0f_c%.0f.png", i, st.rawValue, h, gs, cs))
}

// Side-by-side recommendation strip at best candidates
func drawComparisonRow() -> NSImage {
    let configs: [(Strategy, CGFloat, CGFloat, CGFloat, String)] = [
        (.currentFixed, 38, 15, 11, "A Current 38/11"),
        (.inkCenterEach, 42, 15, 10, "B Ink-centre 42/10"),
        (.sharedBaselineInk, 46, 15, 10, "C Shared 46/10"),
        (.sharedBaselineCentered, 46, 15, 10, "D Shared-ctr 46/10"),
        (.sharedBaselineCentered, 46, 15, 11, "E Shared-ctr 46/11"),
    ]
    // Show a fixed subset of demanding glyphs
    let keys = ["ka", "nga", "a+i", "rgya", "rgyu", "ksa", "ksi", "ksai", "stri", "brgya"]
    let chosen = keys.compactMap { k in samples.first { $0.key == k } }
    let cellH: CGFloat = 46
    let innerW = cellW
    let blockGap: CGFloat = 18
    let cellGap: CGFloat = 6
    let blockW = CGFloat(chosen.count) * (innerW + cellGap) + 12
    let width = CGFloat(configs.count) * (blockW + blockGap) + 20
    let height: CGFloat = cellH + 90

    let image = NSImage(size: NSSize(width: width, height: height))
    image.lockFocus()
    defer { image.unlockFocus() }
    NSColor.white.setFill()
    NSRect(origin: .zero, size: image.size).fill()
    ("Approach comparison — blue=ink bounds, orange=caption band, red=baseline; badge=clearance pt"
        as NSString).draw(at: NSPoint(x: 12, y: height - 24), withAttributes: [
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.black,
        ])

    for (bi, cfg) in configs.enumerated() {
        let (st, h, gs, cs, label) = cfg
        let (_, drawsAll) = planLayout(strategy: st, cellW: innerW, cellH: h, glyphSize: gs, captionSize: cs)
        let draws = chosen.compactMap { s in drawsAll.first { $0.sample.key == s.key } }
        let ox0 = 12 + CGFloat(bi) * (blockW + blockGap)
        (label as NSString).draw(at: NSPoint(x: ox0, y: height - 48), withAttributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .medium),
            .foregroundColor: NSColor.darkGray,
        ])
        let plan = planLayout(strategy: st, cellW: innerW, cellH: h, glyphSize: gs, captionSize: cs).0
        let meta = String(format: "clear %.1f  top %.1f  %@", plan.worstClearance,
                          draws.map { h - $0.inkFrame.maxY }.min() ?? 0,
                          plan.fitsAll ? "OK" : "OVERFLOW")
        (meta as NSString).draw(at: NSPoint(x: ox0, y: height - 64), withAttributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 9, weight: .regular),
            .foregroundColor: plan.fitsAll ? NSColor.systemGreen : NSColor.systemRed,
        ])

        // Re-draw mini cells using same logic as sheet for these samples only
        let sheet = drawSheet(title: "", strategy: st, cellW: innerW, cellH: h,
                              glyphSize: gs, captionSize: cs, showGuides: true)
        // Crop first-row cells for chosen count — simpler: draw manually
        let capFont = didot(cs)
        let glyphFont = tibetan(gs)
        for (i, d) in draws.enumerated() {
            let ox = ox0 + CGFloat(i) * (innerW + cellGap)
            let oy: CGFloat = 16
            let cell = NSRect(x: ox, y: oy, width: innerW, height: h)
            NSColor(white: 0.97, alpha: 1).setFill(); cell.fill()
            NSColor(white: 0.7, alpha: 1).setStroke()
            NSBezierPath(rect: cell).stroke()
            NSColor.systemOrange.withAlphaComponent(0.12).setFill()
            NSRect(x: ox, y: oy, width: innerW, height: plan.captionBand).fill()
            NSColor.systemBlue.withAlphaComponent(0.15).setFill()
            NSRect(x: ox + d.inkFrame.minX, y: oy + d.inkFrame.minY,
                   width: d.inkFrame.width, height: d.inkFrame.height).fill()
            NSColor.systemRed.withAlphaComponent(0.6).setStroke()
            let bl = NSBezierPath()
            bl.move(to: NSPoint(x: ox, y: oy + d.baseline.y))
            bl.line(to: NSPoint(x: ox + innerW, y: oy + d.baseline.y))
            bl.lineWidth = 0.5; bl.stroke()

            let gLine = CTLineCreateWithAttributedString(NSAttributedString(string: d.sample.glyph, attributes: [
                .font: glyphFont, .foregroundColor: NSColor.black,
            ]))
            if let ctx = NSGraphicsContext.current?.cgContext {
                ctx.saveGState()
                ctx.translateBy(x: ox + d.baseline.x, y: oy + d.baseline.y)
                CTLineDraw(gLine, ctx)
                ctx.restoreGState()
            }
            (d.sample.key as NSString).draw(
                in: NSRect(x: ox + d.captionOrigin.x, y: oy + d.captionOrigin.y,
                           width: d.captionSize.width, height: d.captionSize.height),
                withAttributes: [.font: capFont, .foregroundColor: NSColor.black.withAlphaComponent(0.75)])
        }
        _ = sheet
    }
    return image
}

savePNG(drawComparisonRow(), name: "compare_approaches.png")
savePNG(drawBubblegumControl(), name: "bubblegum_control.png")

// Minimum cell height recommendation from sharedBaselineInk + Didot 10/11 at glyph 15/18
struct MinCell: Codable {
    let glyphSize: CGFloat
    let captionSize: CGFloat
    let captionBand: CGFloat
    let maxInkAbove: CGFloat
    let maxInkBelow: CGFloat
    let recommendedMinCellH: CGFloat
    let recommendedMinCellW: CGFloat
}

var minima: [MinCell] = []
for gs in [15.0, 18.0] as [CGFloat] {
    for cs in [10.0, 11.0] as [CGFloat] {
        let env = envelope(at: gs)
        let cap = captionMetrics(font: didot(cs), text: "rgya")
        let captionBand = ceil(cap.lineH + 2 + 1)
        let pad: CGFloat = 2
        let minH = ceil(captionBand + env.above + env.below + 2 * pad)
        let minW = ceil(max(env.width + 2 * pad, cap.width + 4, 38))
        minima.append(MinCell(glyphSize: gs, captionSize: cs, captionBand: captionBand,
                              maxInkAbove: env.above, maxInkBelow: env.below,
                              recommendedMinCellH: minH, recommendedMinCellW: minW))
    }
}

struct Report: Codable {
    let generatedAt: String
    let font: String
    let sampleCount: Int
    let metrics: [InkMetrics]
    let sweep: [SweepRow]
    let minima: [MinCell]
    let recommendation: String
}

let recommendation = """
Recommend sharedBaselineCentered (Brutalist only): measure shaped CTLine ink bounds \
for the full alphabet+Sanskrit sample set; reserve a Didot caption band; place one \
shared baseline so the max ink envelope clears the caption and cell top, centering \
that envelope when slack remains. Stacker: glyph 15 + Didot 10 → min cell height 45 \
(use 46×40). Didot 11 needs height 46. Symbols at glyph 18 need height ≥50 (Didot 10) \
or ≥51 (Didot 11), or keep height 46 and use glyph 15–16. Reject typoPack (line box \
~2.8× ink). inkCenterEach fits shorter cells but breaks cross-cell baseline alignment. \
Keep Bubblegum on fixed offsets + mono 9 captions.
"""

let report = Report(
    generatedAt: ISO8601DateFormatter().string(from: Date()),
    font: "NotoSerifTibetan-Regular",
    sampleCount: samples.count,
    metrics: allMetrics,
    sweep: sweep,
    minima: minima,
    recommendation: recommendation
)

let enc = JSONEncoder()
enc.outputFormatting = [.prettyPrinted, .sortedKeys]
let jsonURL = outDir.appendingPathComponent("metrics.json")
try enc.encode(report).write(to: jsonURL)
print("wrote \(jsonURL.path)")

print("\n=== Minima ===")
for m in minima {
    print(String(format: "glyph %.0f + Didot %.0f → captionBand %.1f, ink ↑%.1f ↓%.1f, min cell %.0f×%.0f",
                 m.glyphSize, m.captionSize, m.captionBand, m.maxInkAbove, m.maxInkBelow,
                 m.recommendedMinCellW, m.recommendedMinCellH))
}
print("\n=== Sweep fits ===")
for row in sweep where row.strategy == "sharedBaselineInk" || row.strategy == "currentFixed" {
    print(String(format: "%@ h=%.0f c=%.0f g=%.0f clear=%5.1f top=%5.1f %@",
                 row.strategy, row.cellH, row.captionSize, row.glyphSize,
                 row.worstClearance, row.minTopClearance, row.fitsAll ? "FITS" : "OVERFLOW"))
}
