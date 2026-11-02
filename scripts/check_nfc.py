#!/usr/bin/env python3
"""Check converter output against Python's own Unicode normaliser.

Default output must already be in NFC. Precomposed output must normalise (NFC)
back to the default output. Inputs are random, structurally plausible
syllables: a consonant run, an optional vowel, suffixes and an optional mark.

Usage: python3 -I scripts/check_nfc.py [count]
"""
import pathlib
import random
import subprocess
import sys
import unicodedata

ROOT = pathlib.Path(__file__).resolve().parent.parent
CONS = ["k", "kh", "g", "ng", "c", "ch", "j", "ny", "t", "th", "d", "n", "p", "ph", "b",
        "m", "ts", "tsh", "dz", "w", "zh", "z", "'", "y", "r", "l", "sh", "s", "h",
        "T", "D", "N", "gh", "dh", "bh", "f", "v"]
VOWELS = ["a", "i", "u", "e", "o", "A", "I", "U", "ai", "au", "-i", "-I", "uo", "ui", "ue"]
MARKS = ["M", "H", "~M", "~M`", "X", "^", "?"]


def syllable(rng):
    s = "".join(rng.choice(CONS) for _ in range(rng.randint(1, 4)))
    if rng.random() < 0.3:
        s = "+".join(rng.choice(CONS) for _ in range(rng.randint(2, 3)))
    s += rng.choice(VOWELS)
    s += "".join(rng.choice(CONS) for _ in range(rng.randint(0, 2)))
    if rng.random() < 0.15:
        s += rng.choice(MARKS)
    return s


def convert(lines, *flags):
    proc = subprocess.run(
        ["cargo", "run", "-q", "-p", "ttime-cli", "--", *flags],
        input="\n".join(lines) + "\n", capture_output=True, text=True, cwd=ROOT, check=True,
    )
    return proc.stdout.split("\n")[:-1]


def main():
    count = int(sys.argv[1]) if len(sys.argv) > 1 else 20000
    rng = random.Random(2026)
    lines = [syllable(rng) for _ in range(count)]
    default = convert(lines)
    precomposed = convert(lines, "--precomposed")
    bad = 0
    for src, d, p in zip(lines, default, precomposed):
        problems = []
        if unicodedata.normalize("NFC", d) != d:
            problems.append("default output is not NFC")
        if unicodedata.normalize("NFC", p) != d:
            problems.append("precomposed output does not normalise to default")
        if problems:
            bad += 1
            if bad <= 15:
                print(f"{src!r}: {'; '.join(problems)}")
                print("   default    ", " ".join(f"{ord(c):04X}" for c in d))
                print("   precomposed", " ".join(f"{ord(c):04X}" for c in p))
    print(f"{count} inputs, {bad} problems")
    sys.exit(1 if bad else 0)


main()
