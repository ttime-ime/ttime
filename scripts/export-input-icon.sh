#!/bin/sh
# Regenerates macos/Resources/icon.tiff: the input-source icon shown in the menu
# bar and in System Settings. It is a template image (black glyph, transparent
# background; the system tints it and draws the grey tile), 16 pt at 1x and 2x,
# like the icons of Apple's own Tibetan input sources. Needs Xcode command line tools.
set -eu
cd "$(dirname "$0")/.."
swift - macos/Resources/icon.tiff <<'SWIFT'
import AppKit
let out = CommandLine.arguments[1]
let glyph = "བོད"

// Draw the glyph large and find where its ink really is (Tibetan line boxes are
// tall and uneven, so layout metrics cannot be trusted to centre it).
let big = 512
let bigRep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: big, pixelsHigh: big, bitsPerSample: 8,
                              samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                              colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bigRep)
NSAttributedString(string: glyph, attributes: [.font: NSFont.systemFont(ofSize: 150, weight: .bold),
                                               .foregroundColor: NSColor.black]).draw(at: NSPoint(x: 40, y: 120))
NSGraphicsContext.restoreGraphicsState()
var minX = big, minY = big, maxX = -1, maxY = -1
for y in 0..<big { for x in 0..<big where (bigRep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.2 {
    minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
} }
precondition(maxX >= 0, "the glyph drew nothing")
let ink = NSRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
let bigImage = NSImage(size: NSSize(width: big, height: big))
bigImage.addRepresentation(bigRep)
let cg = bigRep.cgImage!.cropping(to: ink)!   // CGImage crop is top-left based
let cropped = NSImage(cgImage: cg, size: ink.size)

let image = NSImage(size: NSSize(width: 16, height: 16))
for scale in [1, 2] {
    let px = 16 * scale
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: 16, height: 16)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    let box: CGFloat = 14  // leave a point of margin
    let k = min(box / ink.width, box / ink.height)
    let w = ink.width * k, h = ink.height * k
    cropped.draw(in: NSRect(x: (16 - w) / 2, y: (16 - h) / 2, width: w, height: h))
    NSGraphicsContext.restoreGraphicsState()
    image.addRepresentation(rep)
}
try! image.tiffRepresentation!.write(to: URL(fileURLWithPath: out))
SWIFT
