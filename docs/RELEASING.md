# Releasing

## Cutting a release candidate

```sh
git tag v0.1.0-rc.1 && git push origin v0.1.0-rc.1
```

`.github/workflows/release.yml` runs the tests, builds the universal
(arm64 + x86_64) macOS input method, signs and notarizes it when credentials
exist, and publishes a GitHub pre-release with the zip and its SHA-256. A tag
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
| App Store Connect **API key** (`.p8`), its Key ID and the Issuer ID, for notarization | appstoreconnect.apple.com > Users and Access > Integrations > App Store Connect API (Team Key, role Developer or higher) |

Repository secrets (Settings > Secrets and variables > Actions):

| Secret | Value |
|---|---|
| `MACOS_CERT_P12` | the `.p12`, base64: `base64 -i cert.p12 \| pbcopy` |
| `MACOS_CERT_PASSWORD` | the password set when exporting the `.p12` |
| `MACOS_SIGN_IDENTITY` | the certificate's full name, e.g. `Developer ID Application: Your Name (TEAMID)` (`security find-identity -v -p codesigning` lists it) |
| `APPLE_API_KEY_P8` | the contents of `AuthKey_XXXX.p8` |
| `APPLE_API_KEY_ID` | the 10-character Key ID |
| `APPLE_API_ISSUER_ID` | the Issuer ID (a UUID) |

Use a dedicated API key and revoke it if it leaks. The workflow imports the
certificate into a temporary keychain and deletes the key file after use.

## Not covered yet

- A `.pkg` installer (needs a separate *Developer ID Installer* certificate);
  releases are a zip of the app that the user copies into `~/Library/Input Methods`.
- Automatic updates, an app icon, Windows and Linux builds.
- Signing the Wasm site; it is deployed from the `playground` repository.
