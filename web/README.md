# T-Time Writing Room (prototype)

A static page that runs `ttime-core` in the browser through WebAssembly.
No transliteration rules live in JavaScript; `app.js` handles only events and
presentation.

## Build and run

```sh
rustup target add wasm32-unknown-unknown
cargo install wasm-bindgen-cli --version 0.2.130 --locked   # must equal the pinned crate
scripts/build-web.sh                                         # writes web/pkg and web/fixtures
python3 -m http.server -d web 8000                           # then open http://localhost:8000
```

`web/pkg/` and `web/fixtures/` are generated and not committed. The build script
records the commit (plus `+dirty` if the tree has changes) in the page footer
and in the report text.

## Checks

- `cargo test -p ttime-wasm` — commit policy: converting in committed pieces equals
  converting the whole string (20,000 random inputs, both output modes).
- Open `parity.html`: runs all curated fixtures through the Wasm build; the tab
  title reads `parity: N cases, 0 failed`. Last result: 701 cases, 0 failed
  (Safari/Firefox not yet tried; checked in the Claude desktop app's browser,
  which is Chromium-based).
- Manual typing check done in that browser: typing, backspace across the commit
  boundary, examples, caret in the middle of text, no network requests other
  than the four local files. **Not done:** Safari, Firefox, Windows, Linux, phone
  keyboards, screen readers, other fonts.

## Behaviour and limits

- Typed text is *provisional* (highlighted) until space or Enter, then fixed.
  A space inside `[...]` or after a backslash does not end the run.
- Typing is intercepted only with the caret at the end. Elsewhere, and for
  paste and cut, the browser edits normally and T-Time adopts the result as
  committed text.
- Backspace removes the last typed letter of the provisional run; with none, the
  browser deletes committed text.
- Input methods that use composition events (most phone keyboards) bypass EWTS
  typing; the "EWTS typing" checkbox can turn the interception off.
- Switching "Precomposed output" keeps committed text as is and re-reads only the
  provisional run in the new mode.
- No fonts are bundled. The page lists installed Tibetan fonts; licences of
  candidate fonts (Noto Serif Tibetan, Jomolhari) have not been checked.
- No mascot images yet: the source files are several megabytes and need
  resizing.
- Privacy: no network calls during use. The report is built locally and copied by
  the user. The page is public once deployed; GitHub Pages from a private
  repository needs a paid plan.

## Not yet done

CI (`cargo test`, wasm build, parity check) and deployment; automated browser
tests; cursor-aware editing; the specialist session protocol
(`docs/research/tibetologist-evaluation.md`).
