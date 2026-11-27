#!/bin/sh
# Builds the macOS input method into build/macos/T-Time.app and runs the
# Swift key-policy tests. Needs Xcode command line tools and a Rust toolchain.
# Does not install anything; see macos/README.md.
#
# Environment:
#   UNIVERSAL=1        build arm64 and x86_64 (needs the x86_64-apple-darwin target)
#   VERSION=x.y.z      CFBundleShortVersionString (default: from Info.plist)
#   BUILD_NUMBER=n     CFBundleVersion (default: from Info.plist)
#   SIGN_IDENTITY=...  codesign identity; default "-" is an ad-hoc signature that
#                      only runs locally. A Developer ID identity also turns on
#                      the hardened runtime and a secure timestamp, as
#                      notarization requires.
set -eu
cd "$(dirname "$0")/.."
export PATH="$HOME/.cargo/bin:$PATH"

OUT=build/macos
APP="$OUT/T-Time.app"
HOST=$(uname -m)
if [ "${UNIVERSAL:-0}" = 1 ]; then ARCHS="arm64 x86_64"; else ARCHS="$HOST"; fi
rm -rf "$OUT"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

triple() { [ "$1" = arm64 ] && echo aarch64-apple-darwin || echo x86_64-apple-darwin; }
SWIFTFLAGS="-swift-version 5 -O -import-objc-header crates/ttime-ffi/include/ttime.h"
BINS=""
HELPERS=""
for arch in $ARCHS; do
  T=$(triple "$arch")
  cargo build --release -p ttime-ffi --target "$T"
  LIB="target/$T/release/libttime_ffi.a"
  TARGET="$arch-apple-macos13.0"

  # Key-policy tests: Composer + test driver, no UI frameworks. An architecture
  # the host cannot execute (x86_64 without Rosetta) is built but not tested.
  swiftc $SWIFTFLAGS -target "$TARGET" -o "$OUT/composer-tests-$arch" \
    macos/Sources/Composer.swift macos/Sources/AccentPalette.swift macos/Sources/SanskritSuggest.swift macos/Sources/ShiftTap.swift macos/Sources/ModeLock.swift macos/Sources/Updater.swift \
    macos/Sources/StackerModel.swift macos/Sources/SymbolsModel.swift macos/Tests/main.swift "$LIB"
  if arch -"$arch" /usr/bin/true 2>/dev/null; then
    "$OUT/composer-tests-$arch" || { echo "key-policy tests failed ($arch)" >&2; exit 1; }
  else
    echo "skipping key-policy tests for $arch: this host cannot run it"
  fi

  swiftc $SWIFTFLAGS -target "$TARGET" -o "$OUT/TTime-$arch" \
    macos/Sources/Composer.swift macos/Sources/ShiftTap.swift macos/Sources/ModeLock.swift \
    macos/Sources/SanskritSuggest.swift macos/Sources/SuggestionPanel.swift macos/Sources/AccentPalette.swift macos/Sources/AccentPanel.swift macos/Sources/Preferences.swift macos/Sources/DebugLog.swift macos/Sources/TibetanFont.swift macos/Sources/StackerModel.swift macos/Sources/SymbolsModel.swift macos/Sources/Toolbar.swift macos/Sources/PanelChrome.swift macos/Sources/StackerPanel.swift macos/Sources/SymbolsPanel.swift \
    macos/Sources/Updater.swift macos/Sources/UpdateSettings.swift macos/Sources/InputController.swift macos/Sources/main.swift \
    "$LIB" -framework Cocoa -framework InputMethodKit -framework Carbon -framework ServiceManagement
  BINS="$BINS $OUT/TTime-$arch"

  # The background update helper: no engine, no UI.
  swiftc -swift-version 5 -O -target "$TARGET" -o "$OUT/helper-$arch" -parse-as-library \
    macos/Sources/Updater.swift macos/Sources/UpdateHelper.swift
  HELPERS="$HELPERS $OUT/helper-$arch"
done
lipo -create $BINS -output "$APP/Contents/MacOS/TTime"
lipo -create $HELPERS -output "$APP/Contents/MacOS/TTimeUpdateHelper"
rm -f "$OUT"/composer-tests-* "$OUT"/TTime-* "$OUT"/helper-*

cp macos/Resources/Info.plist "$APP/Contents/Info.plist"
cp macos/Resources/icon.tiff macos/Resources/AppIcon.icns macos/Resources/toolbar-logo.png macos/Resources/stacker-art.webp macos/Resources/symbols-art.webp \
   macos/Resources/NotoSerifTibetan.ttf macos/Resources/OFL-NotoSerifTibetan.txt "$APP/Contents/Resources/"
cp data/sanskrit/iast-lexicon.tsv data/sanskrit/README.md "$APP/Contents/Resources/"
mv "$APP/Contents/Resources/README.md" "$APP/Contents/Resources/iast-lexicon-README.md"
cp -R macos/Resources/en.lproj "$APP/Contents/Resources/"
# Resource files must be readable by every user: the input method runs as the
# logged-in user, and a source file with mode 600 would silently lose its art.
chmod -R a+rX "$APP/Contents/Resources"
mkdir -p "$APP/Contents/Library/LaunchDaemons"
cp macos/Resources/LaunchDaemons/*.plist "$APP/Contents/Library/LaunchDaemons/"
[ -n "${VERSION:-}" ] && plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP/Contents/Info.plist"
[ -n "${BUILD_NUMBER:-}" ] && plutil -replace CFBundleVersion -string "$BUILD_NUMBER" "$APP/Contents/Info.plist"
plutil -lint "$APP/Contents/Info.plist"

IDENTITY="${SIGN_IDENTITY:--}"
# The helper is nested code in Contents/MacOS, which signing the bundle does not
# reach, so it is signed first.
HELPER="$APP/Contents/MacOS/TTimeUpdateHelper"
if [ "$IDENTITY" = "-" ]; then
  codesign --force --sign - "$HELPER"
  codesign --force --sign - "$APP"
else
  codesign --force --sign "$IDENTITY" --options runtime --timestamp "$HELPER"
  codesign --force --sign "$IDENTITY" --options runtime --timestamp "$APP"
fi
codesign --verify --strict --verbose=2 "$APP"
lipo -archs "$APP/Contents/MacOS/TTime"
echo "built $APP (signed with ${SIGN_IDENTITY:-ad-hoc})"
