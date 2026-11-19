#!/bin/sh
# Regenerates macos/Resources/icon.tiff (and the installer's macos/installer/logo.png and background.png), the input-source icon shown in the menu
# bar and in System Settings, from the square logo (the pink boba cup). It is a
# full-colour icon: 16 pt at 1x and 2x, plus a 32 pt version for larger slots.
# Needs Inkscape and Xcode command line tools.
# Usage: scripts/export-input-icon.sh [path/to/logo-square.svg]
set -eu
cd "$(dirname "$0")/.."
SRC="${1:-../visual_design/logos/logo-square.svg}"
TMP=$(mktemp -d)
for px in 16 32 64; do
  /Applications/Inkscape.app/Contents/MacOS/inkscape "$SRC" --export-type=png \
    --export-width=$px --export-height=$px --export-filename="$TMP/$px.png" >/dev/null 2>&1
done
swift - "$TMP" macos/Resources/icon.tiff <<'SWIFT'
import AppKit
let dir = CommandLine.arguments[1], out = CommandLine.arguments[2]
let image = NSImage(size: NSSize(width: 16, height: 16))
// (pixels, points): 16 px is 1x, 32 px is the 2x of 16 pt, 64 px is the 2x of 32 pt.
for (px, pt) in [(16, 16), (32, 16), (64, 32)] {
    let data = try! Data(contentsOf: URL(fileURLWithPath: "\(dir)/\(px).png"))
    let rep = NSBitmapImageRep(data: data)!
    rep.size = NSSize(width: pt, height: pt)
    image.addRepresentation(rep)
}
try! image.tiffRepresentation!.write(to: URL(fileURLWithPath: out))
SWIFT
# The same logo for the installer's pages and window background.
/Applications/Inkscape.app/Contents/MacOS/inkscape "$SRC" --export-type=png --export-width=256 --export-height=256 \
  --export-filename=macos/installer/logo.png >/dev/null 2>&1
/Applications/Inkscape.app/Contents/MacOS/inkscape "$SRC" --export-type=png --export-width=96 --export-height=96 \
  --export-filename=macos/installer/background.png >/dev/null 2>&1
rm -rf "$TMP"
