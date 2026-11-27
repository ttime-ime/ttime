# Glyph / caption layout experiment

Prototype harness for fixing Tibetan glyph vs Roman transliteration collisions in `BubbleButton`, without changing the live IME theme yet.

## Run

```sh
cd experiments/glyph-caption-layout
swift measure_and_render.swift
open out/compare_approaches.png
```

Outputs (under `out/`):

| File | Meaning |
|---|---|
| `metrics.json` | Ink bounds, sweep results, minima, recommendation text |
| `compare_approaches.png` | Side-by-side of the main strategies |
| `NN_*.png` | Full sample grids with guides (blue = ink, orange = caption band, red = baseline) |
| `bubblegum_control.png` | Colour/path reminder that Bubblegum stays on fixed offsets |

`GlyphCaptionLayout.swift` is the proposed API shape for a later Brutalist-only integration (not wired into the app).

## Measurement method

For each sample string, Core Text shapes a `CTLine` with Noto Serif Tibetan, then `CTLineGetImageBounds` records **ink** relative to the typographic baseline. That preserves Sanskrit stacking (unlike iterating code points / raw glyph paths without the layout engine).

Typographic line height at 15 pt is ~42 pt; measured ink for the worst stack is only ~24 pt (~0.57×). Ordinary letters are ~9–12 pt tall. Relying on the line box wastes space and still collides when labels are centre-stacked with fixed offsets.

## Strategies tested

1. **currentFixed** — today’s `centerY − 4` / `bottom − 3`
2. **typoPack** — reserve the full font line box above a caption band
3. **inkCenterEach** — centre each cell’s ink in the glyph band (baselines wander)
4. **sharedBaselineInk** — one shared baseline; envelope from max ink; pinned above caption
5. **sharedBaselineCentered** — same, but centre the envelope in leftover slack

## Recommendation (Brutalist only)

Use **sharedBaselineCentered** with a precomputed ink envelope over the stacker alphabet + Sanskrit stress set.

| Glyph | Caption | Caption band | Max ink ↑ / ↓ | Min cell height | Suggested cell |
|---|---|---|---|---|---|
| 15 | Didot 10 | 16 | 16.6 / 8.0 | **45** | **46×40** (stacker) |
| 15 | Didot 11 | 17 | 16.6 / 8.0 | **46** | **46×40** |
| 18 | Didot 10 | 16 | 19.9 / 9.6 | **50** | **52×56** or keep H=46 and use glyph 15–16 |
| 18 | Didot 11 | 17 | 19.9 / 9.6 | **51** | same |

Keep **Bubblegum** on the existing fixed-offset + monospaced 9 pt caption path until a theme flag selects the new layout.

## Trade-offs

| Approach | Fits compact cells? | Shared baseline? | Notes |
|---|---|---|---|
| currentFixed | No (clearance −6…−13) | Accidental | Collides; overflows typographic box |
| typoPack | No (needs ~58+ pt) | Yes | Line box too tall vs ink |
| inkCenterEach | Yes from **42** pt @ glyph 15 | **No** (~8 pt wander) | Compact but uneven row |
| sharedBaseline* | Yes from **46** pt @ glyph 15 | **Yes** | Best match to editorial grid |

See `out/metrics.json` for full numbers.
