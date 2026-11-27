# T-Time Brutalist Phase 2.2 — report

Optical refinement and layout stabilisation on the Phase 2.1 foundation. Not a redesign.

## 1. Implementation summary

### Files modified

| File | Change |
|------|--------|
| `macos/Sources/StackerPanel.swift` | Flipped alphabet document + in-document padding; `scrollAlphabetToStart` / `scrollAlphabetToEnd`; clear vowel/mark tile washes; art asset wiring |
| `macos/Sources/Theme.swift` | Softer tile wash; softer `panelBorderColor`; `disabledPrimaryFill` / `disabledPrimaryInk`; consonant/tile inventories (Phase 2.1+2.2) |
| `macos/Sources/PanelChrome.swift` | Brutalist top inset **12** (was 20); header height **34**; quiet close |
| `macos/Sources/SymbolsPanel.swift` | Banner→grid spacing **16**; inset selection draw (shared `BubbleButton`) |
| `macos/Sources/DictionaryPanel.swift` | Denser Brutalist CSS; single search rule; quieter menu/clear; entry separators via hairline |
| `macos/Sources/GlyphCaptionLayout.swift` | Class envelopes: `stackerConsonant` / `stackerTile` |
| `macos/Sources/StackPreviewView.swift` | Optical ink-centred preview (unchanged role; height residual refined) |
| `macos/Resources/stacker-art-brutal.png` | New 4:3 asset from `stacking-brutal-2.png` (1448×1086) |
| `experiments/phase1-render/main.swift` | Phase 2.2 harness shots (scroll top/end, constrained heights) |
| `scripts/build-macos.sh` | Packs `stacker-art-brutal.png` + `StackPreviewView.swift` (from 2.1) |

### Semantic tokens touched

| Token | Brutalist value | Notes |
|-------|----------------:|-------|
| `PanelTabs.insets.top` | **12** | Explicit vertical inset (−8 from Phase 2.1’s 20) |
| `panelBorder` | **1** | Delicate edge |
| `panelBorderColor` | `#D8D8D8` / `#333333` | Softer than control border |
| `tile` | `#F7F7F7` / `#161616` | Available vowels/marks now draw **clear** instead |
| `disabledPrimaryFill` | `hoverFill` | Pale disabled Insert |
| `disabledPrimaryInk` | `mutedText` | Legible, not dark-on-dark |
| `stackerArtHeight` | **174** | Unchanged geometry |
| `composeColumnWidth` / gutter | **232** / **12** | Unchanged |

### Layout decisions

- Alphabet document is a **flipped** host (`lettersDocument`) with **10 pt** top and **12 pt** bottom padding inside the document, not via `contentInsets`.
- Stacker art fills **232×174** (source is already 4:3; same asset in light and dark).
- Category label **AFFRICATES, ETC.**
- Vowel/Marks available tiles: no fill (selection and unavailable still communicate state).

### Deviations

| Spec | Actual | Justification |
|------|--------|----------------|
| Natural Stacker ≈ 820–850 | **954** | Fixed 174 compose + Phase 1 cells + document pads; scrolling remains the fit strategy |
| Live Dictionary screenshots | Harness only | Requires network WKWebView session in the running IME |
| Hover-only cell backgrounds | Not implemented | Would need tracking areas; clear available tiles already lighten the alphabet foot |

Bubblegum is untouched in behaviour and measured size (**486×827** Stacker, **480×745** Symbols).

---

## 2. Root-cause analysis — Velar clipping

### Cause

Two cooperating defects:

1. **`NSScrollView.contentInsets` on an equal-sized document**  
   At natural height the letters viewport was sized to the document height while `contentInsets.top = 4` (and bottom 8) still applied. AppKit then permanently obscured the first/last bands of the document: the Velar headstrokes sat under the clip edge.

2. **Non-flipped document + `scroll(to: (0,0))`**  
   `lettersColumn` (`NSStackView`, bottom-origin) was installed as `documentView`, while a flipped host existed but was unused. Scrolling to `(0, 0)` does not mean “show the first row” for a non-flipped document, so constrained-height “scroll to start” was unreliable.

### Correction

- Install `lettersDocument` (`FlippedHostView`) as the document; embed `lettersColumn` with explicit top/bottom pads.
- Zero `contentInsets` on the letters scroll (scroller insets only).
- `scrollAlphabetToStart()` → `(0, 0)` on the flipped document; `scrollAlphabetToEnd()` → `maxY`.

### Verification

- Natural empty / dark empty: Velar sits below the hairline with measured white clearance above ink (antialiased head, not a hard clip).
- `brutal_stacker_scrolled_top.png` (700 pt): header + compose preserved; Velar is the first alphabet row.
- `brutal_stacker_scrolled_marks.png` (700 pt): Marks row fully in view; compose chrome unmoved.

---

## 3. Measurements (before → after)

| Quantity | Phase 2.1 | Phase 2.2 |
|----------|----------:|----------:|
| Header height | 38 | **34** |
| Header top inset | 20 | **12** |
| Compose | 232 \| 12 \| 232 × 174 | unchanged |
| Art source | portrait webp (letterboxed) | **1448×1086 PNG** (4:3 fill) |
| Alphabet doc top pad | contentInsets 4 | **document pad 10** |
| Alphabet doc bottom pad | contentInsets 8 | **document pad 12** |
| Natural Stacker height | 944 | **954** (+ pads) |
| Stacker minimum | ≈538 | **526** |
| Natural Symbols | 688 | **684** |
| Symbols banner→grid gap | 12 | **16** |
| Stacker cells | 40×50 | unchanged |
| Glyph caption size | 10 Didot | unchanged |
| Consonant envelope | full stress set | **consonant-only** class |
| Dictionary `.dictName` top margin/pad | 10 / 8 | **6 / 6** |
| Dictionary definition bottom margin | 4 | **2** |
| Bubblegum Stacker | 486×827 | **486×827** |

Tab heights this machine: Symbols **684**, Stacker remembered **925**, Dictionary **640**.

---

## 4. Screenshots

All under `experiments/phase1-render/out/`:

| Shot | File |
|------|------|
| Symbols light / dark | `brutal_symbols_light.png`, `brutal_symbols_dark.png` |
| Stacker empty light / dark | `brutal_stacker_light_empty.png`, `brutal_stacker_dark_empty.png` |
| Stacker ordinary / prefix / Sanskrit / tall | `brutal_stacker_light_ordinary.png`, `…_prefix.png`, `…_sanskrit.png`, `…_tall.png` |
| Stacker Sanskrit dark | `brutal_stacker_dark_sanskrit.png` |
| Scroll to Velar (700) | `brutal_stacker_scrolled_top.png` |
| Scroll to Marks (700) | `brutal_stacker_scrolled_marks.png` |
| Constrained 700–1000 | `brutal_stacker_constrained_*.png` |
| Bubblegum regression | `bubblegum_stacker.png`, `bubblegum_symbols.png` |

IME binary rebuilt and signed at `build/macos/T-Time.app` (ad-hoc). Live Dictionary and live scroll-with-IME-focus still need a manual pass in the installed input method.

---

## 5. Remaining issues

1. **Natural Stacker height 954** still exceeds a short laptop `visibleFrame`; alphabet scrolling is required and intentional.
2. **u-chen headstrokes** are optically flat; at small sizes they can *look* cropped even when pixels show clearance — worth a second look in the live panel at 1×.
3. **Dictionary** CSS density/separators are implemented but not screenshot-verified here (network WKWebView).
4. **Hover fills** for ordinary consonant cells are not wired; available vowels/marks are clear instead of wash-filled.
5. **Disabled Insert** uses a pale filled primary; secondary Copy/Clear use bordered unavailable washes — hierarchy is intentional but worth checking beside a black enabled Insert.

---

## 6. Acceptance principle

Brutalist remains: Didot / Baskerville / tracked sans for structure; miserable concrete photographs for weight; no colour; Bubblegum unchanged.

**Elegant typography. Precise geometry. Miserable concrete.**
