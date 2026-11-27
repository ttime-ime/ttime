#!/bin/sh
# Builds the installer, build/macos/T-Time-<version>.pkg, from build/macos/T-Time.app
# (run scripts/build-macos.sh first; for a release, sign and notarize the app
# before packaging so the stapled copy is what ships).
#
# It installs into /Library/Input Methods (all users, needs an administrator
# password), shows the licence, and tells the user the two steps macOS leaves to
# them: log out and in, then add the input source.
#
# Environment:
#   PKG_SIGN_IDENTITY  a "Developer ID Installer: ..." identity; without it the
#                      package is unsigned and macOS warns on other Macs.
set -eu
cd "$(dirname "$0")/.."

APP=build/macos/T-Time.app
[ -d "$APP" ] || { echo "$APP not found: run scripts/build-macos.sh first" >&2; exit 1; }
VERSION=$(plutil -extract CFBundleShortVersionString raw "$APP/Contents/Info.plist")
W=build/macos/pkg
FINAL="build/macos/T-Time-$VERSION.pkg"
rm -rf "$W" "$FINAL"
mkdir -p "$W/root/Library/Input Methods" "$W/res" "$W/scripts"

# What gets installed. ditto keeps the code signature and extended attributes.
ditto "$APP" "$W/root/Library/Input Methods/T-Time.app"
cp macos/installer/postinstall "$W/scripts/postinstall"

# Never let the installer "relocate" to another copy of this app it finds (such
# as the one in build/): the bundle must land in /Library/Input Methods.
pkgbuild --analyze --root "$W/root" "$W/components.plist" >/dev/null
/usr/libexec/PlistBuddy -c "Set :0:BundleIsRelocatable false" "$W/components.plist" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Add :0:BundleIsRelocatable bool false" "$W/components.plist"
pkgbuild --root "$W/root" --component-plist "$W/components.plist" --scripts "$W/scripts" \
  --identifier io.github.ttime-ime.inputmethod.TTime.pkg --version "$VERSION" \
  --install-location / "$W/component.pkg" >/dev/null

# One tiny package per look; the installer lets the user pick one. Each leaves its
# name where the app finds it, as the default until the user changes it in Settings.
for style in bubblegum brutal; do
  mkdir -p "$W/style-$style/Library/Application Support/T-Time"
  printf '%s\n' "$style" > "$W/style-$style/Library/Application Support/T-Time/default-style"
  pkgbuild --root "$W/style-$style" --identifier "io.github.ttime-ime.inputmethod.TTime.style-$style" \
    --version "$VERSION" --install-location / "$W/style-$style.pkg" >/dev/null
done

# The licence screen: the project's licence, then third-party notices.
{
  echo "T-Time is licensed under either of the Apache License 2.0 or the MIT license,"
  echo "at your option."
  echo
  echo "=============================== MIT ==============================="
  cat LICENSE-MIT
  echo
  echo "=========================== Apache-2.0 ============================"
  cat LICENSE-APACHE
  echo
  echo "====================== Bundled font: Noto Serif Tibetan ======================"
  echo "Used in T-Time's own windows. Copyright the Noto Project Authors."
  echo "Licensed under the SIL Open Font License 1.1:"
  echo
  cat macos/Resources/OFL-NotoSerifTibetan.txt
  echo
  echo "=============================== Artwork ==============================="
  echo "The illustrations and logos were made for T-Time and are not covered by the"
  echo "licences above."
} > "$W/res/license.txt"
# productbuild keeps only the resources it knows (such as the background), and the
# installer's web view will not show images embedded in a page. So the package is
# built, opened, given the logo next to the pages that refer to it, and closed again.
cp macos/installer/background.png "$W/res/"
cp macos/installer/welcome.html macos/installer/conclusion.html "$W/res/"
sed "s/@VERSION@/$VERSION/g" macos/installer/distribution.xml > "$W/distribution.xml"
productbuild --distribution "$W/distribution.xml" --resources "$W/res" --package-path "$W" "$W/unsigned.pkg" >/dev/null
rm -rf "$W/expanded"
pkgutil --expand "$W/unsigned.pkg" "$W/expanded"
cp macos/installer/logo.png "$W/expanded/Resources/logo.png"
if [ -n "${PKG_SIGN_IDENTITY:-}" ]; then
  pkgutil --flatten "$W/expanded" "$W/flat.pkg"
  productsign --sign "$PKG_SIGN_IDENTITY" --timestamp "$W/flat.pkg" "$FINAL" >/dev/null
  pkgutil --check-signature "$FINAL"
else
  pkgutil --flatten "$W/expanded" "$FINAL"
  echo "note: $FINAL is UNSIGNED (set PKG_SIGN_IDENTITY to sign it)"
fi
echo "built $FINAL"
