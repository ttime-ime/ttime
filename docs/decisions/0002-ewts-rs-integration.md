# ADR 0002 — ewts-rs: dependency, fork, reference, or inspiration

Status: **Proposed** (the recommendation rests on the audit in
`docs/audits/ewts-rs.md`, which has stated gaps)
Date: 2026-11-02

## Context

ewts-rs is a small Rust EWTS→Unicode converter (crate `ewts` 0.1.4, MIT OR
Apache-2.0 declared in Cargo metadata), with wasm and C wrappers. T-Time has its
own converter with diagnostics, reverse conversion, an incremental composition
engine and an NFC-stable output policy. The question is whether to adopt ewts-rs
in place of, or inside, `ttime-core`.

## Evidence

- ewts-rs is forward-only and does no checking, by its own README. It has no
  reverse conversion, diagnostics, composition engine or Unicode policy.
- Over 687 shared fixture inputs it differs from T-Time on 98, 65 of them in
  deliberately malformed input where it silently drops or passes through. No
  case was found where it is demonstrably right and T-Time wrong *without
  the THL text*; its one confirmed contribution was exposing a missing T-Time
  feature (a plus between vowel signs, THL rule 5), now implemented.
- Licensing is incomplete: licence declared in metadata, **no LICENSE file in
  the repository**, and its dictionary comes from `rogerespel/ewts-js`, which
  also shows no licence.
- Its README claim of full compliance rests on 16 examples; its dictionary
  lineage overlaps pyewts, so agreement between them is weak evidence.
- Not examined: its source line by line, its wasm demo, its benchmark.

## Options

| Option | For | Against |
|---|---|---|
| Adopt as dependency | Less converter maintenance | Loses diagnostics, reverse conversion, composition and NFC policy that T-Time already has and tests; licence and provenance unresolved; would force rebuilding on top of it |
| Vendor / fork | Control | Unresolved licence and dictionary provenance; ongoing divergence |
| **Independent reference only** | Keeps existing work; a free third oracle; already integrated as `scripts/differential/ewts-rs-diff` | Two codebases to read when comparing |
| Architectural inspiration | None needed beyond ideas | Little benefit beyond the above |

## Decision (proposed)

**Use ewts-rs only as an independent differential reference.**
Pin `ewts =0.1.4`, keep it out of the production build and out of
`ttime-core`'s dependencies, and re-run the comparison on new releases.

## Consequences

- No change to `ttime-core`'s public interface or dependencies.
- The web prototype builds its own thin wasm bridge to `ttime-core`; it does
  not use `ewts-wasm`.
- T-Time's use of ewts-rs's 16 THL-rule examples (`thl_rules.tsv`) carries
  attribution in NOTICE; this is test data, not shipped code.

## Revisit when

- the author adds licence files and documents the dictionary's origin, **and**
- a reproduced benchmark or a defect in T-Time's conversion speed or size makes
  reuse worth the loss of diagnostics and composition (neither is currently
  true: T-Time converts a 2,300-character page in about 0.43 ms), **or**
- the THL text shows ewts-rs and T-Time diverge in a way that is better fixed by
  adopting its table.

## Not verified

THL's own terms for the rule examples; the licence of the ewts-js dictionary;
ewts-rs source quality; the demo page. See the audit's §6.
