# macOS input method

A thin InputMethodKit shell over the T-Time engine. All typing behaviour
(EWTS conversion and the commit policy) lives in `ttime-core` and reaches Swift
through the C ABI in `crates/ttime-ffi/include/ttime.h`, so the engine can be
replaced or upgraded without touching the shell.

- `Sources/Composer.swift`: key policy over the C engine; no UI dependencies.
- `Sources/InputController.swift`: maps `NSEvent` to `Composer` and writes marked and committed text to the client application.
- `Sources/Toolbar.swift`: the floating, branded toolbar (mode, lock, Symbols and Stacker buttons). AppKit only, so it is built but not unit-tested; it was checked by rendering it.
- `Sources/StackerModel.swift`: the stacker's state and rules (chosen letters, typing, the engine's answer); tested.
- `Sources/StackerPanel.swift`: the pink stacker window with the illustration (`Resources/stacker-art.webp`, made for T-Time, not under the code licence). Checked by rendering, not run in a live input method.
- `Sources/SymbolsModel.swift`, `Sources/SymbolsPanel.swift`: the symbols window (same catalogue and search as the web palette, from `ttime-core`); the model is tested, the panel checked by rendering.
- `Sources/TibetanFont.swift`: registers the bundled Noto Serif Tibetan (`Resources/NotoSerifTibetan.ttf`, SIL OFL 1.1, text in `Resources/OFL-NotoSerifTibetan.txt`; a format conversion of the web playground's copy) for T-Time's own windows. macOS's built-in Tibetan fonts do not stack Sanskrit combinations such as retroflex letters under other letters. Text inserted into a document is drawn in the document's font, so for Sanskrit stacks choose a font such as Noto Serif Tibetan or Jomolhari there.
- `Tests/main.swift`: tests for the key policy, run by the build script.

Install (end users): open the `.pkg` from a release, follow the installer, log
out and in, and add T-Time under System Settings > Keyboard > Input Sources. To
remove it: `sudo sh macos/installer/uninstall.sh`. Building the installer:
`scripts/build-pkg.sh` after `scripts/build-macos.sh` (see `docs/RELEASING.md`).

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

**Toolbar.** A bubblegum-pink bar shows while T-Time is the active input
source: the logo (its cat paw hangs below the bar), the Tibetan/Latin mode (click either side) and a lock (click,
or double-tap left Shift). The Symbols and Stacker buttons open those windows. Drag it anywhere; it remembers where. "Hide Toolbar" is in the
input-method menu. It stays pink in dark mode, because the colours are the brand. The logo is
exported from `visual_design/logos/toolbar_logo.svg` by
`scripts/export-toolbar-logo.sh`.

**Stacker.** Build one Sanskrit stack letter by letter: click letters (top to
bottom) or type their EWTS (Space or `+` adds the letter, Backspace removes one),
choose a vowel and marks, and the window shows the stack, the *shortest* EWTS
for it (`rgya` for `r+g+ya`) and what the engine reports. Return or Insert puts
the stack in the document and starts the next one; Esc closes. Open it with the
toolbar button or Option+Shift+\` (the key left of 1). While it is open, letters
go to the stacker, not the document. The engine (`build_stack` in `ttime-core`,
through `ttime_build_stack_json`) builds every stack, so the window cannot
disagree with typing.

**Symbols.** Punctuation, head marks, brackets, numbers, syllables, Sanskrit
letters and marks in one searchable table. Open it by double-tapping right
Shift or with the toolbar button. Type to search (name, EWTS, code point or the
character), click a category, arrows move, Return or a click inserts, Esc clears
the search and then closes. Tab switches between the symbols and the stacker.
The window opens with the cookie-icing illustration (`Resources/symbols-art.webp`, shown whole beside the table; made for T-Time, not under the code licence). The catalogue is a draft: labels have not been reviewed by a Tibetologist.

**Status.** The key policy is tested. The bundle builds and passes `plutil`.
*Not yet verified:* registering and enabling the input source in System
Settings, typing in real applications, and the `tsInputModeScriptKey` value.
There is no universal (x86_64) build, no Developer ID signing, no
notarization and no installer.
