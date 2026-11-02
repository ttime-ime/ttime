# Differential testing

Evidence, not authority. Neither oracle is the EWTS standard.

- `pyewts_diff.py` — all fixtures against pyewts 1.0.0 (`requirements.txt`).
- `keyman_diff.py` — a small interpreter for the Keyman `tibetan_ewts` `.kmn`
  rules (MIT). The `.kmn` file is not vendored. Pinned source: keymanapp/keyboards
  `release/t/tibetan_ewts/source/tibetan_ewts.kmn` at commit
  `8072bb2a4a9a4762930ab2482eb31326717d2226` (2024-05-17), keyboard version 2.4,
  153,536 bytes; byte-identical to the copy used for every result in the spec.
  Fetch it with `gh api -H 'Accept: application/vnd.github.raw' 'repos/keymanapp/keyboards/contents/release/t/tibetan_ewts/source/tibetan_ewts.kmn?ref=<commit>'`.
  The interpreter is incomplete (see its docstring).
- m17n `bo-ewts.mim` (LGPL) was compared by hand on its stack inventory only;
  no script is committed and nothing was copied.

Results and classified differences: `docs/specification/ewts.md`, section 12.
- `ewts-rs-diff/` — Rust crate comparing all fixtures with `ewts` 0.1.4
  (pinned). Run `cargo run --release` inside it; it has its own workspace.
