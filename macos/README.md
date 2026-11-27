# macOS input method

A thin InputMethodKit shell over the T-Time engine. All typing behaviour
(EWTS conversion and the commit policy) lives in `ttime-core` and reaches Swift
through the C ABI in `crates/ttime-ffi/include/ttime.h`, so the engine can be
replaced or upgraded without touching the shell.

- `Sources/Composer.swift`: key policy over the C engine; no UI dependencies.
- `Sources/InputController.swift`: maps `NSEvent` to `Composer` and writes marked and committed text to the client application.
- `Sources/Toolbar.swift`: the floating, branded toolbar (mode, lock, Symbols and Stacker buttons). AppKit only, so it is built but not unit-tested; it was checked by rendering it.
- `Sources/PanelChrome.swift`: what the Symbols and Stacker windows share: the tab bar (click, or Tab, to switch), the corner resize grip, remembering the window's top-left, and the one-column (compact) setting. Drag the grip narrower and both windows become one column: the picture and a short answer on top, the controls below.
- `Sources/Theme.swift`: the visual styles (Bubblegum pink, and Brutalist black and white, which follows light and dark mode), chosen in the installer and in Settings. Changing the style or the system appearance rebuilds the toolbar and the panels. `MenuIcon` also swaps the input-source icon (`icon-colour.tiff` or `icon-mono.tiff`).
- `Sources/DictionaryModel.swift`, `Sources/DictionaryPanel.swift`: the Dictionary tab and toolbar button. It shows Christian Steinert's Tibetan-English dictionary (dictionary.christian-steinert.de) from its own website in a web view; nothing from it is bundled. Control+Shift+F also opens and closes it. Opening it sends the selected text, or the syllable before the caret, to that site. The panel never takes focus, so there is no search box: the term comes from the document (applications that cannot report their text give no term). The term rules and the URL are tested; the panel was checked by rendering.
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

**Sanskrit suggestions.** In Latin mode, type a Sanskrit word without accents. From three
letters on, a list of up to five accented words appears under it (for example `pratitya` offers
`pratītyasamutpāda` first). Tab accepts the highlighted one, Up and Down move through the list,
Escape or Space keep exactly what you typed; you can also click a suggestion; nothing is replaced unless you choose it. The word is typed straight into the document (no marked text, so no underline); choosing a suggestion replaces the letters before the caret, after checking that they are the typed word (if you moved the caret in between, nothing is replaced). A capital
first letter is kept. The word list is `data/sanskrit/iast-lexicon.tsv` (Monier-Williams and
Edgerton headwords ranked by Digital Corpus of Sanskrit counts; licences (CC BY-NC-SA 3.0 for the dictionary headwords) in
`data/sanskrit/README.md`), measured in `docs/reference/sanskrit-spike.md`. Turn it off in Settings.

**Accent palette.** In Latin mode, hold a letter (a, i, u, r, l, m, h, n, t, d, s; capitals too)
until it repeats and a strip of its IAST variants opens above it (`a` gives `ā`, `s` gives `ś ṣ`,
`n` gives `ṅ ñ ṇ`). Press the number under a variant, or cycle with Tab (it wraps) or the arrow keys and
then press Return or Space, or click one. Letting go of the held key while a variant is highlighted picks it (the key's
state is polled, since an input method gets no key-release event). The plain letter has already been typed, so any other key, or Escape,
keeps it. There is no key-release event in an input method, so the strip stays open after the key
is let go (as the system's own does). With the Sanskrit suggestions on, the variant replaces the
last letter of the word being typed; with them off, a variant letter waits as marked text until
the next key. Holding a letter no longer repeats it. Turn it off in Settings. Logic:
`Sources/AccentPalette.swift` and `Composer.swift` (tested), `Sources/AccentPanel.swift` (not
run in a live input method yet; the log of 2026-11-27 showed that held-key repeats do reach T-Time).

**Shift taps.** Tap left Shift to flip Tibetan and Latin; the mode is remembered when
you move to another field or app (until you flip it again). Double-tap it (within 500 ms) to lock the mode you were
in; the lock survives focus changes and restarts, single taps are ignored while
it is on, and another double tap always clears it. The toolbar's Tibetan and Latin buttons
still work while locked, and the lock then holds the mode you chose. A single tap of right Shift
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

**Menu-bar icon follows the style.** `Resources/icon.tiff` (the file `Info.plist` names) is a link to `/Users/Shared/T-Time/icon.tiff`. The installer's postinstall creates that file from `icon-colour.tiff` or `icon-mono.tiff`, and the app rewrites it (`MenuIcon` in `Theme.swift`) when the style changes, then restarts the menu agents. A link is sealed by its target's name, so the signature holds; but `codesign --strict` and notarization may reject a link that leaves the bundle. Untested for release: check before shipping a notarized build.
