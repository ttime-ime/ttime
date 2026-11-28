#!/usr/bin/env python3
"""Builds data/sanskrit/iast-lexicon.tsv, the word list behind T-Time's Sanskrit (IAST)
suggestions: word <TAB> count <TAB> flag.

usage: build-sanskrit-lexicon.py mw.txt bhs.txt <dcs conllu folder> [out.tsv]

  mw.txt, bhs.txt  Monier-Williams and Edgerton (BHS) from the Cologne Digital Sanskrit
                   Lexicon, csl-orig/v02/{mw,bhs}/ (SLP1; headwords only are used)
  dcs folder       DCS CoNLL-U files, <folder>/files/<text>/*.conllu (lemma counts)
  count            occurrences of the lemma in the nine DCS Buddhist texts
  flag             b if the word is an Edgerton headword or Monier-Williams marks it
                   Buddh., else -

No definitions are copied, only the headwords and counts. See data/sanskrit/README.md
for licences. The method is the one measured in docs/reference/sanskrit-spike.md."""
import re, sys, glob, os, unicodedata, collections

SLP1 = {'a':'a','A':'ā','i':'i','I':'ī','u':'u','U':'ū','f':'ṛ','F':'ṝ','x':'ḷ','X':'ḹ','e':'e','E':'ai','o':'o','O':'au','M':'ṃ','H':'ḥ','k':'k','K':'kh','g':'g','G':'gh','N':'ṅ','c':'c','C':'ch','j':'j','J':'jh','Y':'ñ','w':'ṭ','W':'ṭh','q':'ḍ','Q':'ḍh','R':'ṇ','t':'t','T':'th','d':'d','D':'dh','n':'n','p':'p','P':'ph','b':'b','B':'bh','m':'m','y':'y','r':'r','l':'l','v':'v','S':'ś','z':'ṣ','s':'s','h':'h','L':'ḻ'}
iast = lambda s: unicodedata.normalize('NFC', ''.join(SLP1[c] for c in s))
entry = re.compile(r'<L>([^<]+)<pc>[^<]*<k1>([^<]+)<k2>[^\n]*\n(.*?)<LEND>', re.S)
plain = re.compile(r"[aAiIuUfFxXeEoOMHkKgGNcCjJYwWqQRtTdDnpPbBmyrlvSzshL]+")

words = {}
for i, path in enumerate(sys.argv[1:3]):
    for m in entry.finditer(open(path, encoding='utf-8').read()):
        if plain.fullmatch(m.group(2)):
            w = iast(m.group(2))
            words[w] = words.get(w, False) or i == 1 or 'Buddh.' in m.group(3)

counts = collections.Counter()
for f in glob.glob(os.path.join(sys.argv[3], 'files', '*', '*.conllu')):
    for line in open(f, encoding='utf-8'):
        if not line[:1].isdigit(): continue
        c = line.rstrip('\n').split('\t')
        if len(c) < 10 or '-' in c[0] or c[3] in ('PUNCT', '_') or c[2] in ('_', ''): continue
        # A few DCS lemmas carry stray half-width Hangul (U+FFB1, U+FFDE) where a
        # letter was garbled; they are not words, so they are left out.
        if any('\uff00' <= ch <= '\uffef' for ch in c[2]): continue
        counts[unicodedata.normalize('NFC', c[2])] += 1
for lemma in counts: words.setdefault(lemma, False)

def letters(w): return ''.join(c for c in unicodedata.normalize('NFD', w) if not unicodedata.combining(c))
out = sys.argv[4] if len(sys.argv) > 4 else 'data/sanskrit/iast-lexicon.tsv'
rows = sorted((w, counts[w], 'b' if b else '-') for w, b in words.items() if len(letters(w)) >= 3)
with open(out, 'w', encoding='utf-8') as f:
    for w, n, flag in rows: f.write(f"{w}\t{n}\t{flag}\n")
print(f"{len(rows):,} words written to {out}")
