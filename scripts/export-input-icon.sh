#!/bin/sh
# Regenerates macos/Resources/icon.tiff (and the installer's macos/installer/logo.png and background.png), the input-source icon shown in the menu
# bar and in System Settings, from the square logo (the pink boba cup). It is a
# full-colour icon, a single 32 px image at 144 dpi, as marinaMoji's.
# Needs Inkscape and Xcode command line tools.
# Usage: scripts/export-input-icon.sh [path/to/logo-square.svg]
set -eu
cd "$(dirname "$0")/.."
SRC="${1:-../visual_design/logos/logo-square.svg}"
TMP=$(mktemp -d)
# Exactly what marinaMoji ships (and macOS accepts): one 32 px image at 144 dpi, i.e.
# 16 pt at 2x. No template flag, no extra sizes.
/Applications/Inkscape.app/Contents/MacOS/inkscape "$SRC" --export-type=png \
  --export-width=32 --export-height=32 --export-filename="$TMP/32.png" >/dev/null 2>&1
sips -s format tiff -s dpiWidth 144 -s dpiHeight 144 "$TMP/32.png" --out macos/Resources/icon.tiff >/dev/null
# The same logo for the installer's pages and window background.
/Applications/Inkscape.app/Contents/MacOS/inkscape "$SRC" --export-type=png --export-width=256 --export-height=256 \
  --export-filename=macos/installer/logo.png >/dev/null 2>&1
/Applications/Inkscape.app/Contents/MacOS/inkscape "$SRC" --export-type=png --export-width=96 --export-height=96 \
  --export-filename=macos/installer/background.png >/dev/null 2>&1
rm -rf "$TMP"
