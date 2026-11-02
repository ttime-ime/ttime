# T-Time EWTS specification

Status: draft 1. This document describes what `ttime-core` converts and why.
Every rule carries one of three labels:

- **[Normative]** — required by the EWTS scheme as published by THL (Extended
  Wylie Transliteration Scheme, Germano/Hackett/Wylie lineage).
- **[Implemented]** — what T-Time does today; where it is not also Normative it
  is a documented choice, not a claim about EWTS.
- **[Deviation]** — T-Time knowingly differs from a reference. Each is listed
  in section 12 with a classification.

## 0. Sources and their limits

| Source | Version / date | Licence | Used for |
|---|---|---|---|
| THL EWTS specification | **not retrieved** | THL terms | Intended normative base. The THL URLs I tried returned 404, so **no rule below was checked against the THL text**. Normative labels reflect common knowledge of EWTS and agreement of the references, not a verified reading. |
| m17n-db `bo-ewts.mim` | git.savannah.gnu.org, as fetched in this project | LGPL 2.1+ | Behavioural reference only. No table or text copied. |
| Keyman `tibetan_ewts` v2.4 | keymanapp/keyboards `release/t/tibetan_ewts`, commit 8072bb2 (2024-05-17) | MIT | Behavioural reference, run through a small interpreter of the `.kmn` rules (`scripts/differential/keyman_diff.py`). The interpreter is incomplete; see 12.4. |
| ewts-rs / crate `ewts` 0.1.4 | crates.io, `emgyrz/ewts-rs` | MIT OR Apache-2.0 | Third differential oracle, and its `rules_test.rs` transcribes THL rules 1–16 with examples; used as `thl_rules.tsv`. Its dictionary comes from rogerespel/ewts-js, a descendant of the THL converter family, so it is **not independent of pyewts**. The THL page itself is still unchecked. |
| pyewts 1.0.0 | PyPI | Apache-2.0 | Differential oracle (`scripts/differential/`). Its stack inventory contributed to `STANDARD_STACKS` (see NOTICE). |

Unverifiable here: behaviour of Keyman on real devices, the original THL text,
and any rule only the THL text settles. Those are marked *unverified*.

## 1. Scope

EWTS text in, Tibetan Unicode (block U+0F00–U+0FFF) out. One engine serves
Classical and Modern Tibetan; there are no profiles. No phonetic input.
Conversion is total: every input produces output and never fails
(section 8).

## 2. Characters

### 2.1 Consonants [Normative unless noted]

| Key | Code point | Key | Code point | Key | Code point |
|---|---|---|---|---|---|
| k | 0F40 | kh | 0F41 | g | 0F42 |
| ng | 0F44 | c | 0F45 | ch | 0F46 |
| j | 0F47 | ny | 0F49 | t | 0F4F |
| th | 0F50 | d | 0F51 | n | 0F53 |
| p | 0F54 | ph | 0F55 | b | 0F56 |
| m | 0F58 | ts | 0F59 | tsh | 0F5A |
| dz | 0F5B | w | 0F5D | zh | 0F5E |
| z | 0F5F | ' | 0F60 | y | 0F61 |
| r | 0F62 | l | 0F63 | sh | 0F64 |
| s | 0F66 | h | 0F67 | a (chen) | 0F68 |

Sanskrit letters: T 0F4A, Th 0F4B, D 0F4C, N 0F4E, Sh 0F65, R 0F6A (fixed-form ra).

Aspirated-voiced, written as base + subjoined ha (0FB7): gh = 0F42 0FB7,
dh = 0F51 0FB7, bh = 0F56 0FB7, Dh = 0F4C 0FB7, dzh = 0F5B 0FB7.
`f` = 0F55 0F39 and `v` = 0F56 0F39 (pa/ba plus tsa-phru).

Greedy longest match: `tsh` before `ts`, `dzh` before `dz`, `kh` before `k`.

### 2.2 Vowels

| Key | Output | Note |
|---|---|---|
| a | (none) | inherent vowel; after a consonant it also separates stacks |
| i u e o | 0F72 0F74 0F7A 0F7C | |
| ai au | 0F7B 0F7D | |
| A | 0F71 | |
| I U | 0F71 0F72, 0F71 0F74 | |
| -i -I | 0F80, 0F71 0F80 | reversed vowels |
| uo ui ue | 0F7C 0F74, 0F72 0F74, 0F7A 0F74 | **[Deviation]** m17n extension, not EWTS |

A vowel with no consonant uses a-chen (0F68) as its base.
`ai` and `au` are single signs; they are never `a` + `i`.

### 2.3 Marks

| Key | Code point | Name |
|---|---|---|
| M | 0F7E | anusvara (rjes su nga ro) |
| H | 0F7F | visarga |
| ~M | 0F83 | candrabindu |
| ~M` | 0F82 | nada |
| X | 0F37 | sna ldan (see 12.3) |
| ~X | 0F35 | |
| ^ | 0F39 | tsa-phru |
| ? | 0F84 | halanta |
| & | 0F85 | |
| oM at syllable start | 0F00 | OM ligature (12.2) |

### 2.4 Tsheg, spaces

A space between syllables is a tsheg (0F0B). `_` is a real space (U+0020).
After a shad (0F0D, 0F0E) a space stays a real space. **[Implemented]**:
consecutive spaces each yield a tsheg; behaviour for a space beside `_` is
unspecified in the references and *unverified*.

### 2.5 Punctuation and digits

`/` 0F0D, `//` 0F0E, `*` 0F0C, `;` 0F0F, `|` 0F11, `!` 0F08, `:` 0F14, `=` 0F34,
`@` 0F04, `#` 0F05, `$` 0F06, `%` 0F07, `<` 0F3A, `>` 0F3B, `(` 0F3C, `)` 0F3D.
Digits 0–9 → 0F20–0F29. Half numbers `-1`…`-9`, `-0` → 0F2A–0F33
(m17n and T-Time; pyewts does not define them).

## 3. Stacks

A *stack* is a root consonant with a superscript and/or subscripts, written
in Unicode as a base letter followed by subjoined letters (base + 0x50 for the
regular block; 0FBA, 0FBB, 0FBC for fixed-form wa, ya, ra).

### 3.1 How subjoining is decided

1. `+` forces the neighbouring consonants into one stack. **[Normative]**
   `k+ta` is ཀྟ regardless of any table.
2. Without `+`, consecutive consonants stack only when the sequence is in the
   *standard stack inventory* (`STANDARD_STACKS`, 96 entries, e.g. `rg`, `sk`,
   `ky`, `kr`, `gl`, `rgy`, `skr`, `drw`). **[Implemented]**
3. Otherwise each consonant stands alone. `.` forces a break: `g.ya` is
   ga + ya, not gya (ཉ་). **[Normative]**
4. Prefix ambiguity: `gya`, `bra`, `dwa`… are read as stacks. The prefix
   reading needs `.`. T-Time emits Info `ewts.ambiguous-prefix-stack`
   when a prefix + y/r/l/w could have meant the other. **[Implemented]**
5. Explicit `a` before `+` (`pad+ma`) is accepted: the `a` is the inherent
   vowel and the `+` merges the next consonant.

Inventory provenance: the intersection and union of m17n's and pyewts'
published lists, verified equal to m17n's behaviour on all 113 stacks it
defines (`scripts/differential`). **Not** from the THL text.

### 3.2 Open discrepancy: permissive subjoining

pyewts subjoins any y/r/l/w after any consonant; T-Time and m17n only
inventory stacks. Examples: `ghri`, `dhru` (gh/dh + r). Keyman also stacks
them, so two of three references agree against T-Time. The project rule is not
to follow majorities; the question is *which is right for scholars* and is
**open** (needs the THL text). Until then T-Time keeps the conservative
reading and users get the stack with `gh+ri`.

## 4. Extended EWTS and escapes

- `[text]` — literal pass-through, no conversion; an unclosed `[` emits the
  rest literally and the Warning `ewts.unterminated-literal`.
- `\uXXXX`, `\UXXXXXXXX` — a code point; invalid or short sequences stay
  literal with `ewts.invalid-escape` / `ewts.incomplete-escape`.
  A precomposed Tibetan code point that NFC would rewrite gets Info
  `ewts.non-canonical-escape`; the text is **not** altered.
- `\x` for any other `x` — x literally.
- Any Tibetan character in the input passes through unchanged.
- `~` not starting `~M`/`~X` is literal (`ewts.stray-tilde`).
- Other ASCII letters (`q`, …) are literal (`ewts.unsupported-character`).

## 5. Incremental composition

`composition::Engine` stores raw EWTS typed so far and **re-converts the whole
buffer** on every `preedit()`. This is deliberate: correctness over cleverness.
There is no cursor, no mid-buffer edit, and `backspace` removes the last raw
character. Cost is linear in buffer length per keystroke (section 11).
Syllables not yet complete convert as written (`ba` → བ, never held back), so
the preedit can change earlier output as later letters arrive (`g` → ག, then
`gya` → གྱ). Hosts should treat the preedit as replaceable.

## 6. Unicode normalization

Output is **NFC-stable by construction** (default). Within a stack, combining
marks are placed in canonical-combining-class order (0F71 ccc129 < 0F72,
0F7A–0F7D, 0F80 ccc130 < 0F74 ccc132); 0F7E/0F7F have ccc 0 and are **never**
reordered, so mark order is significant. Because of composition exclusions,
characters such as 0F43, 0F4D, 0F52, 0F57, 0F5C, 0F69, 0F73, 0F75, 0F76, 0F78,
0F81, 0FB9 do not appear in default output; we emit their decomposed forms
(e.g. 0F42 0FB7, not 0F43).

`Options::precomposed` emits those compatibility composites instead. **Output
in that mode is not NFC.** Its status and the open question of which default is
right are in `docs/decisions/0001-unicode-normalization.md`.
Verified: 20,000 random inputs agree with Python `unicodedata` NFC.

## 7. Diagnostics

Structured, advisory, never fatal; output text is identical with or without
them. Spans are half-open UTF-8 byte ranges into the input.
Categories: Invalid, Incomplete, Unsupported, Ambiguous, Unicode.
Codes (stable strings): `ewts.stray-plus`, `ewts.dangling-plus`,
`ewts.mark-without-base`, `ewts.duplicate-mark`, `ewts.unsupported-character`,
`ewts.stray-tilde`, `ewts.incomplete-tilde`, `ewts.unterminated-literal`,
`ewts.incomplete-escape`, `ewts.invalid-escape`, `ewts.non-canonical-escape`,
`ewts.ambiguous-prefix-stack`; reverse: `reverse.unsupported-code-point`,
`reverse.ambiguous-root`, `reverse.non-canonical-input`.

## 8. Error handling classes

| Class | Example | Behaviour |
|---|---|---|
| Invalid | `k++a`, `Ma` | `+` kept literally (`ཀ++ཨ`); a baseless mark is emitted alone (`ཾ`); Warning |
| Incomplete | `ka+`, `ka~`, `[abc`, `\u0F` | emit what is typeable; Warning (an IME may stay silent while typing) |
| Unsupported | `q` | literal; Warning |
| Ambiguous | `gya` | chosen reading; Info |
| Unicode | `གྷ` | unchanged; Info |

Scholarly input is never silently corrected: unusual sequences are kept and
reported, not rewritten.

## 9. Reverse conversion (Unicode → EWTS)

`unicode_to_ewts` returns text plus the fidelity achieved:

- **Exact** — `forward(reverse(u)) == u`. Holds for all fixtures and for
  30,000 random forward outputs.
- **Canonical** — equal after canonical normalization (input used composites or
  non-canonical order).
- **Semantic** — reserved; not implemented.
- **Lossy** — a code point has no EWTS spelling; written as `\uXXXX` so no
  text is lost, with `reverse.unsupported-code-point`.

Root choice in a stack follows the prefix/suffix structure; when no vowel sign
marks the root it is assumed (`reverse.ambiguous-root`). `.` is inserted
where re-reading would otherwise stack differently, and `oM` after a syllable
is written `.oM`.

## 10. Test status

701 curated fixture lines (11 files; target of 500 met), 17 diagnostic tests,
14 reverse tests, 15 property tests, 14 unit tests. Three of the files differ in
authority: `corpus.tsv` (195, agreed by pyewts), `thl_rules.tsv` (16, THL rules as transcribed by ewts-rs), `robustness.tsv` (151 invalid,
incomplete and degenerate inputs; characterization only) and `deviations.tsv`
(10 pinned disagreements; not claims of correctness).
Fuzzing: six `cargo-fuzz` targets in `crates/ttime-core/fuzz` (EWTS→Unicode,
Unicode→EWTS, malformed input, long stacks, combining sequences, incremental
insert/delete), each capping input size (4096 bytes, or fewer). One 60-second
run each on 2026-11-02 (nightly rustc 1.101, cargo-fuzz 0.13.2): about 2.3
million executions in total, **no crashes or assertion failures**. That is a
smoke run, not sustained fuzzing; no long campaign has been done. Checked
properties: no panic, diagnostic spans in range and on char boundaries,
diagnostics do not change text, `Exact` reverse results re-convert to the
input, and `Engine` always equals whole-buffer conversion.

## 11. Performance

Rough wall-clock numbers, release build, one Apple-silicon Mac, no statistics
(`cargo run --release -p ttime-core --example bench`):

| Operation | Time |
|---|---|
| EWTS→Unicode, 1 syllable | ~1.8 µs |
| EWTS→Unicode, 75-char line | ~15 µs |
| EWTS→Unicode, 2,300-char page | ~0.43 ms |
| Unicode→EWTS, same page | ~1.0 ms |
| Keystroke (preedit), 20 / 200 / 2000-char buffer | ~5 / ~38 / ~366 µs |

Cost per keystroke is linear in buffer length, as designed. Allocations were
not measured. No optimization has been attempted; ordinary composition buffers
(one syllable to a line) are far below any perceptible latency.

## 12. Differences from references

> **Expert review:** every open item is collected, with what each implementation does and a question, in `docs/review/expert-review.md`; the generated per-input table is `docs/review/disagreements.md`.

### 12.1 vs m17n

(A bare `-` was once swallowed by T-Time; found by pyewts, fixed, now literal.)

| Item | m17n | T-Time | Class |
|---|---|---|---|
| `\U` 8-digit escape | yes | yes | agree |
| `uo ui ue` | yes | yes | shared extension, non-EWTS |
| half numbers | yes | yes | agree |

### 12.2 `oM`

T-Time: ༀ (0F00) at syllable start. pyewts: ཨོཾ. **Open**: scholars may want
the letters; see ADR 0001.

### 12.3 `X` / `~X`

T-Time and m17n: 0F37 / 0F35. pyewts: 0FBE. **Open.**

### 12.4 vs Keyman (interpreter run, 20,000 generated well-formed syllables)

14,394 identical; 5,606 differ:

- **5,482** — Keyman leaves a prefix letter (b d g m ') as ASCII or drops it
  (e.g. `gdze` → d dz e; pyewts agrees with T-Time). Cause is either a Keyman
  rule gap or my interpreter; **not determined**. Not counted as T-Time bugs.
- **124** — both Tibetan but different: `drw*` Keyman emits full ra + subjoined wa
  (malformed stack; T-Time = m17n = pyewts) → Keyman defect; `ghr*`/`dhr*`
  Keyman and pyewts stack, T-Time/m17n do not → open (3.2).
- `pad+ma`: Keyman has no rule for explicit `a` before `+`.

All 91 word fixtures: 90 identical.

### 12.5 vs pyewts

`scripts/differential/pyewts_diff.py` (pyewts pinned in `requirements.txt`)
over all fixtures except `precomposed.tsv` (671 cases; 2026-11-02):

| File | Differences | Cause |
|---|---|---|
| corpus.tsv | 0 | — |
| words, stacks, syllables | 0 | — |
| alphabet.tsv | 3 | `uo ui ue` (m17n extension; 12.2 of vowels) |
| punctuation.tsv | 12 | half numbers `-0…-9` (10), `\U` escape, `\x` |
| sanskrit.tsv | 11 | `oM` (2), `X`/`~X` (2), `k+fa`, `k+va`, `k+Za`, `kuo`; plus `fe`, `le?`, `kA?` which differ only in mark order and are NFC-equal |
| deviations.tsv | 10 | pinned open items (12.6) |
| robustness.tsv | 78 | malformed input; pyewts warns, drops or raises (it raised `IndexError` on some), so no meaningful oracle |

Beyond fixtures, 30,000 random well-formed syllables were compared during
development; the only remaining class is pyewts' permissive subjoining
(3.2). The random runs are not committed.

### 12.5a vs ewts-rs 0.1.4

`scripts/differential/ewts-rs-diff` (version pinned) over the same fixtures
(687 cases): 98 differ, nearly all in `robustness.tsv` (65; ewts-rs does no
checking and never diagnoses). The rest match the pyewts classes (`uo/ui/ue`,
half numbers, `\U`, `oM`, `X`, `k+fa/va/Za`, mark order). Differences specific
to it: `bod/ bod` (it emits a tsheg after a shad, T-Time a real space),
`sa+rba`, and rule 5's vowel order (NFC-equal).

**Evidence on `oM` (12.2):** both pyewts and ewts-rs give ཨོཾ, and ewts-rs's
rules suite has no ༀ case. That makes ཨོཾ the common reading among the three
other implementations, but T-Time does not follow majorities; the choice stays
open pending the THL text (ADR 0001).

**THL rules 1–16 as transcribed by ewts-rs:** all 16 reproduced (15 exactly,
rule 5 after canonical ordering). Rule 5, a plus between vowel signs
(`bru+e`), was **missing** from T-Time and is now implemented. These cases are
a third party's transcription, not the THL text.

### 12.6 Found while expanding fixtures (open ones pinned in `deviations.tsv`)

- **Suffix versus stack — fixed.** A consonant run after a vowel with no
  tsheg now takes the longest standard stack ending at the next vowel as its
  root (`masti` = ma + sti, `sarba` = sa + rba), as pyewts, Keyman and m17n do.
  `ngo'i`, `mangga` are unchanged. Moved from `deviations.tsv` to `corpus.tsv`.
- **`pra+dznyA`**: with `+` after an explicit vowel, T-Time joins only the last
  consonant (full ra, then subjoined dz); pyewts stacks p+r+dz. Open.
- **`kri+shna`**: `+` after a vowel is stray in T-Time (literal `+`, Warning);
  pyewts subjoins sha after the vowel, producing text that is not a valid
  stack. T-Time's behaviour is intentional.
- **`k~Ma`**: pyewts adds a-chen after a mark followed by `a`; T-Time drops
  the `a`. Open.
- **`kaa`, `aa`**: the second `a` is dropped silently (while `kii` keeps both
  vowels). Conflicts with the no-silent-correction principle. Open.
- `oM`, `X`: see 12.2, 12.3. `bhrUM`: see 3.2.

### 12.7 Other

`k+fa`, `Z`, multiple spaces, space next to `_`: unverified against references.
