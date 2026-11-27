# T-Time Brutalist Phase 2 — report

## Verdict

Phase 2 composition and spatial-economy changes are in place. Brutalist Stacker natural height moved from **974 → 889 pt** (−85). Target band was 820–850; the remaining ~39–69 pt is almost entirely the locked Phase 1 alphabet (40×50 cells). On this machine `NSScreen.visibleFrame` height is **949 pt**, so the natural panel fits without scrolling. Below that, the alphabet scrolls while composition controls stay put. Bubblegum is unchanged (**827 × 486** stacker).

## Screenshots

All under `experiments/phase1-render/out/`:

| Shot | File |
|------|------|
| Stacker light, empty | `brutal_stacker_light_empty.png` |
| Stacker light, Sanskrit stack | `brutal_stacker_light_sanskrit.png` |
| Stacker light, typing prefix `r` | `brutal_stacker_light_prefix.png` |
| Stacker dark, empty | `brutal_stacker_dark_empty.png` |
| Stacker dark, Sanskrit | `brutal_stacker_dark_sanskrit.png` |
| Symbols light / dark | `brutal_symbols_light.png`, `brutal_symbols_dark.png` |
| Constrained 700 / 800 / 900 / 1000 | `brutal_stacker_constrained_*.png` |
| Bubblegum regression | `bubblegum_stacker.png`, `bubblegum_symbols.png` |

Before (Phase 1 end): Stacker **532×974**, Symbols banner ~307 pt tall. After: Stacker **520×889**, Symbols **520×592** with banner **120 pt**.

## Files modified

- `macos/Sources/StackerPanel.swift` — two-column composition; horizontal Insert/Copy/Clear; letters `NSScrollView`; preview height cap; state paints
- `macos/Sources/SymbolsPanel.swift` — `BannerView` fixed-height letterbox
- `macos/Sources/Theme.swift` — art/banner heights, fills, spacing tokens
- `macos/Sources/PanelChrome.swift` — `availableHeight`, height clamp / proposed size (unchanged this pass; already wired)
- `experiments/phase1-render/main.swift` (+ stubs) — measurement harness

## Theme tokens (new / changed)

| Token | Brutalist value | Notes |
|-------|-----------------|-------|
| `stackerArtHeight` | **110** | Was ~146-wide aspect height; now fixed |
| `symbolsBannerHeight` | **120** | Replaces ~307 pt image-driven height |
| `dimmedFill` | light `#E6E6E6` / dark `#222222` | Prefix-mismatch wash |
| `unavailableFill` | light `#D8D8D8` / dark `#181818` | Disabled wash |
| `rootSpacing` | **6** | Was 8–9 |
| `sectionSpacing` | **4** | Was 6–9 |
| Cell sizes | **40×50** / **56×52** | Unchanged from Phase 1 |
| `presetHeight` / radius | **24** / **4** | Unchanged |

Content margin remains `PanelTabs.insets` **20 / 22 / 20 / 22**.

## Space recovered (approx.)

| Change | Δ height |
|--------|----------|
| Two-column compose + horizontal actions (vs art \| card \| vertical buttons) | ~35–45 pt |
| Drop Brutalist card padding / min-height lock | ~20–25 pt |
| Art height 146-aspect → 110 | ~20–30 pt |
| root / section / custom spacing trim | ~15–20 pt |
| Action button strip 32 → 28 | ~4 pt |
| Preview typographic box capped (Noto ~2.8×) | prevents +40–80 overflow |
| **Symbols banner 307 → 120** | **~187 pt** on Symbols panel |
| **Net Stacker** | **974 → 889 (−85)** |

## Symbols banner asset needed

Temporary presentation: full content-width banner (**476 pt** inner), height **120**, square corners, existing portrait asset **letterboxed** on paper (not stretched, not cropped).

**Final landscape asset:** **476 × 120 pt** (at 2×: **952 × 240 px**), aspect **≈ 3.97∶1**.

## Display compatibility

| Available height | Behaviour |
|------------------|-----------|
| 1000 / 949 (this screen) | Natural 889 fits |
| 900 | Fits at natural |
| 800 / 700 | Panel clamped; alphabet scrolls; chrome floor **≈ 483** |

## Interaction states

Monochrome distinction without opacity-only cues:

- **Available** consonants: clear fill, full ink  
- **Selected**: ink fill, paper ink  
- **Prefix-mismatched**: `dimmedFill` + secondary ink  
- **Unavailable**: `unavailableFill` + muted ink  
- **Primary Insert** disabled: secondary fill, paper@0.55 label (still legible)

## Deviations

1. **Natural height 889 vs 820–850.** Further cuts would require smaller cells (forbidden), smaller Didot chrome (forbidden), or defaulting to a scrolled alphabet on large screens. Scrolling already covers short displays.
2. **Symbols banner uses letterboxing** until a 476×120 asset exists.
3. **Toolbar / secondary popovers / dictionary CSS** untouched, as specified.

## Remaining notes

- Category rail labels (`AFFRICATE, W, Z`) are long; they still align to row centres but consume horizontal inset.
- On very short heights the scroll viewport shows mid-alphabet first until focus scrolls the focused cell into view — worth a follow-up if keyboard focus sync feels jumpy.
- Bubblegum stacker/symbols pixel sizes match the pre-Phase-2 regression baseline (827 / 745).
