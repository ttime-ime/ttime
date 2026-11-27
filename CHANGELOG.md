# Changelog

## Unreleased

### macOS

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
  with tracked capitals and hairlines, and following the system's light and dark mode).
  The installer asks which one; Settings switches between them at any time, and the toolbar,
  Symbols and Stacker redraw at once. The Brutalist toolbar is a slim bar with its own
  logos for light and dark, and the panels use the concrete-wall picture.
- The menu-bar input-source icon follows the look: the colour tile for Bubblegum, a solid
  white pot on a black tile (no outline, so it reads on a light or a dark menu bar) for
  Brutalist. `Resources/icon.tiff` is now a link to `/Users/Shared/T-Time/icon.tiff`,
  which the installer and the app write; `codesign --strict` (and so notarization) may
  reject such a link, so check before a notarized release.
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
