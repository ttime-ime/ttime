# Phase 3 — Bubblegum confectionery redesign

## 1. Original problems

- Fixed-offset glyph+caption layout produced uneven vertical spacing and tight tile edges.
- Thick panel border competed with the illustrations.
- Stacker used a three-column composition that under-emphasised the portrait art and crowded actions.
- Character tiles lacked a coherent confectionery surface language (cream tiles, quiet borders, raspberry selection).
- Dictionary looked like an embedded external website with no Bubblegum chrome.
- Latin UI type was system default, not a coherent rounded face.
- Per-tab natural heights and alphabet scrolling existed only for Brutalist.
- Light/dark Bubblegum did not share a semantic strawberry / dark-chocolate palette.

## 2. Architectural changes

| Area | Change |
|---|---|
| `Theme.swift` | Semantic Bubblegum light/dark tokens (`paper`, `tile`, `surface`, `accent`, `selection`, `ink`, …); compose geometry (`composeColumnWidth` 232, `stackerArtHeight` 254); cells 42×52 / 58×54; `usesComposeLayout` / `usesSharedBaselineCells` |
| `BubblegumFonts.swift` | Registers bundled Nunito (SIL OFL); `ui(_:weight:)` with SF Rounded fallback |
| `GlyphCaptionLayout.swift` | Theme-aware `captionFont` (Nunito / Didot); shared-baseline path used by both themes |
| `StackerPanel.swift` / `BubbleButton` | Compose layout + scroll for Bubblegum; confectionery tile chrome; shared-baseline Core Text draw; selection uses `selection` / `selectedInk` / `selectedCaption` |
| `PanelChrome.swift` | Bubblegum width **550** (inner **506**); per-tab heights; confectionery tab pills; quieter close |
| `SymbolsPanel.swift` | Full-aspect illustration (no 120 pt crop); quiet 1 pt outline; centred 7-column grid; Nunito footer |
| `StackPreviewView.swift` | Cream display-case chrome for Bubblegum |
| `DictionaryPanel.swift` | Bubblegum CSS (cream surface, Nunito Latin, cherry ink, raspberry sources) injected once at web-view creation |
| `scripts/build-macos.sh` | Packs `BubblegumFonts.swift` + `Resources/Fonts/Nunito-*.ttf` + OFL |
| `experiments/phase1-render/` | Extended harness for Bubblegum light/dark + Brutalist regression |

Brutalist geometry and Didot/Baskerville presentation are unchanged aside from shared infrastructure generalisation (`usesComposeLayout` instead of `brutal`-only gates).

## 3. Final theme tokens (Bubblegum)

### Light

| Token | Hex | Role |
|---|---|---|
| `paper` | `#FBE8EC` | Strawberry-milk panel |
| `tile` | `#FFF0E2` | Vanilla-cream character tiles |
| `surface` | `#FFF8F6` | Preview / dictionary reading |
| `accent` | `#E98CA4` | Decorative icing |
| `selection` | `#A33D60` | Raspberry-jam selected controls |
| `ink` | `#773047` | Dark-cherry primary |
| `secondaryText` | `#A65A72` | Captions / secondary |
| `controlBorder` | `#EDB2BE` | Quiet outlines |
| `separator` | `#EFCBD4` | Internal rules |
| `selectedInk` | `#FFFFFF` | Selected glyphs |
| `selectedCaption` | `#FFF0E2` | Selected captions |

### Dark

| Token | Hex |
|---|---|
| `paper` | `#302029` |
| `surface` | `#392630` |
| `tile` | `#49303B` |
| `ink` | `#F8DCE4` |
| `secondaryText` | `#D5A5B6` |
| `accent` | `#DF8CA6` |
| `controlBorder` | `#79505F` |
| `separator` | `#593B48` |
| `selection` | `#AD4267` |
| `selectedInk` | `#FFFFFF` |

### Geometry

| Element | Value |
|---|---:|
| Panel radius / border | 24 / 1.5 |
| Cell / tile / action / preset / art | 11 / 11 / 9 / 10 / 14 |
| Stacker cell | 42×52 |
| Symbols cell | 58×54 |
| Compose columns | 232 \| 12 \| 232 |
| Stacker art height | 254 |
| Rail width | 88 |
| Panel width / content | 550 / 506 |

## 4. Typography

- **Latin UI:** Nunito (Regular / Medium / SemiBold / Bold / ExtraBold), bundled under `Resources/Fonts/`, licence `OFL-Nunito.txt`.
- **Verified in harness:** `UI_FONT=Nunito-Bold family=Nunito`.
- **Fallback:** SF Rounded → system, if registration fails.
- **Tibetan:** unchanged Noto Serif Tibetan + Core Text shaping.
- **Brutalist:** Didot / Baskerville / tracked caps unchanged.

## 5. Before / after measurements

| Metric | Pre–Phase 3 Bubblegum | Phase 3 |
|---|---:|---:|
| Panel width | 480 | **550** |
| Content width | 436 | **506** |
| Stacker natural height | ~827 | **1092** (full alphabet document) |
| Stacker minimum height | = natural | **612** (compose chrome + viewport) |
| Symbols natural height | shared with Stacker | **634** (independent) |
| Stacker cell | 38×38 | **42×52** |
| Symbols cell | 56×46 | **58×54** |
| Panel border | 3 | **1.5** |
| Compose art height | n/a (narrow column) | **254** (~50:50) |

Brutalist regression (harness): width **520**, stacker natural **960**, min **526**, symbols **684**, cells **40×50** / **56×52** — unchanged.

## 6. Screenshot locations

All under `experiments/phase1-render/out/`:

**Bubblegum Symbols:** `bubblegum_symbols_light.png`, `bubblegum_symbols_light_selected.png`, `bubblegum_symbols_dark.png`

**Bubblegum Stacker:** `bubblegum_stacker_light_empty.png`, `_ordinary.png`, `_prefix.png`, `_sanskrit.png`, `_tall.png`, `_inherent_a.png`, `_marks.png`, `_unavailable_subjoined.png`, `bubblegum_stacker_scrolled_top.png`, `_scrolled_marks.png`, `bubblegum_stacker_constrained_{700,800,900}.png`, `bubblegum_stacker_dark_empty.png`, `_dark_sanskrit.png`

**Brutalist regression:** `brutal_stacker_light_empty.png`, `_ordinary.png`, `_sanskrit.png`, `brutal_symbols_light.png`, `brutal_stacker_dark_empty.png`, `brutal_symbols_dark.png`

Dictionary welcome / entry shots require the live WKWebView + network; CSS is injected at panel build (same lifecycle as Brutalist). Validate in the installed IME.

## 7. Functional regression checks

| Check | Result |
|---|---|
| Shared-baseline cells (consonants, vowels, marks, symbols) | Pass (Core Text draw path) |
| Tall Sanskrit preview (k+Sh+i) without clip | Pass |
| Alphabet scroll top / Marks | Pass (harness; save must not re-`adaptLettersHeight`) |
| Constrained 700 / 800 / 900 | Pass (floor 612) |
| Unavailable W/Y distinct from dimmed / selected | Pass (unavailable fill + muted ink) |
| Inherent `a` selected | Pass |
| Brutalist layout / Didot / 50:50 / banner | Pass (regression shots) |
| Nunito bundled + loadable | Pass |
| Toolbar redesign | Out of scope (unchanged) |
| Dictionary latency / Tab navigation | Not altered architecturally; separately tracked |

## 8. Deviations from specification

1. **Tile dimension treatment:** Flat cream tiles with 1 pt quiet borders retained after comparison against heavier dimensional shadows — keeps cuteness without visual noise.
2. **Symbols banner height token:** `symbolsBannerHeight = 0` means natural artwork aspect (not Brutalist’s 120 pt crop), as specified.
3. **Optional decorative interactions** (paw-print tab indicator, sparkle, candy scrollbar): deferred; static design first.
4. **Dictionary screenshots:** not captured in the offline harness; CSS + attribution footer path implemented for live validation.
5. **Natural Stacker height (1092)** exceeds typical screen height (~949); opening clamps and scrolls — intentional, matching Brutalist’s approach.

## 9. Remaining issues

- Dictionary welcome / long-entry visual polish should be confirmed in the installed IME against the live Steinert site.
- Latin-subset Nunito may miss rare diacritics in edge captions (fallback to system rounded).
- Existing Dictionary latency and Tab-in-WebView issues remain separately tracked.
- Portrait Stacker art aspect at 232×254 may letterbox slightly depending on asset; ideal replacement size ≈ **928×1016** (@2×) if a new asset is commissioned later — no new art in this phase.

## 10. Recommendations

1. Validate Dictionary light/dark in the installed app; tweak welcome CSS only if upstream markup requires it.
2. Consider a modest optional hover warmth token once Reduce Motion policy is wired for decorative experiments.
3. Toolbar Bubblegum pass (separate phase) should reuse the same semantic palette and Nunito.
4. Keep measuring cell clearance with the existing harness whenever Tibetan inventory or caption size changes.
