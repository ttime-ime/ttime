#!/bin/sh
# Regenerates macos/Resources/toolbar-logo.png from the logo source SVG.
# The pink bar is removed (the app draws it) so the paw can hang below it, and
# the canvas is cropped to 208 units wide. Needs Inkscape and the DynaPuff font
# (the wordmark is live text). Usage: scripts/export-toolbar-logo.sh [path/to/toolbar_logo.svg]
set -eu
cd "$(dirname "$0")/.."
SRC="${1:-../visual_design/logos/toolbar_logo.svg}"
TMP=$(mktemp -d)
python3 - "$SRC" "$TMP/mark.svg" <<'PY'
import re, sys
s = open(sys.argv[1]).read()
s, n = re.subn(r'<rect\s+style="fill:#e4bbc5[^>]*?/>', '', s, count=1, flags=re.S)
assert n == 1, "pink bar rectangle not found"
s = s.replace('width="217.28484mm"', 'width="208mm"').replace('viewBox="0 0 217.28484 66.926712"', 'viewBox="0 0 208 66.926712"')
open(sys.argv[2], "w").write(s)
PY
/Applications/Inkscape.app/Contents/MacOS/inkscape "$TMP/mark.svg" --export-type=png \
  --export-width=832 --export-filename=macos/Resources/toolbar-logo.png
rm -rf "$TMP"
echo "wrote macos/Resources/toolbar-logo.png"
