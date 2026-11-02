# Differential testing

Evidence, not authority. Neither oracle is the EWTS standard.

- `pyewts_diff.py` — all fixtures against pyewts 1.0.0 (`requirements.txt`).
- `keyman_diff.py` — a small interpreter for the Keyman `tibetan_ewts` `.kmn`
  rules (MIT). The `.kmn` file is not vendored; fetch it from
  keymanapp/keyboards `release/t/tibetan_ewts` and record the commit you used.
  The interpreter is incomplete (see its docstring).
- m17n `bo-ewts.mim` (LGPL) was compared by hand on its stack inventory only;
  no script is committed and nothing was copied.

Results and classified differences: `docs/specification/ewts.md`, section 12.
