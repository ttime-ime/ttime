# T-Time Brutalist Phase 2.1 — report

## 1. Root causes of runtime layout defects

| Defect | Root cause |
|--------|------------|
| Symbols / Dictionary inherited Stacker height | `PanelTabs.height()` always used Stacker’s natural/remembered size for every tab |
| Empty space under Symbols grid | Shared tall height + `adaptHeight` expanded the scroll viewport far past the document |
| Composition past right margin | Marks row (~510 pt with wide rail) drove `contentWidth` above the 476 pt content rectangle |
| Clipped Tibetan preview | `NSTextField` + fixed 52 pt height + Noto’s oversized line box |
| Alphabet inaccessible / “no scroll” | Auto Layout document view without a viewport shorter than the document; harness also adapted scroll to a stale `panel.frame` |
| Vertical jump when adding letters | Layer chips grew the composition column; no fixed compose height |
| Inconsistent margins | Child widths derived from `max(inner, marks.fittingSize)` instead of a single content rectangle |

## 2. Files modified

- `macos/Sources/Theme.swift` — compose/rail/banner/action tokens
- `macos/Sources/PanelChrome.swift` — per-tab heights; compact single-line header; quiet close
- `macos/Sources/StackerPanel.swift` — 50:50 composition; stable height; scroll document; layer chips; states
- `macos/Sources/StackPreviewView.swift` — **new** Core Text preview with fit-to-bounds scaling
- `macos/Sources/SymbolsPanel.swift` — 476×120 aspect-fill banner; 7-col gap; natural height; footer rule
- `macos/Sources/DictionaryPanel.swift` — Brutalist-only WKWebView CSS injection
- `macos/Resources/symbols-brutal.png` — landscape banner asset
- `scripts/build-macos.sh` — pack `StackPreviewView.swift` + `symbols-brutal.png`
- `experiments/phase1-render/main.swift` — Phase 2.1 harness shots

## 3. Theme tokens (new / revised)

| Token | Brutalist |
|-------|-----------|
| `composeColumnWidth` | **232** |
| `composeGutter` | **12** |
| `stackerArtHeight` | **174** |
| `railWidth` | **92** |
| `stackerGapX` | **2** (Marks fits in 476) |
| `symbolsGapX` | **14** (7×56 + 6×14 = 476) |
| `symbolsBannerHeight` | **120** |
| `previewNominalSize` | **52** |
| `actionButtonHeight` | **26** |
| `hoverFill` | light `#F4F4F4` / dark `#1A1A1A` |
| Cell sizes | **40×50** / **56×52** unchanged |

Content rectangle: width **520**, insets **20 / 22 / 20 / 22**, inner **476**.

## 4. Final measured layout dimensions

| Element | Value |
|---------|------:|
| Panel width | 520 |
| Content width | 476 |
| Compose columns | 232 \| 12 \| 232 |
| Compose height (fixed) | 174 |
| Header height | 38 |
| Symbols banner | 476 × 120 (aspect-fill) |
| Stacker cells | 40 × 50 |
| Symbols cells | 56 × 52 |

## 5. Natural heights (this machine)

| Panel | Natural height |
|-------|----------------|
| Bubblegum Stacker | **827** (unchanged) |
| Brutalist Stacker | **944** (taller compose art; scrolls below screen) |
| Brutalist Symbols | **688** |
| Dictionary (bounded) | **640** target |
| Screen `visibleFrame` | **949** |
| Stacker minimum (scroll floor) | **≈538** |

Per-tab remembered heights: `NavigatorHeight.<tabRawValue>` when Brutalist.

## 6. Preview ink-bound behaviour

`StackPreviewView` shapes the full string as one `CTLine`, measures with `CTLineGetImageBounds`, and binary-searches point size down from 52 until ink fits the fixed preview rectangle (pad 6). Layout dimensions do not change with stack complexity.

Stress coverage in harness: empty placeholder, ordinary `k`, `k+Shi`, `ch+g+ng+ny`, prefix `r`.

## 7. Scroll viewport / document

- Fixed chrome: header → composition (174) → instructions → presets → hairline  
- Flexible: `lettersScroll` viewport = `panelHeight − chrome`  
- Document: `lettersColumn` width 476, height from cell arithmetic (≥ full inventory)  
- Verified: natural-height shots show Marks ink in the lower bands; 700 pt constrained shots keep composition fixed and alphabet in a shorter viewport  

## 8. Horizontal containment

- Brutalist `contentWidth` capped at `PanelTabs.innerWidth` (476)  
- Category labels abbreviated: **AFFRICATES**, **SUBJOINED**  
- Rail width 92 + gap 2 → Marks `92 + 8 + 9×40 + 8×2 = 476`  
- Symbols: 7 columns with gap 14 span 476 edge-to-edge  

## 9. Dictionary typography decisions

External `WKWebView` (christian-steinert.de). Brutalist injects scoped CSS only:

- Paper/ink dynamic for light/dark  
- Search: borderless bottom-rule field (Baskerville 18)  
- Headword `.definitionHead`: large Tibetan serif  
- Source `.dictName`: 10 pt tracked uppercase system sans, secondary ink, no dotted underline  
- Definitions `.definition`: Baskerville ~15 / 1.4  
- Bubblegum keeps the previous top-bar padding-only inject  

## 10. Screenshot locations

`experiments/phase1-render/out/`

- Stacker light: empty, ordinary, prefix, Sanskrit, tall  
- Stacker dark: empty, Sanskrit  
- Stacker constrained: 700 / 800 / 900 / 1000; scrolled_marks  
- Symbols light / dark  
- Bubblegum regression: `bubblegum_stacker.png`, `bubblegum_symbols.png`  

Dictionary screenshots require a live network session in the running app (not fully automated here).

## 11. Bubblegum regression

Bubblegum Stacker **486×827**, Symbols **480×745** — matches pre–Phase 2.1 sizes. Three-column compact compose and pink chrome preserved.

## 12. Remaining defects / limitations

1. **Stacker natural height 944 > 820–850.** Fixed 174 pt art column + Phase 1 cells dominate; scrolling is the intended fit strategy on short screens.  
2. **Portrait stacker art in a 232×174 (≈4:3) slot** is scaled proportionally (letterboxed). A dedicated **232×174 (or 4:3) landscape stacker asset** would fill the column without empty bands.  
3. **Very tall stacks** may still feel tight against layer chips; preview scales down rather than clipping, but chips + preview share the 174 pt column.  
4. **Dictionary CSS** depends on the site’s class names (`dictName`, `definitionHead`, `_topbar_*`, …); upstream renames would need a follow-up.  
5. **Harness vs live panel:** scroll adaptation now uses `PanelTabs.height(for:)` when the panel is hidden; live open paths call `adaptLettersHeight` from the real frame.

## 13. Deviations from the specification

| Spec | Actual | Rationale |
|------|--------|-----------|
| Symbols banner “correct proportions” at 476×120 | Aspect-fill centre crop of 2172×724 asset | Meets 476×120 target without stretching; slight vertical crop of concrete, vessel remains centred |
| Stacker art 4:3 filled | Proportional fit of portrait `stacker-art-brutal.webp` | Avoid distorting or cropping the teacup; dedicated 4:3 asset recommended |
| Natural Stacker 820–850 | 944 | Spec forbids sacrificing cell typography or illustration quality for an arbitrary height |
| Category “AFFRICATE, W, Z” | **AFFRICATES** | Horizontal containment |
| “Under a letter” | **SUBJOINED** | Same |
