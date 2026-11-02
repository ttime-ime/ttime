# T-Time — Tibetan EWTS IME — Project Plan

**Status:** Foundation under consolidation (core converter implemented; no OS adapter yet)  
**Date:** 2026-11-02  
**Implementation:** Rust core (`ttime-core`, `ttime-cli`); native platform adapters later  
**Scope:** Windows, macOS, Linux; offline-first; Unicode Tibetan

## 1. Executive summary

Build a reliable, cross-platform Tibetan input method centered on strict Extended Wylie Transliteration System (EWTS) conversion, with optional orthographic assistance and dictionary-backed completion. The product should serve Tibetologists, students, and native Tibetan users who prefer transliteration without attempting to replace established direct-layout keyboards.

Three independent layers:

1. **Deterministic conversion:** EWTS ↔ Unicode Tibetan, with interactive composition.
2. **Orthographic intelligence:** syntax and syllable validation, explanations, and non-destructive correction suggestions.
3. **Lexical assistance:** optional dictionary completions, user vocabulary, corpus-derived ranking, and eventually contextual prediction.

**Non-negotiable principle:** no automatic changes to scholarly input. Users must be able to enter unattested, erroneous, historical, and Sanskrit forms exactly as written.

## 1a. Identity, current state and policies

**Identity.** T-Time is an independent product. It shares no code with and has no dependency on any other project. Mascots: Momo (yak) and Tibby (cat-maid).

**One engine.** There are no separate engines for Classical and Modern Tibetan. *Profiles* (Classical/Modern) may later differ only in orthography hints and frequency data (layers 2–3), never in EWTS conversion.

**Phonetic input** is deferred. Nothing is built; the future candidate interface (layer 3) must be able to carry non-EWTS sources, but no phonetic code or data exists.

**Normalization.** Default output is NFC-stable; an opt-in precomposed mode exists and is not NFC. Status: Proposed — see `docs/decisions/0001-unicode-normalization.md`.

**Specification.** `docs/specification/ewts.md` is the behavioural reference and labels each rule Normative / Implemented / Deviation. The THL text has not been consulted (not retrievable), so “Normative” is provisional.

**Licensing (undecided).** Repository licence: MIT or Apache-2.0, to be chosen. Reference licences: Keyman keyboard MIT; pyewts Apache-2.0; m17n-db LGPL 2.1+ (behavioural reference only, no tables copied). Botok, Tibetan NLP, TiSpell, OpenPecha and BDRC resources are **unverified** and each needs an individual licence check before any use.

### Status by item

| Item | Status |
|---|---|
| EWTS → Unicode converter | **Completed**, tests passing |
| Structured diagnostics | **Completed** |
| Unicode → EWTS reverse converter | **Completed** (Exact/Canonical/Lossy; Semantic class **planned**) |
| Incremental composition | **Partial**: whole-buffer re-conversion, no cursor editing |
| Specification | **Partial**: draft 1; THL not checked; differential classification incomplete |
| Curated fixtures | **Partial**: 333 lines vs target 500+ |
| Differential testing | **Partial**: Keyman (interpreter) and pyewts run ad hoc; scripts in `scripts/differential/` |
| cargo-fuzz targets | **Planned** (none run) |
| Performance measurement | **Planned** |
| Orthography (layer 2) | **Deferred** |
| Lexicon/candidates (layer 3) | **Deferred** |
| macOS adapter | **Planned** (first) |
| Windows adapter | **Planned** (second) |
| Linux adapter | **Planned** (third) |
| Phonetic input | **Deferred** |

**Platform order:** core → macOS → Windows → Linux.

## 2. Goals and non-goals

### Goals

- Consistent EWTS behaviour across Windows, macOS, and Linux.
- Fully local input with fast, predictable keystroke response.
- Correct Tibetan Unicode ordering and handling of combining sequences.
- High-quality handling of Sanskrit, punctuation, and extended EWTS.
- Discoverable input rules and understandable diagnostics.
- Optional lexical completions that never override exact transliteration.
- Transparent, licensed, reproducible linguistic data.
- Accessible installation, onboarding, keyboard navigation, and documentation.
- Reusable Rust library independent of GUI and OS-specific APIs.

### Non-goals for initial release

- Phonetic pronunciation-to-spelling conversion.
- Replacing native Tibetan direct keyboard layouts.
- Cloud inference, mandatory accounts, or telemetry.
- Automatic correction of manuscript or historical spellings.
- Full grammatical parsing or large neural prediction models.
- Building a new Tibetan dictionary from scratch.

## 3. Audiences and workflows

| Audience | Primary workflow | Special requirements |
|---|---|---|
| Tibetologist | Type Classical Tibetan from EWTS | Strict conversion, rare stacks, no silent correction |
| Buddhist-studies scholar | Tibetan and Sanskrit quotations | Extended EWTS, punctuation, transliteration fidelity |
| Student | Learn to type Tibetan | Interactive guide, visible composition, helpful errors |
| Multilingual writer | Switch between Tibetan and other scripts | Predictable shortcuts and state |
| Native Tibetan typist using EWTS | Fast Tibetan input | Optional completions, personalized vocabulary |
| Editor/cataloguer | Enter unusual names and manuscript variants | Preserve exact input, auditability |

## 4. Functional requirements

### Layer 1 — deterministic EWTS engine (required)

- Parse EWTS into Unicode Tibetan with a documented, versioned specification.
- Support incremental input, partial syllables, backspace, cursor movement, and commit/cancel.
- Support syllable boundaries, tsheg, punctuation, digits, and Sanskrit extensions.
- Provide a batch conversion API and a streaming/composition API.
- Provide Unicode-to-EWTS reverse conversion with documented limits.
- Expose structured errors and warnings, not just replacement characters.
- Keep the original typed sequence available throughout composition.
- Handle paste and mixed-script input without corrupting adjacent text.
- Avoid unwanted normalization that changes semantically meaningful distinctions.

**Acceptance criteria:** agreed reference corpus passes; round-trip tests pass for a documented subset; IME handles incomplete and malformed input safely; no data loss under repeated editing.

### Layer 2 — orthographic intelligence (optional, local)

- Distinguish invalid EWTS syntax, structurally implausible Tibetan syllables, and unattested vocabulary.
- Show warnings unobtrusively; allow user to disable them globally or per profile.
- Offer correction suggestions with explanations and source provenance.
- Handle historical, dialectal, Sanskrit, and deliberately irregular text without blocking input.
- Keep structural rules independent of lexical dictionaries.

**Acceptance criteria:** curated valid/invalid test sets; false-positive rate measured on historical texts; no warning changes committed output without explicit action.

### Layer 3 — dictionary and candidates (optional, local)

- Prefix completion on EWTS and Unicode forms.
- Distinguish **exact conversion** from **completion** and **correction**.
- Support multi-syllable phrases and tsheg-aware matching.
- Rank using corpus frequency and optionally user-selected frequencies.
- Provide Classical, Modern, and scholarly profiles with separate frequency tables.
- Allow a private user dictionary, import/export, and reset.
- Avoid sending input to network services.
- Later: contextual n-gram ranking and dialect-specific profiles.

**Acceptance criteria:** candidate latency and memory targets met; suggestions are deterministic for fixed data/settings; no candidate is committed without user selection; source and licensing metadata preserved.

## 5. Proposed architecture

```text
                    Offline resource build
 Keyman/m17n/pyewts reference tests    Lexica + annotated corpora
                |                              |
         differential tests            cleaning / tokenization
                |                              |
                +-----------+------------------+
                            |
                     versioned assets
                            |
                  +-------------------+
                  | Rust core crates  |
                  | ewts-parser       |
                  | composition       |
                  | orthography       |
                  | lexicon/candidates|
                  +-------------------+
                            |
                    stable core API
              +-------------+-------------+
              |             |             |
          macOS adapter  Windows TSF   Linux adapter
          InputMethodKit  adapter      IBus/Fcitx5
              |             |             |
         Native UI and onboarding per platform
```

**Current crate layout** (two crates; modularity is inside `ttime-core`):

```text
t-time/
  crates/
    ttime-core/         # no OS or GUI dependencies
      src/ewts/         #   converter, diagnostics, reverse conversion
      src/composition/  #   incremental editing state machine
    ttime-cli/          # command-line front end
  docs/ scripts/
```

`orthography` and `lexicon` become modules of `ttime-core` when layers 2–3 start; split into crates only if a dependency boundary demands it.

**Original aspirational layout** (not current; kept for reference):

```text
tibetan-ime/
  crates/
    ewts-core/          # parser, Unicode conversion, reverse conversion
    composition/        # incremental editing state machine
    orthography/        # structural rules and diagnostics
    lexicon/            # trie/index and candidate ranking
    resources/          # asset schemas and loaders
    ime-api/            # adapter-facing API
  adapters/
    macos/
    windows/
    linux/
  tools/
    corpus-build/
    reference-compare/
    test-fixtures/
  data/
    manifests/
    curated-tests/
  docs/
    specification/
    design/
    user-guide/
```

Use pure Rust for linguistic logic. Choose native adapters on their technical merits; Rust need not implement every platform callback or UI. Keep an explicit boundary between **composition state** and **committed application text**.

## 6. Source-data inventory and audit

The following are **candidates for verification**, not automatically approved dependencies. Confirm current maintenance, provenance, license of code *and data*, encoding, quality, and suitability before adoption.

| Candidate | Intended role | Audit questions |
|---|---|---|
| [Keyman Tibetan EWTS](https://github.com/keymanapp/keyboards/tree/master/release/t/tibetan_ewts) | Interactive behaviour reference | Exact keyboard license, rule coverage, composition edge cases |
| [m17n database](https://git.savannah.gnu.org/cgit/m17n/m17n-db.git) | Independent EWTS implementation | Which bo-ewts rules/version? License and exceptions? |
| [pyewts](https://pypi.org/project/pyewts/) | Batch-conversion oracle | Version, test fixtures, licensing, known divergences |
| [Botok](https://github.com/OpenPecha/Botok) | Segmentation and lexicon pipeline | Dictionary provenance, licensing, historical/modern coverage |
| [Tibetan NLP](https://github.com/tibetan-nlp) | Spellchecking, verbs, annotated data | Which repositories exist and are maintained? Data reuse terms? |
| [OpenPecha](https://github.com/OpenPecha) | Text corpora and NLP resources | Per-dataset licenses, OCR noise, duplicates, domain bias |
| [BDRC](https://www.bdrc.io/) | High-quality Tibetan texts | Rights for each underlying work/transcription; distribution terms |
| [TiSpell](https://github.com/Lyric0620/TiSpell) | Research reference for errors | Availability, model/data licenses, reproducibility |

### Mandatory audit fields

Record for each asset: canonical URL; upstream commit/version; maintainer; license/SPDX; whether redistribution and commercial use are allowed; provenance of embedded data; format; size; script coverage; historical/modern domain; Unicode normalization; OCR/annotation error rate; deduplication method; update policy; and reproducible build checksum.

**License gate:** no corpus or dictionary enters a distributed build until its license and upstream provenance are documented. Do not infer that a tool's Apache/MIT license covers bundled third-party linguistic data.

## 7. Linguistic data pipeline

1. Ingest source text with provenance and license metadata.
2. Validate Unicode and preserve the original unmodified text.
3. Produce a normalized analysis copy, with normalization rules documented.
4. Remove obvious OCR noise, markup artefacts, duplicate passages, and invalid codepoint sequences.
5. Segment into syllables; optionally segment lexical words using Botok or other validated tools.
6. Extract syllable and multi-syllable counts, with domain/source tags.
7. Join with curated dictionaries; keep attested and generated entries distinct.
8. Generate EWTS keys and reversible lookup mappings where possible.
9. Build compact, versioned indices (trie/FST or SQLite for initial prototypes).
10. Evaluate candidate quality against held-out, manually checked texts.
11. Package only legally distributable data with a machine-readable manifest.

Do **not** equate tsheg boundaries with word boundaries. Preserve original text and source provenance so suggestions can be audited.

## 8. Interaction design

### Default typing

- Type EWTS; see a stable preedit/composition display.
- Convert deterministically at defined composition boundaries.
- Commit with predictable Enter/Space behaviour, documented per platform.
- Provide clear escape/cancel and backspace semantics.
- Never silently insert dictionary completions.

### Optional assistance

- Inline syntax warning: **invalid EWTS**.
- Orthography hint: **unusual Tibetan syllable**.
- Lexical hint: **not found in current dictionary**.
- Candidate panel clearly labels **exact**, **completion**, and **correction**.
- Searchable Tibetan punctuation and Sanskrit-character palette.
- Contextual help showing the EWTS sequence for a selected symbol.
- Profile selector: Strict Scholarly, Classical, Modern, Sanskrit Assistance.

### Accessibility

- Entire UI usable by keyboard, with configurable shortcuts.
- Screen-reader labels for controls and candidate positions.
- High-contrast light/dark themes and scalable typography.
- Tibetan fonts selected for coverage and correct shaping; do not ship third-party fonts without permission.
- No dependence on color alone for warnings or selection.

## 9. Platform integration

### macOS

Investigate InputMethodKit lifecycle, preedit/marked-text semantics, secure text fields, input-source registration, signing, notarization, and installer/update strategy. Test in common editors, browsers, LibreOffice, and Word.

### Windows

Implement through the Text Services Framework (TSF), preferably using a small native adapter around the Rust core. Test text stores, composition ranges, candidate UI, application compatibility, high-DPI display, signing, and installer/uninstaller behaviour.

### Linux

Evaluate IBus and Fcitx5 separately; prioritize one for the first release and document desktop/session limitations. Test GNOME/Wayland, KDE/Wayland, X11, Qt, GTK, and LibreOffice. Do not assume the same integration path works in every compositor.

**Cross-platform requirement:** the core conversion results must match; platform-specific keyboard shortcuts and candidate positioning may differ where required by OS conventions.

## 10. Testing and quality assurance

### Linguistic tests

- Curated examples: ordinary Tibetan, complex stacks, Sanskrit, punctuation, numerals, and mixed scripts.
- Differential testing against independent EWTS implementations.
- Property tests: parser safety, round trips for reversible subsets, incremental-vs-batch equivalence where defined.
- Fuzz testing on malformed Unicode and incomplete transliteration.
- Gold-standard historical text set to measure orthographic false positives.
- Held-out Classical and Modern text sets for completion quality.

### IME integration tests

- Insert, commit, cancel, delete, select, paste, and cursor movement.
- Switch languages and applications mid-composition.
- Handle focus changes, application crashes, and secure fields.
- Test candidate selection with mouse, keyboard, accessibility tools.
- Confirm no data leakage or unexpected persistence.

### Proposed performance budgets (to validate)

- Core conversion: p95 under 2 ms for ordinary composition updates.
- Candidate retrieval: p95 under 20 ms for local lookup.
- No network calls on typing path.
- Measure cold start, memory footprint, and binary/data size on all three OSes.

These are engineering targets, not measured current performance.

## 11. Roadmap and exit gates

| Phase | Deliverables | Exit gate |
|---|---|---|
| 0 — Discovery | Source/license audit, EWTS specification, UX research, gold test set | Approved dependencies and scope |
| 1 — Rust core | Batch converter, incremental composition, Unicode tests | Reference suite and fuzz tests pass |
| 2 — First OS adapter | Working IME on one platform, basic installer | Stable typing in target applications |
| 3 — Orthography | Rule engine, diagnostics, exceptions, profiles | Acceptable false-positive rates |
| 4 — Lexicon | Offline dictionaries, completion trie, frequency profiles | Measured suggestion quality and latency |
| 5 — Other OSes | Windows/macOS/Linux adapters and installers | Platform acceptance matrix passes |
| 6 — Beta | Documentation, onboarding, accessibility, crash/bug triage | Pilot users can install and work unaided |
| 7 — Stable | Signed releases, reproducible data builds, maintenance policy | Release checklist and support plan complete |

**Suggested MVP:** phases 0–2 plus a basic searchable symbol palette. Keep orthography and dictionary completion behind feature flags until tested.

## 12. Risks and mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| EWTS implementations disagree | Incorrect scholarly text | Publish normative test corpus; document intentional differences |
| IME composition bugs | Lost or duplicated text | State-machine tests and application compatibility matrix |
| Unicode shaping differs by font | Incorrect visual output | Test multiple fonts and rendering engines |
| OCR-heavy corpora bias suggestions | Bad completions | Gold-standard corpus first; confidence/source tags |
| Lexical resources have unclear licenses | Cannot redistribute | Asset-by-asset legal/provenance gate |
| Classical vs Modern domain mismatch | Irrelevant suggestions | Separate frequency profiles |
| False spelling warnings | Distrust among scholars | Non-blocking hints and strict scholarly mode |
| Platform maintenance burden | Delayed releases | One adapter first, stable core API, CI per OS |
| Scope expansion into phonetic IME | Major NLP project | Explicitly defer pronunciation-to-spelling |

## 13. Decisions to make before coding

1. **First platform:** *decided* — macOS, then Windows, then Linux.
2. **Reference behaviour:** decide which EWTS specification/version and divergences are normative.
3. **Licensing:** choose repository license and compatible data-distribution policy.
4. **Primary corpus:** select a small, legally reusable, manually verified test corpus.
5. **UI toolkit:** choose native platform UI or Qt for shared settings/palette.
6. **Initial profiles:** decide whether MVP includes only strict EWTS or a Sanskrit-focused variant.
7. **Relationship to other projects:** *decided* — T-Time is independent.
8. **Update strategy:** define how keyboard rules and lexical assets are versioned independently.

## 14. First development sprint

**Sprint A — feasibility and specification**

- Create repository and Rust workspace.
- Inventory reference implementations and record licenses/commits.
- Write a precise EWTS input/output and composition-state specification.
- Assemble 300–500 curated conversion cases, including errors and extended stacks.
- Implement a minimal Rust batch converter.
- Compare against at least two independent reference implementations.
- Write a short decision record on normalization and commit semantics.

**Sprint B — composition prototype**

- Implement incremental preedit state, backspace, commit, cancel, and cursor edits.
- Add unit/property/fuzz tests.
- Build a command-line interactive demo.
- Select the first OS adapter and prove composition in two real applications.
- Establish benchmark baselines.

**Sprint C — linguistic data proof of concept**

- Audit one lexical source and one high-quality corpus.
- Produce a tiny licensed dictionary and frequency index.
- Prototype prefix completion separately from exact EWTS conversion.
- Evaluate with 20–30 realistic typing tasks and record failure modes.

## 15. Release and governance

- Publish code, tests, conversion fixtures, and build instructions.
- Include `LICENSE`, `NOTICE`, `THIRD_PARTY_LICENSES`, and per-data-source manifests.
- Pin toolchains and source revisions; publish checksums for linguistic assets.
- Maintain a compatibility matrix for OS versions and applications.
- Use semantic versioning for the core API and separate versioning for linguistic datasets.
- Keep all predictive and correction features opt-in.
- Establish a mechanism for reporting incorrect transliterations with reproducible examples.

## 16. Success criteria

The project succeeds when a new user can install it, select EWTS, type ordinary and complex Tibetan reliably in their preferred applications, discover unfamiliar sequences without external documentation, and optionally obtain useful suggestions **without ever losing control over the exact text produced**.

The differentiator is not inventing a new transliteration standard. It is combining standards-compliant EWTS, scholarly-safe assistance, transparent linguistic resources, and polished cross-platform integration.
