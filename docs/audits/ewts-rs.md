# Audit: ewts-rs

Date: 2026-11-02. Auditor: Claude, working from GitHub API metadata, crates.io
metadata, the published 0.1.4 crate source (README, tests) and behavioural
comparison. **Not done:** a line-by-line source review, running the wasm demo,
running its benchmarks, reading the other workspace crates' sources, checking
the demo page's behaviour. Statements below say which of these they rest on.

## 1. Identity and provenance

| Item | Finding | Basis |
|---|---|---|
| Repository | github.com/emgyrz/ewts-rs, default branch `master` | GitHub API |
| Audited commit | `dda3da986cbdc6b6afa3ea7405bc90c7df384a0f` (2026-10-26, "update demo build deps") | GitHub API |
| Crate audited | `ewts` 0.1.4, released 2026-10-12 (earlier 0.1.0 on 2024-11-19) | crates.io |
| Tags seen | 0.1.4, 0.1.6 (and others) — the workspace crates version separately (`ewts-wasm` 0.1.7) | GitHub API, Cargo.toml |
| Activity | created 2024-11-16; 48 commits; 2 contributors (emgyrz 47, houko 1); 0 open issues; 0 stars | GitHub API |
| Downloads | about 58,800 for the `ewts` crate at the time of checking | crates.io |
| Size | `ewts` 0.1.4 package about 12 KB | crates.io |

Maintenance reading: one active maintainer, recent commits, small and young.
Adoption signals on GitHub are minimal (0 stars) even though crates.io downloads
are not (downloads include automated and transitive fetches, so this is a weak
signal either way).

## 2. Licence and legal status

| Question | Finding |
|---|---|
| Declared licence | `MIT OR Apache-2.0`, set at workspace level in `Cargo.toml` and inherited by `ewts` and `ewts-wasm`; crates.io shows the same. |
| Licence text in the repository | **None found at the repository root.** GitHub reports no detected licence (`license: null`). Directory listings of `ewts/`, `ewts-wasm/`, `ewts-c/` show no LICENSE file. |
| Consequence | The licence is declared in metadata but no licence or copyright text is distributed. MIT and Apache-2.0 both require notices to be carried along. This is a **gap to resolve with the author** before vendoring or redistributing source. Depending on the crate through crates.io leaves T-Time's own code unaffected, but a release bundling the crate should still carry attribution. |
| Upstream of the dictionary | The README says the dictionary "was taken from" `rogerespel/ewts-js`. That repository shows **no licence** on GitHub (`license: null`, no LICENSE file). A related converter, `buda-base/jsewts`, is Apache-2.0. |
| Consequence | The licence status of the data inside `ewts` rests on a source with no visible licence. That is a provenance risk for any adoption beyond comparison. |
| Test data | `rules_test.rs` transcribes THL rule examples. THL's own terms for its examples were not checked. T-Time uses the 16 inputs and expected strings as `thl_rules.tsv` with attribution in NOTICE; it should be revisited if THL terms are found to restrict that. |
| Transitive dependencies | `ewts` has none (`[dependencies]` is empty). `ewts-wasm` depends on `wasm-bindgen`. Not audited further. |

Conclusion: usable as a **differential oracle** (we run it, we do not copy it).
Not safe to **vendor or fork** until the author adds licence files and the
dictionary's origin is clarified.

## 3. Architecture and capabilities

Workspace members seen: `ewts` (library), `ewts-wasm`, `ewts-c`, `ewts-cli`,
`bench`, `demo`. CI: `cargo build` and `cargo test` on ubuntu-latest only; a
second workflow updates GitHub Pages. No fuzzing, no multi-platform CI seen.

| Capability | Finding | Basis |
|---|---|---|
| Forward EWTS → Unicode | Yes. `EwtsConverter::create().ewts_to_unicode(&str)`. | README, run |
| Reverse conversion | **No** (not mentioned; no API seen). | README |
| Incremental composition | **No.** Whole-string only. A web page converting text is not an IME. | README, API |
| Diagnostics | **No.** README: "does not perform any checks, substitutions, transformations". | README |
| Unicode policy | None stated. Our comparison shows typed (not canonical) mark order, e.g. `bru+e` gives 0F74 0F7A. | behaviour |
| Browser build | `ewts-wasm` (wasm-bindgen), published to npm as `ewts`; demo page on GitHub Pages. Not run by me. | README, listing |
| C interface | `ewts-c` with C, C++ and Cython headers. Not built or run by me. | listing |
| Testing | 16 THL-rule cases in `rules_test.rs`. No fixtures corpus, fuzzing or reference differential in the repo. | source |
| Performance claim | README claims about 26,491 KB/s and 12–14× over JS converters. **Not reproduced.** Different workload from our benchmark, so not comparable. | README |
| Compliance claim | README: "Fully compliant with the standard." **Not accepted as established**: it rests on 16 examples, and the THL text was not available to us. | README |

## 4. Differential results

Harness: `scripts/differential/ewts-rs-diff` (pinned `=0.1.4`), plus
`scripts/differential/review_report.py` for the combined table
(`docs/review/disagreements.md`). Run on 2026-11-02 over 687 fixture inputs
(precomposed.tsv excluded).

Differences from ewts-rs alone (98 of 687):

| File | Inputs | Differ | Notes |
|---|---|---|---|
| words, stacks | 91, 92 | 0, 0 | |
| corpus | 200 | 1 | `sa+rba` |
| syllables | 32 | 1 | `bod/ bod` (tsheg after a shad) |
| thl_rules | 16 | 1 | rule 5 vowel order, NFC-equal |
| alphabet | 27 | 3 | `uo ui ue` (m17n extension in T-Time) |
| punctuation | 30 | 11 | half numbers, `\U`, `\x` |
| sanskrit | 38 | 9 | `oM` (2), `X`, `~X`, `k+fa`, `k+va`, `k+Za`, mark order |
| deviations | 10 | 7 | pinned open items |
| robustness | 151 | 65 | it never diagnoses; many drop dangling `+` and `.` |

The three-way table (T-Time, pyewts, ewts-rs) in `docs/review/disagreements.md`
lists 133 inputs on which not all three agree, including cases where only
pyewts differs.

Classification by the plan's categories, for the non-robustness differences:

| Class | Cases |
|---|---|
| T-Time defect (fixed during this work) | `bru+e` vowel stacking (rule 5); suffix-versus-stack after a vowel |
| Convention difference | `uo ui ue`, half numbers, `oM`, `X`, space after a shad (`bod/ bod`) |
| Normalization-only | `fe`, `le?`, `kA?`, `bru+e` mark order |
| Ambiguous / unresolved | `sa+rba`, `k+fa`, `k+Za`, `Wa` / `Ya`, repeated vowels (`kii`), `kaa` |
| Upstream defect | none established; no case where we could show ewts-rs wrong without the THL text |

Nothing was called correct because a majority agreed. ewts-rs and pyewts share
ancestry (a dictionary lineage from the THL converters), so their agreement is
weaker evidence than two independent implementations.

## 5. Decision

See `docs/decisions/0002-ewts-rs-integration.md`. Summary: **independent
reference only**.

## 6. Open verification tasks

1. Ask the author to add LICENSE files and to state the dictionary's origin.
2. Read the `ewts` source for the lookup and tokenization logic.
3. Run the wasm demo and compare its output to the crate's.
4. Re-run the comparison on new upstream releases (`=0.1.4` is pinned).
5. Reproduce their benchmark and compare on equal workloads, if performance
   becomes a decision factor.
