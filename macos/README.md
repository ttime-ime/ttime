# macOS input method

A thin InputMethodKit shell over the T-Time engine. All typing behaviour
(EWTS conversion and the commit policy) lives in `ttime-core` and reaches Swift
through the C ABI in `crates/ttime-ffi/include/ttime.h`, so the engine can be
replaced or upgraded without touching the shell.

- `Sources/Composer.swift`: key policy over the C engine; no UI dependencies.
- `Sources/InputController.swift`: maps `NSEvent` to `Composer` and writes marked and committed text to the client application.
- `Sources/Toolbar.swift`: the floating, branded toolbar (mode, lock, Symbols and Stacker buttons). AppKit only, so it is built but not unit-tested; it was checked by rendering it.
- `Tests/main.swift`: tests for the key policy, run by the build script.

Build (nothing is installed):

```sh
scripts/build-macos.sh        # tests, then build/macos/T-Time.app (ad-hoc signed)
```

Behaviour: typed ASCII is EWTS and shows as marked text; space commits
(with a tsheg); Return commits and then passes through as a new line; Backspace edits the marked run (and passes through when there is none);
Escape cancels; arrows, Tab and shortcuts commit what is pending and pass through.

**Shift taps.** Tap left Shift to flip Tibetan and Latin until focus moves to
another field or app. Double-tap it (within 500 ms) to lock the mode you were
in; the lock survives focus changes and restarts, single taps are ignored while
it is on, and another double tap always clears it. A single tap of right Shift
does nothing; a double tap is reserved for the symbols table (not built). A tap
means no other key or modifier in between and a press under 350 ms, so Shift
for a capital never toggles. There is no on-screen indicator of the mode yet.
Logic: `Sources/ShiftTap.swift`, `Sources/ModeLock.swift` (both tested).

**Toolbar.** A small cream-and-plum bar shows while T-Time is the active input
source: the logo, the Tibetan/Latin mode (click either side) and a lock (click,
or double-tap left Shift). Symbols and Stacker are disabled until those tools
exist. Drag it anywhere; it remembers where. "Hide Toolbar" is in the
input-method menu. It stays light in dark mode, because the colours are the brand.

**Status.** The key policy is tested. The bundle builds and passes `plutil`.
*Not yet verified:* registering and enabling the input source in System
Settings, typing in real applications, and the `tsInputModeScriptKey` value.
There is no universal (x86_64) build, no Developer ID signing, no
notarization and no installer.
