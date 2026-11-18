#!/bin/sh
# Removes T-Time. Remove it from System Settings > Keyboard > Input Sources first
# (or afterwards; macOS then drops the entry), then run:  sudo sh uninstall.sh
set -eu
killall TTime 2>/dev/null || true
rm -rf "/Library/Input Methods/T-Time.app"
pkgutil --forget io.github.ttime-ime.inputmethod.TTime.pkg >/dev/null 2>&1 || true
echo "T-Time removed. Log out and back in to finish."
