#!/usr/bin/env python3
"""Run the Keyman "Tibetan EWTS" keyboard's rules against T-Time.

Keyman Core is not available here, so this is a small interpreter for the
subset of the .kmn language that this keyboard actually uses: rules of the
form  [context] + key > output  with string literals, any(store) and
index(store, n). Rules are tried in file order; the first match wins and the
matched context is replaced by the output. An unmatched key is inserted.

Usage:
    python3 -I scripts/differential/keyman_diff.py KMN_FILE CLI_BINARY < words.txt

Each stdin line is EWTS; a trailing space is appended so Keyman flushes the
final syllable, and T-Time sees the same input. Prints every difference.
This is evidence, not authority: the interpreter covers only what the
keyboard uses, and Keyman converts at vowels and spaces while T-Time converts
a whole string, so partial-input behaviour is not compared.
"""
import re
import subprocess
import sys

TOKEN = re.compile(
    r'''"[^"]*"|'[^']*'|any\(\w+\)|index\(\w+\s*,\s*\d+\)|U\+[0-9A-Fa-f]+|\[[^\]]*\]|nul|\+|>|\w+\(\w+\)''')


def unquote(tok):
    return tok[1:-1]


def parse_store(line):
    m = re.match(r"store\((&?\w+)\)\s*(.*)", line)
    name, rest = m.group(1), m.group(2)
    value = ""
    for t in re.findall(r'"[^"]*"|\'[^\']*\'|U\+[0-9A-Fa-f]+', rest):
        value += chr(int(t[2:], 16)) if t.startswith("U+") else t[1:-1]
    return name, value


def load(path):
    stores, rules = {}, []
    for raw in open(path, encoding="utf8"):
        line = raw.strip()
        if not line or line.startswith("c ") or line == "c":
            continue
        if line.startswith("store("):
            name, value = parse_store(line)
            if not name.startswith("&"):  # &NAME etc. are keyboard metadata
                stores[name] = value
            continue
        if line.startswith(("group(", "begin ")) or ">" not in line or "+" not in line:
            continue
        toks = TOKEN.findall(line)
        if "+" not in toks or ">" not in toks:
            continue
        plus, gt = toks.index("+"), toks.index(">")
        ctx, key, out = toks[:plus], toks[plus + 1:gt], toks[gt + 1:]
        if len(key) != 1 or not key[0].startswith('"') or '"' in unquote(key[0]):
            continue  # virtual keys and the Backspace help rules
        rules.append((ctx, unquote(key[0]), out))
    return stores, rules


def compile_rules(stores, rules):
    by_key = {}
    for ctx, key, out in rules:
        items, pos = [], 0
        for t in ctx:
            if t.startswith("any("):
                items.append(("any", stores[t[4:-1]], pos))
                pos += 1
            else:
                s = unquote(t)
                items.append(("str", s, pos))
                pos += len(s)
        outs = []
        for t in out:
            if t == "nul":
                continue
            if t.startswith("index("):
                name, n = re.match(r"index\((\w+)\s*,\s*(\d+)\)", t).groups()
                outs.append(("index", int(n) - 1))
            elif t.startswith("any("):
                outs.append(("index", None))
            else:
                outs.append(("str", unquote(t)))
        by_key.setdefault(key, []).append((items, pos, outs))
    return by_key


def type_keys(compiled, text):
    buf = ""
    for ch in text:
        for items, length, outs in compiled.get(ch, []):
            if length > len(buf):
                continue
            window = buf[len(buf) - length:] if length else ""
            matched, picks = True, {}
            for kind, val, pos in items:
                if kind == "str":
                    if window[pos:pos + len(val)] != val:
                        matched = False
                        break
                else:
                    idx = val.find(window[pos]) if pos < len(window) else -1
                    if idx < 0:
                        matched = False
                        break
                    picks[pos] = (val, idx)
            if not matched:
                continue
            produced = ""
            for o in outs:
                if o[0] == "str":
                    produced += o[1]
                else:
                    ref = picks[o[1]] if o[1] is not None else next(iter(picks.values()))
                    produced += ref[0][ref[1]]
            buf = buf[:len(buf) - length] + produced
            break
        else:
            buf += ch
    return buf


def main():
    kmn, cli = sys.argv[1], sys.argv[2]
    stores, rules = load(kmn)
    compiled = compile_rules(stores, rules)
    words = [l.rstrip("\n") for l in sys.stdin if l.strip()]
    ours = subprocess.run([cli], input="\n".join(w + " " for w in words) + "\n",
                          capture_output=True, text=True).stdout.split("\n")
    esc = lambda s: " ".join(f"{ord(c):04X}" for c in s)
    same = 0
    for w, o in zip(words, ours):
        k = type_keys(compiled, w + " ")
        if k == o:
            same += 1
        else:
            print(f"{w!r}\n    keyman  {esc(k)}\n    t-time  {esc(o)}")
    print(f"{len(rules)} rules loaded; {same} of {len(words)} inputs identical", file=sys.stderr)


main()
