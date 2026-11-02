# ADR 0001 — Unicode normalization of converter output

Status: **Proposed** (evidence is incomplete; see "What is not known")
Date: 2026-11-02

## Context

Tibetan has characters that NFC/NFD rewrite: 17 composition exclusions
(U+0F43, 0F4D, 0F52, 0F57, 0F5C, 0F69, 0F73, 0F75, 0F76, 0F78, 0F81, 0FB9,
0F93, 0F9D, 0FA2, 0FA7, 0FAC) and compatibility characters (0F77, 0F79).
Combining classes differ across a stack's marks, but U+0F7E/0F7F have class 0,
so their order is never normalised. The same visible text therefore has
several byte sequences, which breaks search, diffing and round-tripping.

## Decision (proposed)

1. **Default output is NFC-stable**: T-Time emits the decomposed form of every
   excluded composite and orders combining marks canonically. Checked against
   Python `unicodedata` on 20,000 random inputs (0 differences).
2. **Keep `Options::precomposed`** as an opt-in for fonts or consumers that
   need the composites (e.g. 0F43 for gha). Its output is **not NFC** and the
   option is documented as such.
3. **Do not widen the API.** No normalization-form parameter, no
   NFD/NFKC modes. A caller needing another form normalizes the output.
4. Input is never normalized silently. Non-canonical input is reported
   (`reverse.non-canonical-input`, `ewts.non-canonical-escape`) and preserved
   by the forward direction.

## Consequences

- Searchable, comparable output by default; precomposed users must opt in.
- The reverse converter reaches `Exact` fidelity only for canonical input;
  otherwise `Canonical`.
- Mark order (0F7E/0F7F) is preserved as typed. Two writers entering "the
  same" text in a different order get different strings; accepted, because
  reordering would be silent correction.

## Alternatives considered

- *Precomposed default*: matches some legacy fonts and m17n's flag; but the
  output is not NFC, so canonical equality fails.
- *Always NFC via post-pass*: hides ordering bugs in the converter; we prefer
  to produce canonical order directly and test it independently.
- *Make normalization a caller concern only*: pushes a correctness property
  onto every IME host.

## Related open question: `oM`

`oM` at syllable start → ༀ (U+0F00) today; pyewts gives ཨོཾ. U+0F00 has no
Unicode decomposition (checked), so NFC leaves it, but scholars searching
letters will not match it. Needs a decision;
not settled here.

## What is not known

- Which composites real Tibetan fonts (Jomolhari, Noto Serif Tibetan,
  Microsoft Himalaya, Apple's Kailasa) render correctly in decomposed form.
  Not tested.
- What Unicode Consortium guidance (Tibetan block notes, UTN) says for
  stability; not consulted.
- Whether the THL spec requires a form.

Until these are checked this ADR stays Proposed.
