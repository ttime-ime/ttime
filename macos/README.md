# macOS input method

A thin InputMethodKit shell over the T-Time engine. All typing behaviour
(EWTS conversion and the commit policy) lives in `ttime-core` and reaches Swift
through the C ABI in `crates/ttime-ffi/include/ttime.h`, so the engine can be
replaced or upgraded without touching the shell.

- `Sources/Composer.swift`: key policy over the C engine; no UI dependencies.
- `Sources/InputController.swift`: maps `NSEvent` to `Composer` and writes marked and committed text to the client application.
- `Tests/main.swift`: tests for the key policy, run by the build script.

Build (nothing is installed):

```sh
scripts/build-macos.sh        # tests, then build/macos/T-Time.app (ad-hoc signed)
```

Behaviour: typed ASCII is EWTS and shows as marked text; space or Return
commits; Backspace edits the marked run (and passes through when there is none);
Escape cancels; arrows, Tab and shortcuts commit what is pending and pass through.

**Status.** The key policy is tested. The bundle builds and passes `plutil`.
*Not yet verified:* registering and enabling the input source in System
Settings, typing in real applications, and the `tsInputModeScriptKey` value.
There is no icon, no universal (x86_64) build, no Developer ID signing, no
notarization and no installer.
