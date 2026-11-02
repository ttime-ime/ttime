# T-Time — Scholarly Functionality and Toolbar Roadmap

**Status:** Planning proposal · **Date:** 2 November 2026  
**Audience:** T-Time developers, prospective Tibetologist collaborators, and usability testers  
**Scope:** Product differentiation, feature prioritization, interface boundaries, research validation, and staged delivery

## 1. Executive decision

T-Time should not justify a persistent branded toolbar merely by offering EWTS-to-Unicode conversion. Existing tools already do that. Its defensible purpose is to become a **scholarly Tibetan writing assistant**: reliable, non-destructive input complemented by discoverable characters, Sanskrit assistance, personal/project terminology, and optional orthographic guidance.

**Immediate decision:** Build a strong IME core and a small **symbols/Sanskrit palette** plus a **conversion/Unicode inspector**. Test these with a Tibetologist before committing to predictive dictionaries or a permanently visible floating toolbar.

**Design rule:** The toolbar follows demonstrated needs; the product must remain useful with the toolbar hidden.

## 2. Existing foundation and assumptions

The current project has a Rust EWTS conversion engine (`ttime-core`), a CLI (`ttime-cli`), WebAssembly integration, and a separate browser playground with Writing Room, Converter, and parity/diagnostics interfaces. The existing implementation has been reported to include roughly 330 fixtures and initial composition support; confirm the latest repository state before planning implementation tasks.

This document is a **forward-looking product plan**, not a claim that proposed features are implemented. It does not replace the EWTS specification, normalization ADR, or converter audit. No particular third-party lexical dataset is approved for redistribution until audited.

### 2.1 Target users

- Tibetologists entering Classical Tibetan, editions, commentaries, and manuscript transcriptions.
- Researchers handling Sanskrit in Tibetan script and specialized punctuation.
- Editors working across Word, LibreOffice, browsers, and scholarly text tools.
- Potential later audiences: Modern Tibetan writers and users of dialect-sensitive phonetic input.

### 2.2 Non-negotiable principles

1. **Deterministic input remains authoritative.** EWTS conversion never depends on a dictionary.
2. **No silent corrections.** Unusual historical spellings and deliberate manuscript errors remain enterable.
3. **Offline-first and private.** Personal/project lexica stay local unless explicitly exported or shared.
4. **Cross-platform core.** Platform adapters are separate; macOS first, Windows/Linux later.
5. **No invented features.** Experimental controls are hidden or clearly labelled until functional.
6. **Accessibility and keyboard use.** Core functions work without a floating toolbar.
7. **Scholarly provenance.** Suggestions and validation must identify their basis where possible.

## 3. Product boundaries: IME, tools, and web playground

| Surface | Appropriate responsibilities | Avoid |
|---|---|---|
| **T-Time Input (IME)** | EWTS composition, mode/status, punctuation insertion, Sanskrit input help, optional candidate display, vocabulary profile selection | Arbitrary rewriting of selected document passages without host API support |
| **T-Time Tools (companion panel)** | Unicode/EWTS inspection, batch conversion, normalization comparison, text cleanup previews, dictionary import/edit, later segmentation | Pretending to be a document editor or OCR suite |
| **T-Time Playground (web)** | Demonstrate converter and composition, showcase palette/inspector, collect reproducible feedback | Claiming to test native IME integration or system-wide text selection |

A native IME usually controls its own composition and committed text, **not arbitrary existing document selections**. Selection-based transformations must be evaluated separately for each host or implemented in a companion tool/plugin.

## 4. Feature portfolio and priority

Priority labels: **P0** foundational, **P1** early differentiator, **P2** validated expansion, **P3** research horizon.

| Feature | Priority | User value hypothesis | Technical dependencies | Where it belongs |
|---|---|---|---|---|
| Reliable EWTS composition/editing | P0 | Trustworthy everyday typing | EWTS core, cursor/composition model | IME + playground |
| Input mode/status and shortcuts | P0 | Predictable control without distraction | OS adapters | IME |
| Searchable Tibetan punctuation/marks palette | **P1** | Avoid memorizing rare sequences or copying symbols | Curated Unicode catalogue | IME + playground |
| Sanskrit/extended-stack explorer | **P1** | Discover complex sequences and supported EWTS forms | Verified converter coverage, font tests | Palette + playground |
| EWTS/Unicode/code-point inspector | **P1** | Diagnose invisible or unexpected sequences | Reverse converter, diagnostics | Tools + playground |
| Non-destructive Unicode/tsheg checks | P2 | Identify suspicious encoding/spacing without rewriting evidence | Diagnostic rules, reference tests | Tools; limited IME hints |
| Personal and project dictionaries | **P2** | Speed recurring names, terms, and formulae | Import format, lexicon, local storage | IME + Tools |
| Classical/Modern lexical profiles | P2 | More relevant completions by written register | Licensed corpora, frequency data | IME |
| Dictionary completion/candidates | P2 | Reduce repetitive typing | Trie/index, ranking, UI | IME |
| Orthographic assistance | P2 | Flag likely errors while preserving unusual forms | Orthographic rules, evaluated lexica | IME + Tools |
| Batch conversion/cleanup | P2 | Improve scholarly editing workflows | Reversible preview, export | Tools |
| Corpus-aware segmentation | P3 | Aid annotation/search workflows | Tokenizer, licensed corpus, evaluation | Tools |
| Pronunciation-to-spelling by spoken dialect | P3 | Broaden access beyond EWTS | Dialect phonology, lexicon, native-speaker evaluation | Separate input engine + candidates |

**Important distinction:** Classical/Modern are written-register profiles, **not spoken dialects**. The Momo/Tibby branding does not establish phonetic input support.

## 5. First tangible differentiator: symbols and Sanskrit palette

### 5.1 Minimum viable palette

- Search by Unicode name, code point, descriptive label, or EWTS sequence when known.
- Categories: punctuation, opening/closing marks, editorial marks, Sanskrit/extended characters, recently used.
- Each entry shows a large glyph, name, code point(s), supported input sequence, and a short usage note when verified.
- Insert at the current composition position where supported; otherwise provide an explicit **Copy** action.
- Accessible keyboard navigation, focus return, and screen-reader labels.
- Font fallback and clear warnings when a glyph cannot be displayed reliably.

### 5.2 Curatorial constraints

Begin with a **small, reviewed catalogue**, not every code point in the Tibetan Unicode block. Unicode names are not usage instructions; scholarly labels and EWTS sequences require validation. Do not invent transliteration mappings for characters unsupported by the engine. Distinguish Unicode characters from glyph variants and manuscript marks with no standardized Unicode encoding.

### 5.3 Sanskrit assistance

Provide a discoverable stack reference and a small set of verified examples. Prefer helping users find the correct EWTS sequence over introducing a visual stack builder prematurely. Complex stacks require cross-font and cross-browser rendering tests.

### 5.4 Acceptance tests

- Every palette entry has verified Unicode output and provenance for any input mapping.
- Insert/copy works without corrupting composition state.
- No missing or clipped marks in the tested font/browser matrix, or limitations are explicitly documented.
- A first-time tester can locate and insert a selected rare mark without consulting external documentation.

## 6. Second differentiator: Unicode and EWTS inspector

The inspector should explain exactly what the engine produced without implying that the output is wrong.

**MVP fields:** EWTS input; resulting Tibetan; direction; code points in order; normalization status; reverse-conversion fidelity; structured warnings; engine/build version.

**Controls:** Copy EWTS, copy Tibetan, copy code points, generate a minimal bug report. The report should be inspectable before sharing and should never transmit user text automatically.

**Future checks:** unexpected combining order, tsheg/whitespace anomalies, unsupported sequences, and normalization differences. Keep Unicode validity, orthographic plausibility, and lexical attestation as distinct concepts.

## 7. Candidate layer: only after user validation

### 7.1 Completion model

EWTS input has a deterministic conversion; candidate entries are **completions or suggestions**, not competing Unicode readings of the same input. For example, entering `bstan` may yield the exact conversion and optional longer entries such as `bstan pa` or `bstan 'dzin` when attested by the active lexicon.

### 7.2 Data model

Each entry should support:

- Unicode form and canonical EWTS form.
- Entry type (word, expression, person, place, Sanskrit term, user-defined).
- Written-register profile and project association.
- Frequency/ranking signals, with source and corpus version.
- Provenance, license/redistribution status, and editorial notes.
- User override or suppression without altering the underlying source record.

### 7.3 Ranking and control

Start with exact-prefix matching and deterministic frequency ranking. Keep user dictionaries separate from global resources. Provide an obvious **Suggestions Off** state. Never auto-commit an extended completion or silently normalize a scholarly spelling.

### 7.4 Research gate

Do not begin large-scale corpus ingestion until a Tibetologist confirms that completion would improve actual writing tasks, and a licensing/quality audit establishes suitable sources.

## 8. Orthographic intelligence: advisory, explainable, reversible

Maintain separate diagnostic layers:

1. **Transliteration syntax:** EWTS parse and unsupported sequences.
2. **Structural orthography:** plausible Tibetan syllable construction.
3. **Lexical evidence:** whether a form appears in a particular dictionary/corpus.

A form absent from a dictionary is not necessarily invalid. Avoid global “correct/incorrect Tibetan” labels for historical material. Diagnostics should identify source, confidence or rule, and whether they can be disabled. No automatic substitution.

## 9. Toolbar strategy

### 9.1 Initial UI

**Preferred:** OS-native status/menu item, keyboard shortcuts, and an optional compact floating toolbar rather than a permanently intrusive panel.

Initial toolbar, only when the corresponding functions work:

`[T-Time logo]  |  [EWTS/status]  |  [Symbols]  |  [Settings]`

The logo opens Help/About and project documentation. Status is visible without a branded toolbar where the OS already provides it.

### 9.2 Later UI

Once tested and implemented:

`[T-Time]  |  [Input mode ▾]  |  [Vocabulary profile ▾]  |  [Suggestions]  |  [Symbols]  |  [Settings]`

Keep controls few and intelligible; do not place batch normalization, segmentation, or dictionary management directly on the floating bar. These belong in Tools.

### 9.3 Toolbar go/no-go criterion

A persistent toolbar is justified only if observational testing shows that users repeatedly need at least two or three of its functions during ordinary writing and cannot access them more efficiently through shortcuts or the system input menu. Otherwise default to a small status control and on-demand palette.

## 10. Tibetologist discovery and evaluation

### 10.1 Goal

Identify real interruptions in scholarly Tibetan writing, rather than asking testers to approve an already-chosen feature list.

### 10.2 Interview prompts

- What keyboard/input method do you currently use, and why?
- When working with Tibetan, what repeatedly forces you to leave the keyboard?
- Which marks, Sanskrit stacks, names, or terms are difficult to enter?
- How often do you convert between Tibetan Unicode and EWTS?
- Are the problems different for Classical Tibetan, Modern Tibetan, and manuscript transcription?
- Would completions help, or interrupt your work?
- Which corrections would be unacceptable in a diplomatic transcription?
- Would a floating toolbar be welcome, or distracting?
- What would make you switch from your present method?

### 10.3 Guided 20-minute session

| Time | Task | Observe |
|---|---|---|
| 0–4 min | Current workflow discussion | Existing tools and pain points |
| 4–9 min | Write ordinary Tibetan in Writing Room | Speed, confidence, editing friction |
| 9–14 min | Enter Sanskrit and rare punctuation using palette | Discoverability and actual need |
| 14–17 min | Inspect and copy a difficult sequence | Understanding of Unicode/diagnostics |
| 17–20 min | Compare proposed toolbar and on-demand menu | Preferred interaction and priorities |

Ask permission before retaining sample text. Offer copyable, user-reviewed bug reports; avoid automatic collection of scholarly material.

### 10.4 Evidence and decision log

Record observed tasks, frequency, severity, workarounds, and requested features. Separate direct observations from assumptions. After each session, update a ranked backlog and identify features to **reject or defer**, not just features to add.

## 11. Technical architecture

```text
                 ttime-core (Rust)
                 /       |       \
         EWTS engine  diagnostics  lexicon (future)
               |          |          |
          ttime-wasm / stable internal API
               |                     \
       ttime-playground             native adapters
       Writing Room/Tools          macOS → Windows/Linux
               |
       shared palette catalogue
       + inspected, versioned resources
```

- Keep conversion rules in Rust, not duplicated in JavaScript.
- Maintain a versioned, machine-readable symbol catalogue with tests.
- Keep platform-specific insertion/selection operations behind adapters.
- Use a separate companion tool for arbitrary batch text processing.
- Keep optional lexical databases separate from the core converter.
- Ensure build and corpus versions appear in reproducible reports.

## 12. Resource and licensing audit

Before integrating external resources, record: repository/dataset URL, exact version, license, scope of license, dependencies, redistribution rights, provenance, and quality concerns. Distinguish code from dictionaries, model weights, and underlying copyrighted texts.

Potential research inputs include Keyman EWTS, m17n, pyewts/ewts-rs, Botok, Tibetan NLP, OpenPecha, and BDRC. **Listing a resource here is not approval to copy or redistribute it.** The existing engine and independently authored mappings remain the default unless an explicit integration decision is recorded.

## 13. Phased roadmap

### Phase A — Consolidate the engine and playground (foundation)

- Complete/maintain EWTS specification, normalization ADR, structured diagnostics, reverse conversion, and parity tests.
- Verify browser composition and text copying.
- Publish a clear experimental-status statement and version information.

**Exit:** A Tibetologist can type and inspect examples without installation, with known limitations documented.

### Phase B — Symbols and Sanskrit palette (first differentiation)

- Curate a small Unicode catalogue and verified EWTS mappings.
- Build searchable palette in playground; test insertion and copy.
- Provide accessible Sanskrit/extended-stack examples.
- Add a compact inspector and reproducible report export.

**Exit:** Tested examples are discoverable and correctly inserted/copied; no regression in conversion behaviour.

### Phase C — External evaluation (decision gate)

- Conduct at least two structured sessions if collaborators are available, including one experienced Tibetologist.
- Observe actual tasks and record friction points.
- Decide whether the native toolbar is warranted and which functions deserve priority.

**Exit:** Written, evidence-based feature priorities and a revised product hypothesis.

### Phase D — macOS IME and optional toolbar

- Implement native composition and keyboard shortcuts.
- Integrate palette via supported OS mechanisms.
- Prefer native status/menu UX; make floating toolbar optional.
- Test across target applications.

**Exit:** Reliable native writing without requiring a floating toolbar.

### Phase E — Personal lexica and assistance (conditional)

- Design import/export and per-project vocabulary profiles.
- Evaluate dictionary licensing and data quality.
- Add optional completion and advisory orthography only if user testing supports them.

**Exit:** Suggestions demonstrably save effort without corrupting or obscuring scholarly input.

### Phase F — Windows/Linux and longer-term research

- Port native adapters without changing EWTS semantics.
- Evaluate text-processing companion features, segmentation, and dialect-specific phonetic input as separate research projects.

## 14. Risks and mitigations

| Risk | Mitigation |
|---|---|
| Building a toolbar nobody wants | Validate workflow first; keep toolbar optional |
| Scope creep into general DH software | Separate IME, Tools, and Playground responsibilities |
| Incorrect Unicode or broken stacks | Specification, code-point inspection, font/browser tests |
| Dictionary suggestions harming historical work | Advisory-only, opt-in, provenance, no silent corrections |
| OCR noise contaminating vocabulary | Curated corpora, source confidence, corpus-specific profiles |
| Licensing conflicts | Per-resource audit before import or redistribution |
| Platform API limits on selected text | Explicit capability matrix; companion tools/plugins |
| Visual branding obscuring usability | Restrained controls, typography-first, keyboard accessibility |

## 15. Success measures

Prioritize **observed outcomes**, not the number of features or toolbar buttons:

- Users complete common typing tasks without consulting external character lists.
- Rare marks and Sanskrit sequences can be found and entered reliably.
- Diagnostic reports reproduce issues with exact engine version and input.
- Testers can explain when and why they would use the palette or inspector.
- Users can work with the toolbar hidden and retain all essential input capabilities.
- If completion is introduced, measured time/keystroke savings exceed interruption costs.
- No silent normalization or correction changes scholarly evidence.

## 16. Immediate work package for the coding agent

1. Audit existing playground controls, composition behaviour, and diagnostic API.
2. Propose a compact, versioned symbol catalogue schema with verified examples.
3. Implement a searchable palette in the playground, initially with copy and safe insertion.
4. Improve the Unicode/EWTS inspector and user-reviewed bug-report export.
5. Add automated tests for mapping, insertion, Unicode output, and accessibility basics.
6. Prepare a concise tester script and feedback form.
7. **Do not** implement dictionary completion, dialect phonetic input, or a permanent floating toolbar in this work package.

### Deliverables

- Working palette and inspector in the web playground.
- Verified catalogue with source notes.
- Test results and known rendering limitations.
- Research-session script and observation template.
- Updated decision log: toolbar status, proposed features, and deferred work.

---

## Final product principle

**T-Time should earn its interface through useful work.** The immediate opportunity is not to out-brand existing EWTS keyboards, but to make difficult Tibetan text easier to enter, inspect, and trust—without compromising the freedom essential to philological scholarship.
