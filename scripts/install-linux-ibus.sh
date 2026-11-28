#!/bin/sh
# Installs the T-Time IBus component for the current user (~/.local).
# Build first: scripts/build-linux-ibus.sh
set -eu
cd "$(dirname "$0")/.."

ENGINE=build/linux/ibus-engine-ttime
XML=build/linux/ttime.xml
if [ ! -x "$ENGINE" ] || [ ! -f "$XML" ]; then
  echo "missing build output; run scripts/build-linux-ibus.sh first" >&2
  exit 1
fi

LIBEXEC="${HOME}/.local/libexec"
COMP="${HOME}/.local/share/ibus/component"
mkdir -p "$LIBEXEC" "$COMP"

install -m 755 "$ENGINE" "$LIBEXEC/ibus-engine-ttime"
EXEC_PATH="$LIBEXEC/ibus-engine-ttime"
sed "s|@EXEC_PATH@|$EXEC_PATH|g" linux/ibus/ttime.xml.in > "$COMP/ttime.xml"

echo "Installed:"
echo "  $LIBEXEC/ibus-engine-ttime"
echo "  $COMP/ttime.xml"
echo ""
echo "Next: ibus restart"
echo "Then add the T-Time input source (Settings → Keyboard → Input Sources → Tibetan / T-Time)."
echo "Check: ibus list-engine | grep -i ttime"
echo "If it is missing, see linux/README.md (IBUS_COMPONENT_PATH or a system install)."
