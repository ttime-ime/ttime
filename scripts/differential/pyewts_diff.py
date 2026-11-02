#!/usr/bin/env python3
"""Compare T-Time with pyewts on every curated fixture.

Usage (from the repository root, after `cargo build -p ttime-cli`):
    python3 -m venv .venv && .venv/bin/pip install -r scripts/differential/requirements.txt
    .venv/bin/python scripts/differential/pyewts_diff.py

Prints every input where the two disagree. robustness.tsv and deviations.tsv
are expected to contain disagreements; the other files should have none except
the documented ones (docs/specification/ewts.md, section 12). pyewts is an
oracle for comparison, not an authority.
"""
import glob
import os
import subprocess
import unicodedata

import pyewts

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CLI = os.path.join(ROOT, "target", "debug", "ttime-cli")
conv = pyewts.pyewts()


cases = []
for f in sorted(glob.glob(os.path.join(ROOT, "crates/ttime-core/tests/fixtures/*.tsv"))):
    name = os.path.basename(f)
    if name == "precomposed.tsv":
        continue
    for line in open(f, encoding="utf8"):
        line = line.rstrip("\n")
        if line and not line.startswith("#") and "\t" in line:
            cases.append((name,) + tuple(line.split("\t", 1)))

# One CLI run per case: inputs may contain spaces and escapes.
def ours(text):
    return subprocess.run([CLI], input=text + "\n", capture_output=True, text=True,
                          encoding="utf8").stdout.rstrip("\n")


def theirs(text):
    try:
        return conv.toUnicode(text)
    except Exception as e:  # pyewts raises on some malformed input
        return "<pyewts raised %s>" % type(e).__name__


esc = lambda s: " ".join("%04X" % ord(c) for c in s)
differ = {}
for name, inp, _ in cases:
    o, p = ours(inp), theirs(inp)
    if o != p:
        differ.setdefault(name, 0)
        differ[name] += 1
        same = unicodedata.normalize("NFC", o) == unicodedata.normalize("NFC", p)
        print(f"{name}\t{inp!r}\n    ours {esc(o)}\n    py   {esc(p)}  (NFC-equal: {same})")
print(len(cases), "cases;", "differences by file:", differ or "none")
