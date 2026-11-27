# T-Time Brutalist Phase 2.3 — report

Final polishing pass. No redesign.

## 1. Files modified

| File | Changes |
|------|---------|
| `macos/Sources/Theme.swift` | `glyphCaption` token; quieter `dimmedFill` / `unavailableFill`; unified `disabledActionFill` / `disabledActionInk` |
| `macos/Sources/StackerPanel.swift` | Selection insets; caption floor; inherent `a` draw path; disabled action parity; quiet unavailable cells; inactive tabs via colour not opacity; `AFFRICATES +`; preview row omit empty chips; document bottom pad **18** |
| `macos/Sources/GlyphCaptionLayout.swift` | Envelope slack bias **0.28** (glyphs closer to captions) |
| `macos/Sources/StackPreviewView.swift` | Optical downward bias (~35–42% of residual slack) |
| `macos/Sources/DictionaryPanel.swift` | Shorter search chrome; more inter-source spacing; no entry rules |
| `experiments/phase1-render/main.swift` | Inherent / unavailable / constrained-600 shots |

Bubblegum sources untouched in behaviour.

## 2. Defects and root causes

| Defect | Root cause | Fix |
|--------|------------|-----|
| Blank inherent vowel `a` when selected | `look == .tile` + `filled` cleared the layer for inset `draw(_:)`, but `usesSharedBaseline` was false (empty caption), so white title drew on a clear background | Include text-only tiles in shared draw; centre Didot `a` in the selection inset |
| Pale Roman captions | Alpha on ink (~0.55 light) | Semantic `glyphCaption` `#666666` / `#A3A3A3` |
| Tsheg “space” flush to selection bottom | Uniform 3 pt inset + caption at `y≈1` | Asymmetric selection (bottom inset 1); caption floor `y≥5` |
| Inconsistent disabled Insert vs Copy/Clear | Primary kept bordered pale fill; secondary used unavailable wash | Shared `disabledActionFill` + muted ink, no border |
| Loud unavailable W/Y blocks | Strong `#D8D8D8` cell fills | Clear background; muted ink only |
| Inactive tabs looked disabled | `alphaValue = 0.4` | Opaque; inactive uses `secondaryText` |
| Empty preview floated high | Residual reserved 24 pt for hidden chips; optical centre too high | Omit empty chip strip; downward optical bias |
| `AFFRICATES, ETC.` wrapped | Label wider than rail | `AFFRICATES +` |
| Marks captions clipped at window bottom | Tight document bottom pad | Bottom pad **18** pt |
| Dictionary search too tall / entries cramped | Topbar padding; tight `.dictName` margins | Shorter search; +~4 pt between sources |

## 3. Semantic tokens (Brutalist)

| Token | Light | Dark |
|-------|-------|------|
| `glyphCaption` | `#666666` | `#A3A3A3` |
| `disabledActionFill` | `hoverFill` `#F4F4F4` | `#1A1A1A` |
| `disabledActionInk` | `mutedText` | `mutedText` |
| `unavailableFill` | `#F2F2F2` (unused for cells; clear bg) | `#141414` |
| `dimmedFill` | `#F0F0F0` | `#1A1A1A` |

Geometry unchanged: content **476**, compose **232\|12\|232×174**, cells **40×50** / **56×52**, header height **34**, top inset **12**.

## 4. Panel dimensions (this machine)

| Panel | Natural height |
|-------|---------------:|
| Brutalist Stacker | **960** |
| Brutalist Symbols | **684** |
| Dictionary target | **640** |
| Stacker minimum | **526** |
| Bubblegum Stacker | **827** (unchanged) |
| Bubblegum Symbols | **745** (unchanged) |

## 5. Glyph-to-caption clearance

- Shared baseline retained; slack distribution biased to **28%** below the envelope (was 50%).
- Caption drawing floor **5 pt** (selection padding).
- Stress inventory still uses measured consonant/tile envelopes; minimum pad **2 pt** inside the plan, with cell height **50** unchanged.
- No return to per-glyph centring.

## 6. Scrolling validation (harness)

| Height | Result |
|-------:|--------|
| 600 | Viewport adapts; alphabet scrolls |
| 700 | `scrolled_top`: Velar first; `scrolled_marks`: Marks glyphs **and** Roman captions visible |
| 800–1000 | Constrained shots written |
| Natural 960 | Full document with top/bottom pads |

`scrollAlphabetToEnd` + document bottom pad **18** keep Marks captions inside the clip. Live trackpad/keyboard confirmation still recommended in the installed IME.

## 7. Dark-mode validation

Re-rendered: `brutal_stacker_dark_empty.png`, `brutal_stacker_dark_sanskrit.png`, `brutal_symbols_dark.png`. Same geometry; original photographs; `glyphCaption` and disabled fills use dark tokens. Fine Didot strokes remain the limiting factor for caption size (unchanged at 10 pt).

## 8. Bubblegum regression

| Shot | Size |
|------|------|
| `bubblegum_stacker.png` | 486×827 |
| `bubblegum_symbols.png` | 480×745 |

Matches Phase 2.1/2.2 baselines.

## 9. Literal `<term>` markup (Dictionary)

Observed in the 84000 Glossary entry as bold literal text. **Not present in T-Time source.** Upstream HTML/data from the remote dictionary site; Bubblegum shows the same content. **Not corrected in this Brutalist-only phase** (per §6.3). Track as a shared data/parsing follow-up if desired.

## 10. Screenshots

`experiments/phase1-render/out/`:

- `brutal_symbols_{light,dark}.png`
- `brutal_stacker_light_{empty,ordinary,prefix,sanskrit,tall,inherent_a,unavailable_subjoined}.png`
- `brutal_stacker_dark_{empty,sanskrit}.png`
- `brutal_stacker_scrolled_{top,marks}.png`
- `brutal_stacker_constrained_{600,700,800,900,1000}.png`
- `bubblegum_{stacker,symbols}.png`

Dictionary live shots still require a networked WKWebView session.

## 11. Deviations / remaining

1. Preview optical bias is strong but empty-state balance may still want a live eyeball pass next to the action row.
2. Natural Stacker **960** remains taller than a short `visibleFrame`; scrolling is intentional.
3. `<term>` deferred (upstream / cross-theme).
4. Hover washes for ordinary consonants still not wired (clear default retained).

## 12. Done criteria

- Symbols captions use `glyphCaption`; selection has bottom padding.
- Stacker preview ink-biased; disabled actions unified; inherent `a` visible; `AFFRICATES +` one line; unavailable cells quiet; Marks captions reachable at 700 pt.
- Dictionary search shortened; inter-source spacing increased.
- Bubblegum unchanged.

**Typographic precision, architectural severity, functional clarity.**
