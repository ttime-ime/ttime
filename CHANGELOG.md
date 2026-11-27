# Changelog

## Unreleased

### macOS

- Two looks, Bubblegum (pink, the default) and Brutalist (black and white, set in Didot
  with tracked capitals and hairlines, and following the system's light and dark mode).
  The installer asks which one; Settings switches between them at any time, and the toolbar,
  Symbols and Stacker redraw at once. The Brutalist toolbar is a slim bar with its own
  logos for light and dark, and the panels use the concrete-wall picture.
- The menu-bar input-source icon follows the look: the colour tile for Bubblegum, the black
  pot for Brutalist. `Resources/icon.tiff` is now a link to `/Users/Shared/T-Time/icon.tiff`,
  which the installer and the app write; `codesign --strict` (and so notarization) may
  reject such a link, so check before a notarized release.
- Accent palette in Latin mode: hold a, i, u, r, l, m, h, n, t, d or s (capitals too)
  and a strip of IAST variants opens above the letter (`a` gives `ā`, `s` gives `ś ṣ`).
  Pick with a number key, cycle with Tab then Return or Space, move with the arrow keys,
  or click; letting go of the held key with a variant highlighted picks it. Any other key,
  or Escape, keeps the plain letter. Holding a letter no longer repeats it. On by default;
  switch it off in Settings.
- The Sanskrit suggestion list can be clicked.
- T-Time now remembers the Tibetan/Latin mode when you switch windows, instead of
  returning to the start mode. A lock still overrides it, and the "starts in" setting
  applies only until the first choice.
- The key log now records whether a keypress is a held-key repeat.
