# T-Time IME: Toolbar, Preferences, and Input Behaviour Plan

**Status:** Working decision record · 2 November 2026  
**Scope:** Native T-Time IME, with related browser/companion tools identified separately  
**Principle:** Every visible control must solve a recurring user problem. Do not create features to justify a branded toolbar.

## 1. Executive decision

T-Time is first and foremost a **deterministic EWTS-to-Tibetan Unicode input method**. Its value should come from reliable composition, accurate conversion, predictable editing, and useful access to uncommon characters—not from a crowded floating toolbar.

**Current recommendation:** Do **not** commit to a permanently visible toolbar. Provide a small platform-appropriate input-method menu and keyboard shortcuts. Evaluate a compact Symbols palette with actual Tibetologists before deciding whether a floating control is warranted.

Dictionary-based next-syllable prediction is **out of scope**: reported correct predictions are only **20–45%**. This result concerns the tested prediction approach; it does not establish that all explicit abbreviation expansion or curated completion would fail. Neither is currently a roadmap commitment.

## 2. Audited toolbar controls

| Proposed control | Decision | Rationale | Alternative placement |
|---|---|---|---|
| **EWTS ▾** | **Remove for now; revisit** | EWTS is currently the only supported Tibetan input scheme; a dropdown promises nonexistent alternatives. Becomes a scheme selector if decision 0004 is implemented. | Plain status label, if useful. |
| **Latin escape** | **Implement; shortcut first** | Scholars frequently alternate Tibetan and Latin text. Conversion needs a predictable temporary bypass. | Shortcut plus visible state in the system input-method menu; optional transient indicator. |
| **Sanskrit** | **Remove as standalone control** | EWTS already expresses Sanskrit characters and stacks; a separate mode is not justified without concrete conflicting parsing requirements. | Sanskrit characters/signs within Symbols. |
| **Inspect** | **Remove from toolbar** | IMEs cannot reliably read arbitrary selected text across applications/platforms; inspection is usually occasional. | Composition diagnostics in menu; pasted-text inspector in playground/companion tool. |
| **Settings ⚙** | **No permanent button required** | Preferences are infrequently changed. | Platform input-method menu. |
| **Symbols ༄** | **Provisional** | A discoverable palette may help with uncommon punctuation, signs, and Sanskrit extensions. Frequency of use remains unproven. | Menu command and shortcut initially; consider toolbar only after testing. |
| **T-Time logo** | **Branding, not a functional control** | A logo cannot itself justify persistent UI. | System input-source/menu icon; About screen; website. |

**Default visible interface:** Prefer none beyond the operating system's normal input-source indicator. If a floating toolbar is later validated, it should be optional and compact.

## 3. Input methods and Latin escape

### 3.1 EWTS is the default Tibetan mode

> **Superseded in part by [decision 0004](decisions/0004-additional-input-layouts.md)** (proposed): Sambhota Keymap One, TCC Keyboards #1/#2 and Monlam Bod-yig are to be offered as additional schemes once their key tables are verified. The first two bullets below record the earlier position.

- No alternative Wylie mapping until a concrete compatibility requirement emerges.
- No direct Tibetan layout without evidence that maintaining one would benefit users over existing OS layouts.
- No pronunciation/dialect-based input in the initial roadmap; that would be a separate linguistic project.
- Do not imply that Classical/Modern profiles exist when dictionary prediction is not supported.

### 3.2 Latin escape: required behaviour to specify and test

**Goal:** Allow ordinary Latin typing without repeatedly changing OS input sources.

Proposed first implementation: a **persistent Tibetan ↔ Latin passthrough toggle** with a configurable, conflict-checked shortcut. While passthrough is active, T-Time must not interpret EWTS sequences. A visible state indication should prevent users from wondering why conversion has stopped.

**Design decisions still open:**

1. Exact default shortcut on macOS, Windows, and Linux; check collisions with host applications and OS shortcuts.
2. Whether switching modes commits, cancels, or preserves an unfinished composition; choose a documented, lossless rule.
3. Whether the mode persists across focus changes, application switches, and restarts.
4. Whether a one-shot bypass is needed in addition to persistent mode; do not implement without user evidence.
5. Whether OS input-source switching already serves users adequately on each platform.

**Acceptance tests:** Latin text passes through unchanged; Tibetan input resumes correctly; shortcut does not insert stray characters; unfinished composition is handled predictably; mode state is discoverable; no text loss during application switching.

## 4. Symbols palette: the only provisional toolbar candidate

### Initial categories

- Tibetan punctuation and marks (e.g., shad, nyis shad, yig mgo, gter tsheg).
- Less-common Tibetan letters and signs.
- Sanskrit-related Tibetan-script letters, vowel signs, and combining marks.
- Scholarly/editorial symbols **only where a real user need and appropriate encoding have been established**.

### Required interaction

- Search/browse by name, visual glyph, and Unicode code point.
- Show the Unicode name and code point; show an EWTS sequence **only when verified** against T-Time's converter.
- Insert through the active IME where technically supported; offer Copy as a fallback.
- Provide keyboard navigation and accessible labels.
- Distinguish a complete insertable sequence from an isolated combining mark.
- Do not imply all glyphs render correctly in all application fonts.

### Optional follow-on: visual stack composer

Investigate a component-based Tibetan-script stack composer **only if users struggle to construct uncommon stacks**. It should preview the sequence, validate Unicode structure, and provide insertion/copying. Do not build a standalone Sanskrit mode.

### Validation threshold

Before assigning a permanent toolbar button, observe users completing real transcription tasks. Record frequency of palette invocation, whether a shortcut/menu is sufficient, time saved, and which signs cannot already be entered comfortably using EWTS.

## 5. Inspector and diagnostics: useful, but not a toolbar control

**Level A — composition diagnostics:** Display current or last committed EWTS input, resulting Tibetan, Unicode code points, normalization, and engine warnings. Accessible through the T-Time menu, primarily for troubleshooting and bug reports.

**Level B — full text inspector:** A pasted-text tool in the browser playground or companion application. Support code-point inspection, reverse EWTS, normalization comparisons, suspicious sequence detection, and copyable diagnostic reports.

**Selected-text inspection:** Deferred. macOS text-input APIs, Windows TSF, and Linux IBus/Fcitx differ in how reliably surrounding or selected text is available. Test host-specific access before promising it in Word, LibreOffice, or browsers.

## 6. Preferences: minimal specification

Prefer a **small preferences window** rather than an elaborate settings application. Expose only settings backed by implemented behaviour.

### 6.1 Typing

| Preference | Initial policy | Notes |
|---|---|---|
| Latin escape shortcut | **Include** | Platform-appropriate default, configurable if feasible. |
| Latin/Tibetan state | **Include as status, not necessarily a preference** | Make mode visible and predictable. |
| Commit-key behaviour | **Defer** | Add only if real users need a choice. |
| Space-bar behaviour | **Investigate** | Specify current semantics and test before adding alternatives. |
| Punctuation mappings | **Document defaults** | Allow customization only where needed; avoid silent automatic substitutions. |
| Shortcut reference | **Include** | Can be Help/menu rather than a settings control. |

### 6.2 Appearance

| Preference | Initial policy | Notes |
|---|---|---|
| Theme | Follow system; optional override | Applies to T-Time's own windows/palettes, not host-document formatting. |
| Floating toolbar visibility | Only if toolbar is implemented | Default should not assume a floating toolbar exists. |
| Interface language | Defer until translations exist | No empty language selector. |
| Tibetan font | Only for T-Time-owned UI | An IME generally cannot set the font used by the host application. |

### 6.3 Advanced / Unicode

| Preference or action | Initial policy | Notes |
|---|---|---|
| Output normalization | Standard NFC by default | Confirm exact current converter behaviour and test cases. |
| Alternative precomposed output | Advanced, off by default | Explain precisely which output sequences change and compatibility trade-offs. |
| Composition diagnostics | Menu action | Not a permanently enabled debugging overlay. |
| Build/version information | About/diagnostics | Include core and adapter versions for reproducible reports. |

### 6.4 Symbols preferences

Favorites, recents, and optional custom symbol shortcuts—**if implemented**—belong within the palette rather than a global preferences page.

## 7. Explicit non-goals

Do not add settings or toolbar controls for:

- Dictionary next-syllable prediction or candidate-ranking sensitivity.
- Classical/Modern predictive vocabulary profiles.
- Sanskrit mode without demonstrated different parsing semantics.
- Automatic spelling correction that changes scholarly text without consent.
- Font selection purporting to change Word/LibreOffice/browser document fonts.
- Arbitrary document selection inspection without tested platform support.
- Extensive toolbar customization, animations, or a plugin marketplace.

## 8. Implementation phases

### Phase 0 — Behaviour inventory

Document existing EWTS composition, commit, Space, punctuation, and normalization behaviour; verify against tests. Identify platform-specific menu and shortcut capabilities.

**Deliverable:** Baseline behaviour specification and regression tests.

### Phase 1 — Latin escape

Implement passthrough, shortcut handling, state indication, and composition-transition rules. Test across supported applications and platforms.

**Deliverable:** Reliable Tibetan/Latin switching without loss of text.

### Phase 2 — Minimal preferences and system menu

Provide shortcut configuration/reference, theme selection for owned UI, advanced Unicode policy, About/build information, and access to diagnostics. Do not add speculative options.

**Deliverable:** Small, comprehensible settings surface; no mandatory floating toolbar.

### Phase 3 — Symbols prototype

Build a compact palette with verified Unicode metadata, Tibetan punctuation, and Sanskrit-related signs; insertion and copy; keyboard access. Collect task-based feedback.

**Deliverable:** Working palette and evidence on whether it needs permanent visibility.

### Phase 4 — Inspector in playground

Expand pasted-text diagnostics and code-point reporting; keep it separate from ordinary typing.

**Deliverable:** Useful Unicode troubleshooting tool without IME toolbar clutter.

### Phase 5 — Reassess toolbar

Based on observed use, choose one:

1. **No floating toolbar** (preferred default absent contrary evidence).
2. **Optional compact launcher** for Symbols and menu access.
3. **Persistent toolbar** only if multiple high-frequency, distinct actions are demonstrated.

Record evidence and rationale before implementing option 3.

## 9. Questions for the Tibetologist

1. How often do you switch between Tibetan and Latin while composing one document?
2. What shortcut or workflow do you use today to switch input modes?
3. Which Tibetan or Sanskrit-script characters do you repeatedly have to look up or copy?
4. Are uncommon stacks difficult to **type**, to **remember**, or to **render correctly**?
5. Do you ever need to inspect Unicode sequences, or only when something breaks?
6. Would a visible floating toolbar help, or would it obstruct your document?
7. Which current EWTS composition/editing behaviours cause mistakes or interruptions?

Observe actual tasks, not only stated preferences.

## 10. Decision log and next actions

### Accepted direction

- Keep EWTS deterministic and central.
- Implement a Latin escape mechanism.
- Remove EWTS, Sanskrit, Inspect, and Settings as **dedicated permanent toolbar controls**.
- Retain Sanskrit character access **inside Symbols**.
- Keep composition diagnostics accessible through a menu and full inspection in the playground.
- Treat Symbols as **provisional**, not as a predetermined reason for a toolbar.
- Keep preferences deliberately small.

### Open decisions

- Default Latin escape shortcut and transition semantics.
- Exact normalization/precomposed-output settings and descriptions.
- Which symbols are actually needed, and how frequently.
- Whether a visual stack composer is warranted.
- Whether a floating toolbar is warranted at all.

### Immediate next steps

1. Audit current typing and Unicode behaviour.
2. Specify and implement Latin escape.
3. Add a small native input-method menu and minimal preferences.
4. Prototype the Symbols palette without assuming permanent toolbar placement.
5. Conduct a short task-based evaluation with a Tibetologist.
6. Update this decision record from evidence.

---

**Product rule:** *A feature earns its place in T-Time by making Tibetan writing more accurate, more predictable, or less laborious—not by filling a toolbar.*
