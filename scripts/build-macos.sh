#!/bin/sh
# Builds the macOS input method into build/macos/T-Time.app, T-Time Tools into
# build/macos/T-Time Tools.app, and runs the Swift tests. Needs Xcode command
# line tools and a Rust toolchain. Does not install anything; see macos/README.md.
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
TOOLS="$OUT/T-Time Tools.app"
HOST=$(uname -m)
if [ "${UNIVERSAL:-0}" = 1 ]; then ARCHS="arm64 x86_64"; else ARCHS="$HOST"; fi
rm -rf "$OUT"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
mkdir -p "$TOOLS/Contents/MacOS" "$TOOLS/Contents/Resources"

triple() { [ "$1" = arm64 ] && echo aarch64-apple-darwin || echo x86_64-apple-darwin; }
SWIFTFLAGS="-swift-version 5 -O -import-objc-header crates/ttime-ffi/include/ttime.h"
BINS=""
HELPERS=""
TOOL_BINS=""
TOOLS_SRC="macos/tools/Sources/Prefs.swift macos/tools/Sources/Engine.swift macos/tools/Sources/ConvertLogic.swift macos/tools/Sources/ConvertService.swift macos/tools/Sources/ConvertWindow.swift macos/tools/Sources/ConvertIntents.swift macos/tools/Sources/TibetanFont.swift macos/tools/Sources/main.swift"
for arch in $ARCHS; do
  T=$(triple "$arch")
  cargo build --release -p ttime-ffi --target "$T"
  LIB="target/$T/release/libttime_ffi.a"
  TARGET="$arch-apple-macos13.0"

  # Key-policy tests: Composer + test driver, no UI frameworks. An architecture
  # the host cannot execute (x86_64 without Rosetta) is built but not tested.
  swiftc $SWIFTFLAGS -target "$TARGET" -o "$OUT/composer-tests-$arch" \
    macos/Sources/Composer.swift macos/Sources/AccentPalette.swift macos/Sources/SanskritSuggest.swift macos/Sources/ShiftTap.swift macos/Sources/ModeLock.swift macos/Sources/ClientText.swift macos/Sources/Updater.swift \
    macos/Sources/StackerModel.swift macos/Sources/SymbolsModel.swift macos/Sources/DictionaryModel.swift macos/Tests/main.swift "$LIB"
  if arch -"$arch" /usr/bin/true 2>/dev/null; then
    "$OUT/composer-tests-$arch" || { echo "key-policy tests failed ($arch)" >&2; exit 1; }
  else
    echo "skipping key-policy tests for $arch: this host cannot run it"
  fi

  # Tools conversion tests (logic + engine via FFI).
  swiftc $SWIFTFLAGS -target "$TARGET" -o "$OUT/tools-tests-$arch" \
    macos/tools/Sources/Prefs.swift macos/tools/Sources/Engine.swift macos/tools/Sources/ConvertLogic.swift \
    macos/tools/Tests/main.swift "$LIB"
  if arch -"$arch" /usr/bin/true 2>/dev/null; then
    "$OUT/tools-tests-$arch" || { echo "tools tests failed ($arch)" >&2; exit 1; }
  else
    echo "skipping tools tests for $arch: this host cannot run it"
  fi

  swiftc $SWIFTFLAGS -target "$TARGET" -o "$OUT/TTime-$arch" \
    macos/Sources/Composer.swift macos/Sources/ShiftTap.swift macos/Sources/ModeLock.swift macos/Sources/ClientText.swift \
    macos/Sources/SanskritSuggest.swift macos/Sources/SuggestionPanel.swift macos/Sources/AccentPalette.swift macos/Sources/AccentPanel.swift macos/Sources/Preferences.swift macos/Sources/DebugLog.swift macos/Sources/TibetanFont.swift macos/Sources/BubblegumFonts.swift macos/Sources/StackerModel.swift macos/Sources/SymbolsModel.swift macos/Sources/GlyphCaptionLayout.swift macos/Sources/StackPreviewView.swift macos/Sources/Theme.swift macos/Sources/Toolbar.swift macos/Sources/PanelChrome.swift macos/Sources/StackerPanel.swift macos/Sources/SymbolsPanel.swift macos/Sources/DictionaryModel.swift macos/Sources/DictionaryPanel.swift \
    macos/Sources/Updater.swift macos/Sources/UpdateSettings.swift macos/Sources/InputController.swift macos/Sources/main.swift \
    "$LIB" -framework Cocoa -framework InputMethodKit -framework Carbon -framework ServiceManagement -framework WebKit
  BINS="$BINS $OUT/TTime-$arch"

  # The background update helper: no engine, no UI.
  swiftc -swift-version 5 -O -target "$TARGET" -o "$OUT/helper-$arch" -parse-as-library \
    macos/Sources/Updater.swift macos/Sources/UpdateHelper.swift
  HELPERS="$HELPERS $OUT/helper-$arch"

  # Companion converter: Services, Shortcuts intents, convert window.
  # shellcheck disable=SC2086
  swiftc $SWIFTFLAGS -target "$TARGET" -o "$OUT/TTimeTools-$arch" \
    $TOOLS_SRC "$LIB" -framework Cocoa -framework AppIntents
  TOOL_BINS="$TOOL_BINS $OUT/TTimeTools-$arch"
done
lipo -create $BINS -output "$APP/Contents/MacOS/TTime"
lipo -create $HELPERS -output "$APP/Contents/MacOS/TTimeUpdateHelper"
lipo -create $TOOL_BINS -output "$TOOLS/Contents/MacOS/TTimeTools"
rm -f "$OUT"/composer-tests-* "$OUT"/tools-tests-* "$OUT"/TTime-* "$OUT"/helper-* "$OUT"/TTimeTools-*

cp macos/Resources/Info.plist "$APP/Contents/Info.plist"
cp macos/Resources/icon-colour.tiff macos/Resources/icon-mono.tiff macos/Resources/AppIcon.icns macos/Resources/toolbar-logo.png macos/Resources/toolbar-logo-brutal.png macos/Resources/toolbar-logo-brutal-dark.png macos/Resources/stacker-art.webp macos/Resources/symbols-art.webp macos/Resources/symbols-brutal.png macos/Resources/brutal-art.webp macos/Resources/stacker-art-brutal.webp macos/Resources/stacker-art-brutal.png \
   macos/Resources/NotoSerifTibetan.ttf macos/Resources/OFL-NotoSerifTibetan.txt "$APP/Contents/Resources/"
mkdir -p "$APP/Contents/Resources/Fonts"
cp macos/Resources/Fonts/Nunito-*.ttf macos/Resources/Fonts/OFL-Nunito.txt "$APP/Contents/Resources/Fonts/"
cp data/sanskrit/iast-lexicon.tsv data/sanskrit/README.md "$APP/Contents/Resources/"
mv "$APP/Contents/Resources/README.md" "$APP/Contents/Resources/iast-lexicon-README.md"
cp -R macos/Resources/en.lproj "$APP/Contents/Resources/"
# Resource files must be readable by every user: the input method runs as the
# logged-in user, and a source file with mode 600 would silently lose its art.
chmod -R a+rX "$APP/Contents/Resources"
# The input-source icon macOS shows in the menu bar is Resources/icon.tiff: the colour
# one here; the installer swaps in the mono one when Brutalist is chosen.
cp macos/Resources/icon-colour.tiff "$APP/Contents/Resources/icon.tiff"
mkdir -p "$APP/Contents/Library/LaunchDaemons"
cp macos/Resources/LaunchDaemons/*.plist "$APP/Contents/Library/LaunchDaemons/"
[ -n "${VERSION:-}" ] && plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP/Contents/Info.plist"
[ -n "${BUILD_NUMBER:-}" ] && plutil -replace CFBundleVersion -string "$BUILD_NUMBER" "$APP/Contents/Info.plist"
plutil -lint "$APP/Contents/Info.plist"

# T-Time Tools bundle.
cp macos/tools/Resources/Info.plist "$TOOLS/Contents/Info.plist"
cp macos/Resources/AppIcon.icns macos/Resources/NotoSerifTibetan.ttf macos/Resources/OFL-NotoSerifTibetan.txt \
  "$TOOLS/Contents/Resources/"
chmod -R a+rX "$TOOLS/Contents/Resources"
TOOLS_VER="${VERSION:-}"
[ -z "$TOOLS_VER" ] && TOOLS_VER=$(plutil -extract CFBundleShortVersionString raw "$APP/Contents/Info.plist")
plutil -replace CFBundleShortVersionString -string "$TOOLS_VER" "$TOOLS/Contents/Info.plist"
[ -n "${BUILD_NUMBER:-}" ] && plutil -replace CFBundleVersion -string "$BUILD_NUMBER" "$TOOLS/Contents/Info.plist"
plutil -lint "$TOOLS/Contents/Info.plist"

# App Intents are compiled into Tools (ConvertIntents.swift). Emitting their
# Shortcuts metadata needs an Xcode app target's build graph
# (appintentsmetadataprocessor); with swiftc alone, use Services + a system
# keyboard shortcut, or a Shortcut that runs the Service.

IDENTITY="${SIGN_IDENTITY:--}"
# The helper is nested code in Contents/MacOS, which signing the bundle does not
# reach, so it is signed first.
HELPER="$APP/Contents/MacOS/TTimeUpdateHelper"
if [ "$IDENTITY" = "-" ]; then
  codesign --force --sign - "$HELPER"
  codesign --force --sign - "$APP"
  codesign --force --sign - "$TOOLS"
else
  codesign --force --sign "$IDENTITY" --options runtime --timestamp "$HELPER"
  codesign --force --sign "$IDENTITY" --options runtime --timestamp "$APP"
  codesign --force --sign "$IDENTITY" --options runtime --timestamp "$TOOLS"
fi
codesign --verify --verbose=2 "$APP"
codesign --verify --verbose=2 "$TOOLS"
lipo -archs "$APP/Contents/MacOS/TTime"
lipo -archs "$TOOLS/Contents/MacOS/TTimeTools"
echo "built $APP and $TOOLS (signed with ${SIGN_IDENTITY:-ad-hoc})"
