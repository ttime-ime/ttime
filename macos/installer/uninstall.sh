#!/bin/sh
# Removes T-Time and T-Time Tools. Remove T-Time from System Settings > Keyboard >
# Input Sources first (or afterwards; macOS then drops the entry), then run:
#   sudo sh uninstall.sh
set -eu
killall TTime 2>/dev/null || true
killall TTimeTools 2>/dev/null || true
rm -rf "/Library/Input Methods/T-Time.app" "/Applications/T-Time Tools.app" \
  "/Library/Application Support/T-Time"
pkgutil --forget io.github.ttime-ime.inputmethod.TTime.pkg >/dev/null 2>&1 || true
echo "T-Time removed. Log out and back in to finish."
