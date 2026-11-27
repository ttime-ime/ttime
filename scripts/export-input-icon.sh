#!/bin/sh
# Regenerates macos/Resources/icon-colour.tiff (and the installer's macos/installer/logo.png and background.png), the input-source icon shown in the menu
# bar and in System Settings, from the square logo (the pink boba cup). It is a
# full-colour icon, a single 32 px image at 144 dpi, as marinaMoji's.
# Needs Inkscape and Xcode command line tools.
# Usage: scripts/export-input-icon.sh [path/to/logo-square.svg]
set -eu
cd "$(dirname "$0")/.."
SRC="${1:-../visual_design/logos/logo-square.svg}"
TMP=$(mktemp -d)
# One 44 x 32 px image at 144 dpi (22 x 16 pt at 2x), full colour, no template flag.
# Native input-source icons are wide tiles, so the plum tile is widened and the cup of
# the logo centred on it. It must carry NO colour profile: sips embeds an sRGB one, and
# with it macOS drew the icon as a plain square. Same format as marinaMoji's, but wider.
/Applications/Inkscape.app/Contents/MacOS/inkscape "$SRC" --export-type=png \
  --export-width=256 --export-height=256 --export-filename="$TMP/256.png" >/dev/null 2>&1
python3 - "$TMP/256.png" macos/Resources/icon-colour.tiff <<'PY'
import sys
from PIL import Image, ImageDraw
logo = Image.open(sys.argv[1]).convert("RGBA")
plum = logo.getpixel((128, 6))          # the tile colour, just inside the top edge
# The cup and straw are the light part of the logo; copy that box onto a wider tile.
light = logo.convert("L").point(lambda v: 255 if v > 140 else 0)
box = light.getbbox()
cup = logo.crop(box)
S = 8                                    # work at 8x, then shrink
W, H = 44 * S, 32 * S
tile = Image.new("RGBA", (W, H), (0, 0, 0, 0))
ImageDraw.Draw(tile).rounded_rectangle((0, 0, W - 1, H - 1), radius=8 * S, fill=plum)
scale = (H * 0.92) / cup.height          # cup fills about 92% of the height
cup = cup.resize((round(cup.width * scale), round(cup.height * scale)), Image.LANCZOS)
tile.alpha_composite(cup, ((W - cup.width) // 2, (H - cup.height) // 2))
im = tile.resize((44, 32), Image.LANCZOS)
im.info.pop("icc_profile", None)
im.save(sys.argv[2], format="TIFF", compression="raw", dpi=(144, 144), icc_profile=None)
PY
# The same logo for the installer's pages and window background.
/Applications/Inkscape.app/Contents/MacOS/inkscape "$SRC" --export-type=png --export-width=256 --export-height=256 \
  --export-filename=macos/installer/logo.png >/dev/null 2>&1
/Applications/Inkscape.app/Contents/MacOS/inkscape "$SRC" --export-type=png --export-width=96 --export-height=96 \
  --export-filename=macos/installer/background.png >/dev/null 2>&1
# The brutalist style's icon: the black pot on nothing, with a thin white outline so it
# reads on a dark menu bar as well as a light one (macOS draws its own tile behind icons).
BRUTAL="${2:-../visual_design/logos/logo-square-brutal-light.svg}"
if [ -f "$BRUTAL" ]; then
  /Applications/Inkscape.app/Contents/MacOS/inkscape "$BRUTAL" --export-type=png \
    --export-width=256 --export-height=256 --export-filename="$TMP/brutal.png" >/dev/null 2>&1
  python3 - "$TMP/brutal.png" macos/Resources/icon-mono.tiff <<'PY2'
import sys
from PIL import Image, ImageFilter
pot = Image.open(sys.argv[1]).convert("RGBA")
# The pot is the part of the tile that is cut out: transparent, but not outside it.
from PIL import ImageChops, ImageDraw
hole = pot.getchannel("A").point(lambda v: 255 if v < 128 else 0)
for xy in ((0, 0), (hole.width - 1, 0), (0, hole.height - 1), (hole.width - 1, hole.height - 1)):
    ImageDraw.floodfill(hole, xy, 0)      # the corners and the margin are not the pot
mask = hole.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.MinFilter(5))
pot.putalpha(mask)
pot = pot.crop(mask.getbbox())
S = 8
W, H = 44 * S, 32 * S
tile = Image.new("RGBA", (W, H), (0, 0, 0, 0))
scale = (H * 0.92) / pot.height
pot = pot.resize((round(pot.width * scale), round(pot.height * scale)), Image.LANCZOS)
alpha = pot.getchannel("A")
halo = alpha.filter(ImageFilter.MaxFilter(2 * (S // 2) + 1)).point(lambda v: 255 if v > 40 else 0)
white = Image.new("RGBA", pot.size, (255, 255, 255, 255)); white.putalpha(halo)
black = Image.new("RGBA", pot.size, (0, 0, 0, 255)); black.putalpha(alpha)
x, y = (W - pot.width) // 2, (H - pot.height) // 2
tile.alpha_composite(white, (x, y)); tile.alpha_composite(black, (x, y))
im = tile.resize((44, 32), Image.LANCZOS)
im.info.pop("icc_profile", None)
im.save(sys.argv[2], format="TIFF", compression="raw", dpi=(144, 144), icc_profile=None)
PY2
fi
rm -rf "$TMP"
