# Items for expert review

Audience: a Tibetologist or EWTS specialist with access to the THL EWTS page.
Status: nothing below has been checked against the THL text, which was
unreachable (404, then server trouble). Full per-input data:
[disagreements.md](disagreements.md) (generated). Rules and tables:
[../specification/ewts.md](../specification/ewts.md).

## How to read this

- **Our tests currently all pass.** That means T-Time matches its own fixtures,
  not that it is right. Fixtures in `deviations.tsv` and `robustness.tsv` pin
  T-Time's behaviour where it disagrees with another implementation or where
  no reference defines the answer.
- The other implementations are pyewts 1.0.0 (Apache-2.0), ewts-rs 0.1.4
  (MIT/Apache-2.0), Keyman `tibetan_ewts` v2.4 (MIT, run through an
  interpreter I wrote, which is incomplete), and m17n `bo-ewts` (LGPL, compared
  on its stack inventory only). pyewts and ewts-rs share ancestry, so their
  agreement is weaker evidence than it looks.
- For each item: what T-Time does, what others do, the question, and what T-Time
  does until answered. **Please answer from the THL text or from scholarly
  practice, not by counting implementations.**

## A. Decisions that change output (highest priority)

| # | Input | T-Time | Others | Question |
|---|---|---|---|---|
| A1 | `oM` at syllable start | ༀ U+0F00 | pyewts, ewts-rs: ཨོཾ (0F68 0F7C 0F7E). Keyman: not checked. | What does THL specify? Should the default be the single character or the letters? (ADR 0001) |
| A2 | `X`, `~X` | U+0F37, U+0F35 | pyewts: U+0FBE (and a literal `~` for `~X`) | Which code points are intended? |
| A3 | `ghr…`, `dhr…`, `bhr…` (`ghri`, `dhru`, `bhrUM`) | gh + separate ra | pyewts, Keyman, ewts-rs: gh + subjoined ra. m17n: separate | Are these implicit standard stacks, or do they need `+`? |
| A4 | Repeated vowel in one syllable (`kii`, `kuu`, `ii`, `kAA`) | vowel signs stacked on one letter, nothing inserted | pyewts, ewts-rs: a-chen (0F68) inserted between | THL rule 11 says a-chen inside a syllable is `.a`. Is `kii` = ཀི+ཨི, or invalid? We may be wrongly merging. |
| A5 | `kaa`, `aa` | second `a` silently dropped | pyewts, ewts-rs: a-chen appended (0F68) | Same family as A4. Silently dropping input breaks the "never silently correct" rule. |
| A6 | `k~Ma` | `a` after `~M` dropped | pyewts: adds a-chen after the mark | Is `~Ma` meaningful, or malformed? |
| A7 | `pra+dznyA` | p, full ra, subjoined dz | pyewts, ewts-rs: p + subjoined ra + subjoined dz | After an explicit `a`, does `+` extend a whole standard stack (`pr`)? |
| A8 | `sa+rba` | s + subjoined r, then b | pyewts agrees (…0F56); ewts-rs: s, subjoined r, subjoined ba (0FA6) | Which reading of `+` after `a`? |
| A9 | `uo`, `ui`, `ue` | 0F7C 0F74, 0F72 0F74, 0F7A 0F74 | pyewts, ewts-rs: `u` then a-chen + vowel | These are m17n extensions, not (we believe) EWTS. Keep as extensions, or remove? |

## B. Punctuation, numbers, spacing

| # | Input | T-Time | Others | Question |
|---|---|---|---|---|
| B1 | `-1`…`-9`, `-0` | half numbers U+0F2A–0F33 | pyewts, ewts-rs: literal `-` then the full digit (`-1` = 002D 0F21) | Are half numbers in EWTS? (m17n has them.) |
| B2 | `\U00000F40` | ཀ | pyewts, ewts-rs: empty output | THL rule 8 defines `\U`; confirm behaviour. |
| B3 | `\x` | `x` | pyewts and ewts-rs: `\` followed by Tibetan letters (they read `x` as an EWTS-level token; the output is not a clean pass-through) | What does a backslash before an ordinary letter do? (THL rule 10 shows `\3`.) |
| B4 | `bod/ bod` | space after a shad stays U+0020 | ewts-rs: tsheg after the shad | Correct typography after a shad? |
| B5 | space beside `_`; multiple spaces | each space is a tsheg; `_` is U+0020 | untested against references | Is repetition meaningful? |

## C. Sanskrit-oriented letters

| # | Input | T-Time | Others | Question |
|---|---|---|---|---|
| C1 | `k+fa`, `k+va` | k + subjoined pa/ba + U+0F39 | pyewts: non-subjoined pa/ba + U+0F39; ewts-rs: drops the `+fa` | How do f and v combine in stacks? |
| C2 | `k+Za` | k + U+0F39 | pyewts: k + U+0FAF; ewts-rs: k, literal `Z`, a-chen | Meaning of `Z`? |
| C3 | `Wa`, `Ya`, `kW`, `kY` (no `+`) | literal `W`/`Y` plus warning | pyewts, ewts-rs: ཝ / ཡ | Are W and Y valid outside stacks? THL rule 15 limits them to non-top stack positions. |
| C4 | `kri+shna` | `+` after a vowel is stray; literal `+` plus warning | pyewts, ewts-rs: sha subjoined after the vowel | Is a stack after a vowel valid? (Likely yes for Sanskrit; T-Time may be too strict.) |

## D. Mark and vowel order

Output differs only in the order of combining marks; the results are NFC-equal
(`fe`, `le?`, `kA?`, `bru+e`). T-Time emits canonical order (Unicode combining
class order) so output is NFC-stable; pyewts/ewts-rs emit the typed order. Is
typed order ever meaningful to a reader or font? Marks with combining class 0
(U+0F7E, U+0F7F) are not reordered by Unicode; how should `kMH` versus `kHM`
be treated? (ADR 0001.)

## E. Robustness (no reference defines these)

`robustness.tsv` has 151 malformed or odd inputs. For 92 of them at least one
oracle differs. Notable classes:

- **Dangling `+` and `.`** (`k+`, `ka.`, `ts+`): T-Time keeps the character and
  warns; oracles drop it silently. Do you want the character kept?
- **Mismatched case** (`Q`, `x`, `J`): kept literally with a warning; oracles
  vary.
- **Stray escapes, unterminated brackets**: kept, warned.

Expert question: for typing, should T-Time pass unknown characters through
(current) or ignore them?

## F. Evidence gaps (things I could not check)

- The THL page (rules, tables, standard-stack list). The stack list in
  `STANDARD_STACKS` is the union of m17n's and pyewts' lists, not THL's.
- THL rules 1–16 as transcribed by ewts-rs: T-Time reproduces all 16 (rule 5
  after canonical ordering), but that is a third party's transcription.
- Keyman and m17n behaviour on real systems. Keyman was run through my own
  rule interpreter; 5,482 of 20,000 generated syllables differed because it
  leaves prefix letters unconverted, and I could not tell whether that is
  Keyman or my interpreter.
- Font rendering of decomposed versus precomposed forms (ADR 0001).
- Anything about Classical versus Modern conventions: no profile exists.

## G. Known T-Time behaviours I would not defend without review

1. The standard-stack inventory (96 entries) is not from THL.
2. Ambiguous prefix + y/r/l/w reads as a stack (`gya`); prefix needs `.`.
   Reported as Info, never an error.
3. After a vowel, a consonant run takes the longest standard stack as the
   next root (`masti` = ma + sti). Matches every reference tried and THL rule 7
   as transcribed, but changes where a "syllable" ends.
4. Escapes of precomposed characters (`གྷ`) are kept as typed.
5. Reverse conversion guesses the root letter when no vowel marks it
   (`reverse.ambiguous-root`).
