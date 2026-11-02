# 0003: Diplomatic mode

**Status:** Accepted, 2 November 2026. Implemented in `ttime-core` and the web
prototype. Not yet in the macOS input method.

## Context

A diplomatic transcription reproduces a source as written. T-Time already never
rewrites text it has converted: diagnostics are advisory and the output is the
same with or without them (specification, section 7). What is not covered is
the places where the converter *chooses*: it picks one reading where other
converters pick another, or ignores a letter without saying so. A scholar
checking a transcription cannot see those choices.

## Decision

`Options::diplomatic` (default off) changes **only what is reported**:

- The converted text is identical in both modes. A test checks this on 20,000
  random inputs in both Unicode forms.
- Four new diagnostics exist only in this mode, each a Warning:
  `ewts.dropped-input` (an `a` that adds nothing, as in `kaa`, `k~Ma`),
  `ewts.om-syllable` (`oM` as the single character U+0F00),
  `ewts.x-sign` (`X`, `~X` as U+0F37, U+0F35) and
  `ewts.unstacked-subjoin` (`ghr`, `dhr`, ... not stacked, section 3.2).
- `ewts.ambiguous-prefix-stack` (`gya`) is raised from Info to Warning.
- Input that is plain and unambiguous reports nothing.
- The mode never blocks or delays typing and never edits committed text.

Diagnostics are not produced in normal mode, so existing behaviour and tests
are unchanged.

## Not decided

Two stricter readings were offered and not chosen: refusing to convert a
stretch where the converter would guess or drop input, and keeping exact code
points regardless of Unicode normalization. Either would change the output and
interrupt typing; revisit only if specialists ask for it.

The list of reported choices is the set documented as open in specification
section 12 (12.2, 12.3, 12.6, 3.2). `kii` (both vowels kept) is not reported
because nothing is lost. When an open question is resolved, drop the matching
code.

## Consequences

- The mode is only as complete as that list. A choice not yet documented as open
  is not reported.
- The web prototype shows a checkbox, a warning count and the diagnostics for
  all typed text. The macOS input method has no diagnostics surface yet and
  does not offer the mode; the C interface is unchanged.
