# Releasing

## Cutting a release candidate

```sh
git tag v0.1.0-rc.1 && git push origin v0.1.0-rc.1
```

`.github/workflows/release.yml` runs the tests, builds the universal
(arm64 + x86_64) macOS input method, signs and notarizes it when credentials
exist, builds the installer package, and publishes a GitHub pre-release with the
`.pkg`, the app as a `.zip`, and their SHA-256 sums. A tag
without a `-` suffix (`v0.1.0`) is a full release. Tags are made by hand; CI never
tags.

Continuous integration (`ci.yml`) runs on every push to `main` and every pull
request: `cargo fmt`, `clippy -D warnings`, the whole test suite, the Wasm
build, and the macOS build (ad-hoc signed, kept as a 7-day artifact).

## What signing needs

Without the secrets below the release still builds, but it is ad-hoc signed,
named `...-UNSIGNED.zip`, and macOS will refuse to open it on other machines.

| What | Where it comes from |
|---|---|
| Apple Developer Program membership (paid, per person or organization) | developer.apple.com/programs |
| **Developer ID Application** certificate and its private key, exported as a `.p12` | Xcode > Settings > Accounts > Manage Certificates, or developer.apple.com > Certificates; export from Keychain Access with a password |
| **Developer ID Installer** certificate (a different certificate from the Application one; same membership), exported as a `.p12`, which can be the same file as the Application one if both are exported together | developer.apple.com > Certificates |
| App Store Connect **API key** (`.p8`), its Key ID and the Issuer ID, for notarization | appstoreconnect.apple.com > Users and Access > Integrations > App Store Connect API (Team Key, role Developer or higher) |

Repository secrets (Settings > Secrets and variables > Actions):

| Secret | Value |
|---|---|
| `MACOS_CERT_P12` | the `.p12`, base64: `base64 -i cert.p12 \| pbcopy` |
| `MACOS_CERT_PASSWORD` | the password set when exporting the `.p12` |
| `MACOS_SIGN_IDENTITY` | the certificate's full name, e.g. `Developer ID Application: Your Name (TEAMID)` (`security find-identity -v -p codesigning` lists it) |
| `MACOS_INSTALLER_CERT_P12` | the Developer ID Installer `.p12`, base64 (omit if it is in `MACOS_CERT_P12`: then set this to the same value) |
| `MACOS_INSTALLER_CERT_PASSWORD` | its password |
| `MACOS_INSTALLER_IDENTITY` | e.g. `Developer ID Installer: Your Name (TEAMID)` |
| `APPLE_API_KEY_P8` | the contents of `AuthKey_XXXX.p8` |
| `APPLE_API_KEY_ID` | the 10-character Key ID |
| `APPLE_API_ISSUER_ID` | the Issuer ID (a UUID) |

Use a dedicated API key and revoke it if it leaks. The workflow imports the
certificate into a temporary keychain and deletes the key file after use.

## The installer

`scripts/build-pkg.sh` turns `build/macos/T-Time.app` into `build/macos/T-Time-<version>.pkg`
(run `scripts/build-macos.sh` first). It installs into `/Library/Input Methods` for
all users (administrator password), is non-relocatable, stops a running copy
afterwards, and shows the licence (`LICENSE-MIT`, `LICENSE-APACHE`, the bundled
font's OFL text and an artwork note, assembled by the script), a welcome page and a
closing page telling the user to log out and in and add the input source. macOS
does not let an installer enable an input method, so those two steps stay manual.
Its pages are in `macos/installer/`. Without `PKG_SIGN_IDENTITY` the package is
unsigned. In CI the app is signed and notarized first, so the stapled app is what
goes into the package; the package is then signed, notarized and stapled too.
To remove T-Time: `sudo sh macos/installer/uninstall.sh`.

Without the installer secrets the release still publishes the `.pkg`, named
`...-UNSIGNED.pkg`.

## Not covered yet

- Automatic updates, an app icon, Windows and Linux builds.
- Signing the Wasm site; it is deployed from the `playground` repository.
