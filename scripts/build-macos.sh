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
for arch in $ARCHS; do
  T=$(triple "$arch")
  cargo build --release -p ttime-ffi --target "$T"
  LIB="target/$T/release/libttime_ffi.a"
  TARGET="$arch-apple-macos13.0"

  # Key-policy tests: Composer + test driver, no UI frameworks. An architecture
  # the host cannot execute (x86_64 without Rosetta) is built but not tested.
  swiftc $SWIFTFLAGS -target "$TARGET" -o "$OUT/composer-tests-$arch" \
    macos/Sources/Composer.swift macos/Tests/main.swift "$LIB"
  if arch -"$arch" /usr/bin/true 2>/dev/null; then
    "$OUT/composer-tests-$arch" || { echo "key-policy tests failed ($arch)" >&2; exit 1; }
  else
    echo "skipping key-policy tests for $arch: this host cannot run it"
  fi

  swiftc $SWIFTFLAGS -target "$TARGET" -o "$OUT/TTime-$arch" \
    macos/Sources/Composer.swift macos/Sources/InputController.swift macos/Sources/main.swift \
    "$LIB" -framework Cocoa -framework InputMethodKit
  BINS="$BINS $OUT/TTime-$arch"
done
lipo -create $BINS -output "$APP/Contents/MacOS/TTime"
rm -f "$OUT"/composer-tests-* "$OUT"/TTime-*

cp macos/Resources/Info.plist "$APP/Contents/Info.plist"
cp macos/Resources/icon.tiff macos/Resources/AppIcon.icns "$APP/Contents/Resources/"
cp -R macos/Resources/en.lproj "$APP/Contents/Resources/"
[ -n "${VERSION:-}" ] && plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP/Contents/Info.plist"
[ -n "${BUILD_NUMBER:-}" ] && plutil -replace CFBundleVersion -string "$BUILD_NUMBER" "$APP/Contents/Info.plist"
plutil -lint "$APP/Contents/Info.plist"

IDENTITY="${SIGN_IDENTITY:--}"
if [ "$IDENTITY" = "-" ]; then
  codesign --force --sign - "$APP"
else
  codesign --force --sign "$IDENTITY" --options runtime --timestamp "$APP"
fi
codesign --verify --strict --verbose=2 "$APP"
lipo -archs "$APP/Contents/MacOS/TTime"
echo "built $APP (signed with ${SIGN_IDENTITY:-ad-hoc})"
