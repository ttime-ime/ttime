# Phase 3.6 — Bubblegum final polish

## 1. Files modified

| File | Role |
|---|---|
| `macos/Sources/Theme.swift` | Density tokens; biscuit/paw experiment flags |
| `macos/Sources/StackerPanel.swift` | Full-tile Bubblegum selection; caption floor; compose density; biscuit edge draw |
| `macos/Sources/StackPreviewView.swift` | Empty-placeholder optical centre (Bubblegum) |
| `macos/Sources/SymbolsPanel.swift` | Edge-aligned 7-col gap derivation; footer spacing |
| `macos/Sources/PanelChrome.swift` | Insets; optional paw motif |
| `macos/Sources/DictionaryPanel.swift` | Search alignment CSS; source colour; reading pad/rhythm |
| `experiments/phase1-render/main.swift` | Comparison shots + metrics |
| `experiments/phase1-render/PHASE3.6-BUBBLEGUM-REPORT.md` | This report |

Brutalist token values and drawing paths were not changed (inset selection retained for Brutalist only).

## 2. Problems and causes

| Problem | Cause |
|---|---|
| Right column short of separator | Compose columns fixed at 232+12+232=476 while content width was 506 |
| Selected tiles looked smaller | Brutalist-style inset selection fill inherited by Bubblegum |
| Captions tight to tile bottom | Caption baseline used a weak floor; descent not fully reserved |
| Empty preview sat low | Optical-down bias meant for Brutalist placeholders |
| Stacker taller than screen | Composition 254 pt + generous vertical gaps |
| Symbols grid floated inward | Independent horizontal centering + fixed 8 pt gaps |
| Dictionary clear control misaligned | Upstream absolute/flow styles; wrap not flex-centred |
| Source labels too bright | Used icing `accent` (#E98CA4) instead of darker raspberry |

## 3. Changes implemented (mandatory)

- Compose columns **247|12|247** → span equals content width **506**.
- Composition height **254 → 224** (−30 pt); preview↔buttons gap **~8 pt**.
- Root/section/row spacing tightened (8/6/4 → 6/4/3).
- Cell/tile radius **11 → 8.5** (biscuit, not telephone key).
- Bubblegum selection fills the **full tile** (Brutalist keeps inset).
- Caption optical bottom clearance ≈ **4.5 pt** (baseline ≥ clearance + descent).
- Empty preview ink centred when placeholder alpha is low.
- Symbols: fixed **7** columns; gap = `(innerWidth − 7×cellW) / 6` (edge-aligned).
- Dictionary: flex-centred search chrome; clear/menu 28×28; reading inset **14 px**; source `#A34465` / dark `#E0A0B4`; source–definition / between-source rhythm.

## 4. Semantic tokens added or modified

**Modified (Bubblegum only):** `cellRadius`, `tileRadius`, `actionRadius`, `presetRadius`, `stackerGapY`, `rootSpacing`, `sectionSpacing`, `presetHeight`, `stackerArtHeight`, `composeColumnWidth`, `previewNominalSize`, `actionButtonHeight`; insets top/bottom.

**Added (experimental, default off):** `Theme.bubblegumBiscuitEdge`, `Theme.bubblegumPawMotif`.

**Dictionary CSS:** dedicated `source` colour (not a new Theme property — kept palette small).

## 5–6. Before / after dimensions

| Metric | Phase 3.0 | Phase 3.6 | Δ |
|---|---:|---:|---:|
| Panel width / inner | 550 / 506 | 550 / 506 | 0 |
| Compose column / span | 232 / 476 | **247 / 506** | +15 / +30 |
| Art / compose height | 254 | **224** | −30 |
| Stacker natural height | 1092 | **1032** | **−60** |
| Stacker minimum height | 612 | **565** | −47 |
| Symbols natural height | 634 | **620** | −14 |
| Cell radius | 11 | **8.5** | −23% |
| Stacker gap Y | 4 | **3** | −1 |

Brutalist regression (unchanged): width **520**, stacker natural **960**, min **526**, symbols **684**.

## 7. Glyph / caption clearances

- Shared-baseline plan pad (Bubblegum): **3.5** (was 2).
- Caption ink floor: **≥ 4.5 pt** above tile bottom (`baseline ≥ 4.5 + descent`).
- Glyph–caption clearance still governed by envelope + plan slack (unchanged engine); pad increase shifts caption band slightly taller without shrinking Tibetan ink budget below Phase 3.0 cell size (**42×52** / **58×54** retained).

## 8. Scroll viewport

| Height | Result |
|---:|---|
| 600 | Clamped to floor **565**; alphabet scrolls |
| 700 / 800 / 900 | Scrolling; Marks reachable (`scrolled_marks`) |
| Natural 1032 | Full document; still above typical screen (~949) → scroll on open |

## 9. Screenshot locations

`experiments/phase1-render/out/`:

- Bubblegum light/dark Stacker & Symbols (updated)
- `p36_tiles_flat.png` / `p36_tiles_biscuit.png`
- `p36_header_plain.png` / `p36_header_paw.png`
- Brutalist regression: `brutal_stacker_*`, `brutal_symbols_*`

Dictionary welcome/results: CSS updated; capture in the live IME (network).

## 10. Optional decorative experiments

| Experiment | Result | Ship? |
|---|---|---|
| Squarer radius (8.5) | Clearer biscuit shape; still soft | **Yes (mandatory polish)** |
| Biscuit lower edge | Visible in `p36_tiles_biscuit.png`; subtle but busy at full-grid density | **No** — leave flag off |
| Paw motif | `p36_header_paw.png`; emoji paw is coarse vs toolbar art | **No** — leave flag off; revisit with a tiny vector asset if desired |
| Insertion sparkle | Omitted — IME insert/dismiss path makes reliable non-blocking feedback impractical | **No** |

## 11. Functional regression

| Check | Result |
|---|---|
| Shared-baseline / Sanskrit preview | Pass (harness) |
| Selection outer size (Bubblegum) | Pass (full-tile fill) |
| Alphabet scroll top / Marks | Pass |
| Brutalist appearance | Pass (regression shots match prior metrics) |
| Theme / appearance switching | Untouched paths; flags default off |
| Dictionary Tab / latency | Still separately tracked — not claimed fixed |

## 12. Remaining / deviations

1. **Natural Stacker height 1032** still exceeds many screens (~949). Measured recovery **60 pt** (target band 60–100). Further cuts would require shrinking cell height or glyph pad — rejected to protect clearance.
2. **Panel width** kept at 550: Marks row (9×42 + gaps + rail) still needs content width 506.
3. **Dictionary** live visual confirmation of clear-button geometry still recommended after install.
4. Biscuit edge and paw remain behind flags for future review; not enabled in production.

### Design decisions forced by measurement

- Compose width raised to **247** so the right edge meets the content rectangle (not an arbitrary aesthetic widen).
- Height recovery prioritised unused gaps and composition chrome over tile interiors.
- Caption floor uses **descent-aware** baseline math rather than a blind upward nudge that would collide with tall stacks.
