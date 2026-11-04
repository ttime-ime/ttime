# 0004: Additional input layouts (Sambhota, TCC, Monlam)

**Status:** Proposed, 4 November 2026. Nothing implemented. Key tables are not yet
sourced (see "Open questions").

## Context

T-Time has one Tibetan input scheme, EWTS. Users have asked for three layouts that
are in wide use among Tibetans and are not transliteration schemes in the EWTS
sense:

- **Sambhota Keymap One** (Nitharta). A partial-Wylie keyboard with one key per
  Tibetan letter. Aspirates are the capital of the column letter (`K` for kha,
  `T` for tha) instead of `kh`, `th`. Stacks use a `+` key. THL describes it as
  widely used by Tibetans in China, India and Nepal.
- **Tibetan Computer Company (TCC) Keyboards #1 and #2.** #1 is a positional
  "ka-kha-ga-nga" layout: Q=ka, W=kha, E=ga, R=nga, continuing along the rows,
  with the vowels in the middle of the second row. THL describes it as popular in
  Nepal and India. How #2 differs was not found.
- **Monlam Bod-yig.** Ships with the Monlam fonts and input methods for Windows
  and Mac, with four layouts, one based on the TCRC layout. Its key mapping and
  stacking behaviour were not found.

All three are listed in the THL pages "Tibetan Input System Principles" and
"Legacy Tibetan Input Methods for Windows". Sambhota Keymap One and TCC #1/#2 are
also input methods in the Jskad editor. THL names Sambhota Keymap 1, TCC
Keyboard #1 and THL Extended Wylie as the most common at the time of writing
(the page is old).

The earlier plans ruled this out until a concrete requirement appeared
(`ttime_ime_toolbar_settings_plan.md` section 3.1; non-goals in
`tibetan_ewts_ime_plan.md`). This is that requirement.

## Decision

1. **Offer all three families**, as selectable input schemes beside EWTS. EWTS
   stays the default.
2. **Two kinds of scheme, one selector.** The core gains a notion of "input
   scheme" with two implementations:
   - *Transliteration schemes* (EWTS, and Sambhota, which differs from EWTS in
     its aspirate letters and its `+` stacking key). These go through the
     existing composition engine, with the scheme supplying its own letter table.
   - *Positional layouts* (TCC, Monlam). Each key maps to a Tibetan character,
     and stacks are formed by whatever stacking mechanism the layout uses. This is
     a table-driven layer next to the EWTS engine, not a variant of it.
3. **Output is Unicode in every scheme.** The legacy layouts targeted Tibetan
   Machine glyphs; our tables map to Unicode directly, and the existing
   normalization decision (0001) applies to the output of all schemes.
4. **Tables are written from observed behaviour and published charts,** not
   copied from other projects' files. In particular, do not copy the THDL
   `sambhota_keyboard.ini`: its licence is not stated beyond a 2001-2002
   THDL copyright notice. Keyman has no Sambhota or TCC keyboard to refer to.
5. **No implementation until the tables are verified** against a real copy of
   each layout (see below).

## Open questions

- **Sources for the key tables.** TCC #1/#2: TCC's own documentation. Monlam: the
  published chart or a machine with the layout installed. Sambhota: the
  Nitharta documentation or Jskad behaviour.
- **Which Monlam layout.** It ships four. The TCRC-based one is the likely
  candidate but it is not confirmed.
- **Stacking in TCC and Monlam.** One of the three methods THL lists (no stacking
  key, a stacking key, a modifier key) applies to each; which is not confirmed.
- **Typing only, or conversion too.** Whether existing text typed in these layouts
  should also be convertible, as the converter page does for EWTS.
- **Provenance of reference material.** Monlam installers circulate widely with
  malware; take any reference copy only from the official source.

## Consequences

- The toolbar plan's rule "EWTS remains the sole Tibetan mode" and the removal of
  the "EWTS ▾" control no longer hold. The control becomes a scheme selector once a
  second scheme exists. The plan documents are updated to point here.
- The "replacing native Tibetan direct keyboard layouts" non-goal is narrowed:
  we do not replace OS layouts, but we do offer these layouts where they let a
  user keep a layout they already type with.
- The Latin escape (not yet designed) must work in every scheme, and capital
  letters carry meaning in Sambhota, so the escape cannot rely on them.
- Each scheme needs its own fixtures. The existing EWTS fixtures
  (`playground/fixtures`) are a template for them.
- Sambhota can reuse the composition engine. TCC and Monlam need new code, whose
  size depends on the stacking answers above.

## Sources

- THL, Tibetan Input System Principles, collab.its.virginia.edu/wiki/tibetan-script
- THL, Legacy Tibetan Input Methods for Windows (same site)
- THL, Keyman Keyboards (same site; Chris Walker's Sambhota #1/#2 to Unicode)
- Digital Tibetan, Tibetan keyboards, digitaltibetan.github.io/DigitalTibetan
- THDL tools, `TibetanKeyboard` API, thdltools.sourceforge.net
