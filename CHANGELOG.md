# Changelog

## Unreleased

- Windows and Linux scaffolds (`windows/`, `linux/`) plus a shared C harness
  (`ffi-smoke/`) that links `ttime-ffi` and types one EWTS syllable. CI builds and runs
  it on Ubuntu and Windows; there is no TSF or IBus IME yet.
- The typing behaviour (composer, long-press accents, Sanskrit suggestions, the Shift-tap
  mode lock and its timing, Stacker and Symbols window state, dictionary term rules) now
  lives in `ttime-core` and reaches the shells through the C interface (`ttime.h`), so
  Windows and Linux versions can share it. The macOS Swift sources are thin wrappers;
  nothing is drawn differently. The key-policy tests run in Rust and again through the
  Swift wrappers.
- The Sanskrit word list is parsed once, in the background, and shared by every window;
  switching apps no longer waits for it.
- Sanskrit word list: five garbled entries (stray half-width Hangul from the corpus data,
  such as `kﾱp`) are removed, and the build script now leaves such lemmas out.
- Symbols: paluta (U+0F85) no longer gets a dotted circle; it is punctuation, not a mark.
- Stacker: switching between precomposed and decomposed output rebuilds the current stack.

## 0.1.0-rc.7

- Fix the release build: the menu-bar icon is a real file again (rc.6's link outside the
  app was rejected by notarization, so rc.6 was never published). The installer puts in the
  mono icon when Brutalist is chosen; changing the style in Settings later does not change it.

## 0.1.0-rc.6


### macOS

- The dictionary page is no longer loaded when T-Time starts: nothing is sent to the
  dictionary's website until you open the Dictionary tab.
- Symbols and Stacker: a long label (the digits) shrinks to fit its cell instead of being
  cut off; the Stacker opens at most 780 pt tall (your own size is remembered, and is now
  saved once when you let go of the resize grip, not on every mouse move).
- **T-Time Tools** companion app (`/Applications/T-Time Tools.app`, same installer
  as the IME): convert between Tibetan and Wylie (EWTS) via the Services menu
  (Auto-convert, Wylie → Tibetan, Tibetan → Wylie) or a converter window with
  Copy. Auto chooses direction from the script. Assign a Services keyboard
  shortcut in System Settings. It is an optional choice in the installer. App
  Intent code is included, but Shortcuts will not list it until a later metadata pass. The IME menu has **Open
  Converter…**, which seeds the window from the selection when the host can
  report it. Batch convert APIs are on the C ABI (`ttime_convert`,
  `ttime_unicode_to_ewts`).
- Symbols, Stacker and Dictionary are now one navigator: the same window width, height and
  position, and the same header (the T-Time title in Brutalist, the three tabs, and the close
  button) on every tab, so switching tabs changes only what is inside and nothing moves under
  the pointer. They are always one column; drag the corner grip to change the height (the
  width is fixed, and the height is never less than the Stacker needs). The two-column layouts
  are no longer used. The Brutalist Stacker has a new picture (`stacker-art-brutal.webp`,
  from `visual_design/reference/stacking-brutal.png`).
- The toolbar's Tibetan and Latin buttons always work. The lock now only stops Shift taps from
  switching; choosing a mode on the toolbar while locked changes it, and the lock holds the mode
  you chose across fields and apps until you unlock.
- Two looks, Bubblegum (pink, the default) and Brutalist (black and white, set in Didot
  with tracked capitals and hairlines). Both follow the system's light and dark mode.
  The installer asks which one; Settings switches between them at any time, and the toolbar,
  Symbols and Stacker redraw at once. The Brutalist toolbar is a slim bar with its own
  logos for light and dark, and the panels use the concrete-wall picture.
- The menu-bar input-source icon follows the look: the colour tile for Bubblegum, a solid
  white pot on a black tile (no outline, so it reads on a light or a dark menu bar) for
  Brutalist, chosen at install time.
- Dictionary tab (third tab beside Symbols and Stacker, a toolbar button, ཚིག, and the shortcut
  Control+Shift+F): shows
  Christian Steinert's online Tibetan-English dictionary (dictionary.christian-steinert.de) in
  a web view. It looks up the selected text, or the syllable before the caret; with neither,
  it opens the dictionary's own page. It needs an internet connection, and opening it sends
  the term to that site; nothing from the dictionary is bundled. Click into the page and it
  takes the keyboard (scrolling, menus, dragging, the search box, Cmd+V); while it has the
  keyboard T-Time passes keys through, so typing there is plain Latin, not EWTS. Esc always
  closes it, and the keyboard goes back to the document's application.
- Brutalist tabs are smaller (16 pt) so three tabs fit beside the title.
- Accent palette in Latin mode: hold a, i, u, r, l, m, h, n, t, d or s (capitals too)
  and a strip of IAST variants opens above the letter (`a` gives `ā`, `s` gives `ś ṣ`).
  Pick with a number key, cycle with Tab then Return or Space, move with the arrow keys,
  or click; letting go of the held key with a variant highlighted picks it. Any other key,
  or Escape, keeps the plain letter. Holding a letter no longer repeats it. On by default;
  switch it off in Settings.
- The Sanskrit suggestion list can be clicked.
- Sanskrit suggestions no longer underline the word being typed. Letters now go straight
  into the document and choosing a suggestion (Tab, click or an accent pick) replaces the
  typed letters, after checking they are still just before the caret; if the caret moved,
  nothing is replaced. Previously the word was marked text, which many applications
  underline and which cannot be turned off from an input method.
- The key log (opt-in) now also records, per key, how long T-Time took and where the time
  went, plus whether suggestions were on and how many were offered. It never records the
  characters typed.
- T-Time now remembers the Tibetan/Latin mode when you switch windows, instead of
  returning to the start mode. A lock still overrides it, and the "starts in" setting
  applies only until the first choice.
- The key log now records whether a keypress is a held-key repeat.
