#!/bin/sh
# Builds the macOS input method into build/macos/T-Time.app and runs the
# Swift key-policy tests. Needs Xcode command line tools and a Rust toolchain.
# Does not install anything; see macos/README.md.
set -eu
cd "$(dirname "$0")/.."
export PATH="$HOME/.cargo/bin:$PATH"

cargo build --release -p ttime-ffi
LIB=target/release/libttime_ffi.a
OUT=build/macos
APP="$OUT/T-Time.app"
rm -rf "$OUT"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

SWIFTFLAGS="-swift-version 5 -O -import-objc-header crates/ttime-ffi/include/ttime.h"

# Key-policy tests: Composer + test driver, no UI frameworks.
swiftc $SWIFTFLAGS -o "$OUT/composer-tests" \
  macos/Sources/Composer.swift macos/Tests/main.swift "$LIB"
"$OUT/composer-tests"

swiftc $SWIFTFLAGS -o "$APP/Contents/MacOS/TTime" \
  macos/Sources/Composer.swift macos/Sources/InputController.swift macos/Sources/main.swift \
  "$LIB" -framework Cocoa -framework InputMethodKit
cp macos/Resources/Info.plist "$APP/Contents/Info.plist"
[ -f macos/Resources/icon.tiff ] && cp macos/Resources/icon.tiff "$APP/Contents/Resources/"
plutil -lint "$APP/Contents/Info.plist"
# Ad-hoc signature: enough to run locally, not for distribution.
codesign --force --sign - "$APP"
echo "built $APP"
