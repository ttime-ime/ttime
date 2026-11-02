# T-Time — `ewts-rs` Evaluation and Web Prototype Plan

**Status:** Proposed; Workstream A completed (§4); B and C prototyped (`crates/ttime-wasm` here; pages in the `playground` repository, whose README records what was checked) · **Date:** 2 November 2026 (revised after the foundation work)  
**Scope:** Technical due diligence, reusable browser infrastructure, and an invitation-ready Tibetologist testing experience  
**Related plan:** `docs/tibetan_ewts_ime_plan.md`  
**Reference project:** https://github.com/emgyrz/ewts-rs  
**Reference demonstration:** https://emgyrz.github.io/ewts-rs/

> **Evidence boundary:** The first draft of this plan treated the external repository as unaudited. A partial audit is now in `docs/audits/ewts-rs.md` (metadata, licence, API, behavioural comparison). Its source, wasm demo and benchmark claims have **not** been examined. Do not adopt code or quote benchmark claims without reproducing them.

## 1. Executive decision

Build a **small, static, browser-based T-Time writing laboratory** backed by the existing Rust `ttime-core`, compiled to WebAssembly. Before implementation, conduct a time-boxed audit of `ewts-rs` to decide whether it should be (a) a dependency, (b) an independent differential-testing reference, or (c) merely an architectural example.

The website's immediate purpose is **recruitment and substantive feedback from a Tibetologist**, not a public product launch. It should demonstrate real EWTS composition and expose its limitations honestly. No dictionary, phonetic conversion, or candidate UI should be simulated.

**Default until evidence changes:** Keep the existing T-Time converter; use `ewts-rs` as an independent comparison target; implement a thin `ttime-wasm` bridge and an original browser interface. Do not rewrite the converter or duplicate its rules in JavaScript.

## 2. What success looks like

A prospective collaborator can open a URL, type EWTS, see correctly rendered Tibetan, copy Unicode text, inspect the transliteration, try difficult examples, and submit a precise problem report **without installing software or creating an account**.

The prototype should answer three questions:

1. Is T-Time's transliteration sufficiently correct for real scholarly material?
2. Does its live typing interaction feel usable compared with the Tibetologist's current workflow?
3. Which *actual* unmet needs justify orthographic assistance, dictionary completion, or additional input methods?

**Success is not** a polished marketing site, high traffic, or a fully functional desktop IME.

## 3. Existing baseline and constraints

Revalidated against the repository on 2 November 2026:

- Rust workspace with `ttime-core` and `ttime-cli`; the core has no OS or GUI dependencies.
- 701 curated fixture lines in 11 files, plus 17 diagnostic, 14 reverse-conversion, 15 property and 14 unit tests, and six `cargo-fuzz` targets (60-second smoke run each, no findings).
- Differential comparison with pyewts 1.0.0, ewts-rs 0.1.4 and the Keyman keyboard (pinned commit); m17n compared by hand on its stack inventory.
- Structured diagnostics (15 codes) and Unicode → EWTS reverse conversion with Exact / Canonical / Lossy fidelity are implemented.
- Composition: `Engine` with `push(char)`, `backspace`, `preedit`, `commit`, `cancel`. It **re-converts the whole buffer on every keystroke and has no cursor model**.
- NFC-stable default; the precomposed option is not NFC. ADR 0001 is **Proposed**.
- Open scholarly questions are collected in `docs/review/expert-review.md`; none are settled and the THL text has not been checked.

Re-check these facts before editing. Keep `ttime-core` and `ttime-cli` names; do not reorganize into speculative crates. macOS remains the first planned native adapter; Windows and Linux follow later.

## 4. Workstream A — audit `ewts-rs`

**Status: completed on 2026-11-02 (partial audit, stated gaps).** Deliverables: `docs/audits/ewts-rs.md`, `docs/decisions/0002-ewts-rs-integration.md` (Proposed: independent reference only), the comparison harness `scripts/differential/ewts-rs-diff`, and `docs/review/disagreements.md`. Findings that matter here: no LICENSE file in the upstream repository and an unlicensed dictionary source (so no vendoring), forward-only and no diagnostics or composition (so no adoption), and one real T-Time gap found and fixed. The subsections below are the original task list, kept for reference.

### A1. Establish provenance and legal status

Record the exact upstream commit, version, release date, repository URL, and license file. Determine whether the license applies to the entire workspace and whether third-party tables or test corpora have separate terms. Check dependencies, transitive licenses, and whether the code can be redistributed within T-Time's proposed licensing model. **Do not assume an open GitHub repository is permissively licensed.**

### A2. Map architecture and capabilities

Inspect the actual workspace and source. Record whether it provides:

| Capability | Questions to answer |
|---|---|
| Forward EWTS conversion | API shape, completeness, punctuation, Sanskrit, errors |
| Reverse conversion | Supported code points, canonicalization, lossiness |
| Browser build | Wasm toolchain, generated artifacts, deployment approach |
| Incremental composition | Does it support keystrokes and edits, or only whole strings? |
| Unicode policy | NFC, precomposed/decomposed handling, canonical stability |
| Diagnostics | Invalid and incomplete sequences, spans, warning categories |
| C/native interface | Exists? Maintained? Useful for T-Time? |
| Testing | Fixtures, fuzzing, reference implementations, CI |
| Maintenance | Recent commits, unresolved issues, release history |

**Do not infer an interactive IME from a webpage that converts text.** Batch transliteration and composition are separate capabilities.

### A3. Differential evaluation

Create a reproducible comparison harness that runs the same input cases through T-Time and `ewts-rs`, and, where practical, m17n and pyewts. Pin external versions. Keep upstream implementations out of the production runtime during the audit.

Use the existing ~330 fixtures first, then add a focused corpus of difficult cases: consonant stacks, Sanskrit extensions, punctuation, whitespace, incomplete input, invalid sequences, long strings, combining marks, and canonical equivalents.

For each discrepancy, capture:

```text
case_id
input_ewts
expected_unicode (if independently established)
ttime_output
ewts_rs_output
other_reference_outputs
unicode_codepoints
normalization_form
classification
notes / specification citation
```

Classification: **T-Time defect / upstream defect / convention difference / normalization-only difference / ambiguous / unresolved**. Never choose the majority output as automatically correct. Compare code points, not only visual rendering.

### A4. Decision gate

Write `docs/decisions/0002-ewts-rs-integration.md` comparing:

| Option | Advantages | Risks |
|---|---|---|
| Adopt as dependency | Less duplicated converter maintenance; possible reverse conversion | API/license coupling; may not fit incremental composition or diagnostics |
| Vendor/fork | Control over fixes and release cadence | Ongoing maintenance; attribution and license obligations |
| Independent reference only | Preserves existing work; excellent differential oracle | Two codebases to understand; no immediate feature reduction |
| Architectural inspiration only | Minimal dependency | Limited correctness benefit |

**Recommendation must be evidence-based.** Do not replace `ttime-core` solely because another Rust implementation exists. If integration is justified, first prove it behind a stable adapter interface and preserve existing tests.

**Exit criteria:** versioned audit report, reproducible comparison results, license determination, and a recorded adopt/reference/reject decision.

## 5. Workstream B — minimal WebAssembly bridge

Create a thin WebAssembly package, tentatively `ttime-wasm`, depending on `ttime-core` and **not** on `ewts-rs` or `ewts-wasm` (ADR 0002). Keep the core independent of browser APIs and UI frameworks. Only add a workspace crate if that fits the existing repository structure.

Suggested boundary (illustrative, not prescribed):

```text
Browser UI (TypeScript / HTML / CSS)
       │
       ▼
ttime-wasm (wasm-bindgen bindings)
       │
       ▼
ttime-core (EWTS conversion + composition)
```

Provide a small stable interface for:

- `convert(input, options) -> { text, diagnostics }` (diagnostics may initially be empty/limited).
- `create_session(options)`, `insert_text`, `backspace`, `reset`, `get_state` or an equivalent composition API.
- Explicit `commit` behavior and a clear distinction between provisional and committed text.
- `version()` identifying the Rust core build/commit for reproducible reports.

Do not expose a reverse-conversion button until reverse conversion is implemented and tested. Do not claim full Unicode editor support when only append/backspace is available.

### Provisional versus committed text

`Engine::preedit()` re-converts everything typed so far, so earlier output can change as later letters arrive (`g` becomes ག, then `gya` becomes གྱ). The Writing Room therefore needs an explicit commit policy before any UI work. Proposed first policy, to be tested with a user: keep the current syllable provisional; commit on space (tsheg), shad or other punctuation, and on explicit Enter or blur; never rewrite committed text. Whether committing mid-word hurts Sanskrit stacks typed across a space-less run (`masti`) must be tried in practice. The inspector must label which part is provisional. Backspace crossing a commit boundary needs a stated rule (proposed: it edits only provisional text; committed text is edited through ordinary browser editing).

### Browser interaction caveat

A browser text field does not automatically behave like a system-wide IME. Decide how `beforeinput`, `input`, `keydown`, paste, selection, and browser-native composition events interact. Avoid intercepting system IME events indiscriminately. Preserve accessibility, clipboard behavior, and mobile keyboard compatibility where feasible. Test actual editing sequences rather than only batch conversion.

**Recommended first implementation:** controlled composition at the end of the document, with clear UI affordances and an honest limitation notice. Add arbitrary-caret editing only after the core has a tested edit model. A separate batch-conversion inspector can provide a reliable fallback during early testing.

## 6. Workstream C — T-Time Writing Room

> **Update:** the site now has two modes, as recommended: a **Converter** (two boxes, bidirectional, diagnostics and round-trip fidelity) to test conversion correctness, and the **Writing Room** to test the typing experience. They test different things, and good conversion does not imply good typing.

### C1. Purpose and tone

A restrained, friendly scholarly instrument: inviting enough for a first encounter, serious enough to inspire confidence. Use the established T-Time identity; Momo and Tibby can appear subtly, but should not crowd the writing surface. Avoid mock candidate menus or promises of features that do not exist.

### C2. Initial page

**Header:** T-Time · *An experimental Tibetan writing room* · prototype version.

**Primary editor:** large Tibetan writing surface with good line height, clear focus state, multiline support if implemented, and copy-to-clipboard. Live EWTS composition is the central experience.

**Controls:** EWTS on/off, clear, copy Unicode, optional font switch, help/shortcuts. Keep controls compact.

**Inspector (collapsible):** show raw EWTS, Unicode output, code points, normalization form, and available diagnostics. Make clear whether the inspector represents the active composition or committed text.

**Examples:** one-click inputs for ordinary Tibetan, stacks, punctuation, Sanskrit, and an unusual/edge-case sequence. Each example should state what it tests and should be reviewed for linguistic correctness before public use. Only examples from `corpus.tsv` or `thl_rules.tsv` (agreed by other implementations) or confirmed by the specialist should be shown as ordinary; anything from `docs/review/expert-review.md` must be labelled as an open question.

**Feedback:** a short form or locally generated report with actual input, actual output, expected output, optional comment, browser/platform, and engine version. **Preview exactly what will be sent.** Offer copy-report as a no-backend fallback.

**Footer:** experimental status, privacy note, project source/license, contact, and a link to known limitations.

### C3. Typography

Evaluate at least two freely redistributable Tibetan fonts, for example Noto Serif Tibetan and Jomolhari, after verifying their current licenses. Check stack rendering across browsers and operating systems. Allow a font toggle for diagnosis; do not confuse font-shaping defects with conversion defects. Test the actual browser-rendered code-point sequences.

### C4. Explicit non-features

Do not implement in this milestone: account creation, cloud storage, dictionary suggestions, AI correction, phonetic dialect conversion, user telemetry, collaborative editing, or native desktop installation. Do not fake any of these in the interface.

## 7. Privacy and feedback handling

Default to **local-only conversion**: no typed text sent to a server for processing. A static site can serve the Wasm binary and interface assets without a backend. Be precise: hosting infrastructure may still log requests, and third-party resources can generate network traffic.

Feedback should be **opt-in**. Provide a preview, redact/remove text at the user's discretion, and explain where reports go. For the first collaborator, a copyable diagnostic report or email draft may be sufficient; a public issue tracker is not appropriate for confidential research passages by default. Do not automatically upload complete writing sessions.

If collecting reports centrally later, establish retention, access controls, spam protection, and a concise privacy notice before enabling submission.

## 8. Deployment and infrastructure

Start with a static host such as GitHub Pages. A custom domain can wait. Avoid introducing a backend solely to serve the converter.

Suggested CI pipeline:

```text
Pull request / main branch
    ├── cargo fmt --check
    ├── cargo clippy / cargo test
    ├── differential fixture checks (offline, pinned)
    ├── wasm build
    ├── browser smoke tests
    └── deploy static assets on approved branch
```

Pin Rust and JavaScript toolchains where practical. Use a reproducible lockfile and record the build's commit ID in the UI. Prefer no external runtime scripts or CDN dependencies. Set appropriate caching for fingerprinted Wasm/assets and avoid stale `index.html` after releases.

A preview URL is **not private access control**. GitHub Pages serves a public site even from a private repository, and Pages on a private repository requires a paid plan; check the account's plan before choosing it, and state plainly that the page is public. If a prospective collaborator needs confidentiality, use a host with actual access protection; otherwise explicitly state that the test page is publicly reachable.

## 9. Testing matrix

| Area | Minimum checks |
|---|---|
| Conversion | All existing fixtures pass through native Rust and Wasm |
| Composition | Insert, backspace, commit, syllable boundaries, repeated edits |
| Unicode | Code-point comparison, canonical equivalents, copy/paste |
| Browsers | Current Safari, Firefox, Chrome desktop |
| Platforms | macOS initially; at least one Windows and Linux browser before broader sharing |
| Fonts | Complex stacks, Sanskrit signs, punctuation, fallback behavior |
| Accessibility | Keyboard-only use, focus order, labels, zoom, screen-reader basics |
| Error handling | Unknown/incomplete input does not crash or silently corrupt committed text |
| Feedback | Report captures version and reproducer only after user approval |
| Privacy | No network submission of editor content during ordinary typing |

Add automated browser tests for core user journeys, but also conduct manual tests: browser selection and composition behavior can be subtle.

## 10. Tibetologist evaluation protocol

Recruit one prospective collaborator for a **15–20 minute exploratory session**. Make clear that this is a prototype and that criticism is useful. Do not begin by asking for a long-term commitment.

Suggested sequence:

1. **Baseline (3 minutes):** Ask what operating system, input method, Tibetan varieties/registers, and applications they currently use.
2. **Free typing (5 minutes):** Let them type familiar material without coaching. Observe interruptions, correction behavior, and expectations.
3. **Scholarly edge cases (5 minutes):** Ask the participant to try real difficult sequences: stacks, Sanskrit, punctuation, manuscript spellings, or whichever cases matter to their work. Add a short, separate set of the open questions from `docs/review/expert-review.md` (for example `oM`, `kii`, `ghri`) and record the answers verbatim; these decide spec items, not preferences.
4. **Workflow transfer (3 minutes):** Copy Unicode output into their normal editor and inspect rendering.
5. **Discussion (5 minutes):** Ask what is missing, what would justify switching, and whether Classical/Modern profiles or candidate completion would help or distract.

Avoid treating the first participant as representative of all Tibetologists. Record qualitative findings and concrete reproductions separately. Do not collect their source texts without permission.

### Questions that should drive roadmap decisions

- Is EWTS their primary method, or do they prefer a direct Tibetan keyboard?
- Do they want conversion, faster typing, validation, completion, or better document interoperability?
- Which errors or interruptions cost them time today?
- Is dictionary assistance welcome, and when should it remain silent?
- Do they need dialect-specific **phonetic** input, or merely different written-vocabulary profiles?
- Would they be interested in advising, testing periodically, contributing data, or co-designing features?

## 11. Proposed schedule (indicative)

| Stage | Deliverable | Target effort | Gate |
|---|---|---:|---|
| 0 | Repository and external-project audit | 1–2 days | License/API/comparison evidence |
| 1 | Integration ADR | 0.5 day | Explicit adopt/reference decision |
| 2 | Wasm wrapper + smoke test | 1–2 days | Native/Wasm fixture parity |
| 3 | Writing Room MVP | 2–4 days | Real typing, copy, inspector |
| 4 | Browser/Unicode QA + feedback | 1–2 days | Invitation-ready, limitations disclosed |
| 5 | Tibetologist session | 1 session | Findings and prioritized issues |
| 6 | Roadmap revision | 0.5–1 day | Evidence-based next milestone |

These are rough engineering estimates, not commitments. Caret handling, complex-script rendering, or Wasm incompatibilities could extend the schedule. **Time-box the website**; don't let it become a second product.

## 12. Decisions and unresolved questions

| Decision | Proposed position | Status |
|---|---|---|
| Product name | T-Time | Adopted in project discussion |
| Branding | Momo/Tibby, restrained scholarly interface | Direction set |
| Core | Existing `ttime-core` | Default pending audit |
| `ewts-rs` | Independent reference unless audit justifies adoption | Open |
| Web runtime | Rust → Wasm, static site | Proposed |
| Initial native platform | macOS | Agreed direction |
| Classical/Modern | Written vocabulary/frequency profiles, not dialect phonetic engines | Proposed |
| Phonetic dialect input | Future research, not MVP | Deferred |
| Unicode normalization | NFC-stable default; precomposed option under review | ADR pending |
| Diagnostics | Structured, non-destructive | Planned |
| Reverse conversion | Planned; no fake UI before ready | Planned |
| Dictionary completion | Not part of web MVP | Deferred |
| Hosting | Static deployment, public preview unless protected | Proposed |
| Feedback | Explicit opt-in; local report fallback | Proposed |
| Original code license | MIT or Apache-2.0 under consideration | Open |

## 13. Deliverables and acceptance criteria

### Required repository artifacts

- `docs/audits/ewts-rs.md` — versioned technical and licensing audit.
- `docs/decisions/0002-ewts-rs-integration.md` — dependency decision with evidence.
- A reproducible converter comparison harness and discrepancy fixtures.
- Thin Wasm binding package integrated with `ttime-core`.
- Static Writing Room web application.
- Browser smoke tests and a short deployment README.
- `docs/research/tibetologist-evaluation.md` — interview protocol and findings template.
- Updated `docs/tibetan_ewts_ime_plan.md` milestone references, without erasing the broader plan.

### Invitation-ready definition of done

- [ ] Web and native builds agree on the same curated fixtures.
- [ ] A user can type EWTS and obtain usable Tibetan Unicode in the browser.
- [ ] Copy/paste works into at least one external editor.
- [ ] Incomplete input and known editor limitations are explained, not hidden.
- [ ] Tibetan stacks render correctly in tested browsers/fonts.
- [ ] The inspector provides a reproducible view of input and output.
- [ ] Feedback is explicit, reviewable, and does not silently transmit text.
- [ ] No unverified dictionary or dialect functionality is advertised.
- [ ] External code/data licensing is documented before incorporation.
- [ ] A real Tibetologist can complete the evaluation without installing software.

## 14. Instructions for the coding agent

1. Inspect the actual T-Time repository and the upstream `ewts-rs` repository before implementing anything.
2. **Do not assume** the upstream crate layout, APIs, license, or performance from secondhand descriptions.
3. Complete the audit and ADR first; pause if licensing or conversion correctness is materially uncertain.
4. Preserve the existing `ttime-core` public interface unless there is a justified, tested change.
5. Prefer small commits by workstream: audit, Wasm, UI, tests, deployment.
6. Keep all transliteration rules in Rust; JavaScript should handle only browser interaction and presentation.
7. Do not claim that a web converter is equivalent to a native IME.
8. At the end, report precisely what was verified, implemented, tested, deferred, and still uncertain.

**Next action:** Audit `ewts-rs` against T-Time's existing fixtures and write the integration decision. Then build the smallest real WebAssembly typing prototype that a Tibetologist can use and critique.
