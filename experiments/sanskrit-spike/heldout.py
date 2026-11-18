"""Held-out test: rank with counts from the other texts, then 'type' every word of the
held-out text. usage: heldout.py mw.txt bhs.txt <dcs folder>. Each fold holds out one
text (the three Abhidharma files together); counts and extra lemmas come only from the
rest. The target of each token is its lemma, as the dictionary spells it."""
import re, sys, glob, os, unicodedata, collections, heapq

SLP1 = {'a':'a','A':'ā','i':'i','I':'ī','u':'u','U':'ū','f':'ṛ','F':'ṝ','x':'ḷ','X':'ḹ','e':'e','E':'ai','o':'o','O':'au','M':'ṃ','H':'ḥ','k':'k','K':'kh','g':'g','G':'gh','N':'ṅ','c':'c','C':'ch','j':'j','J':'jh','Y':'ñ','w':'ṭ','W':'ṭh','q':'ḍ','Q':'ḍh','R':'ṇ','t':'t','T':'th','d':'d','D':'dh','n':'n','p':'p','P':'ph','b':'b','B':'bh','m':'m','y':'y','r':'r','l':'l','v':'v','S':'ś','z':'ṣ','s':'s','h':'h','L':'ḻ','~':'̐',"'":"’"}
iast = lambda s: unicodedata.normalize('NFC', ''.join(SLP1.get(c, '?') for c in s))
def fold(s):
    return ''.join(c for c in unicodedata.normalize('NFD', s) if not unicodedata.combining(c)).replace('’', '').lower()

entry = re.compile(r'<L>([^<]+)<pc>[^<]*<k1>([^<]+)<k2>[^\n]*\n(.*?)<LEND>', re.S)
ok = re.compile(r"[aAiIuUfFxXeEoOMHkKgGNcCjJYwWqQRtTdDnpPbBmyrlvSzshL~']+")
dict_words = {}  # word -> buddhist label
for i, path in enumerate(sys.argv[1:3]):
    for m in entry.finditer(open(path, encoding='utf-8').read()):
        if ok.fullmatch(m.group(2)):
            w = iast(m.group(2))
            dict_words[w] = dict_words.get(w, False) or i == 1 or 'Buddh.' in m.group(3)

texts = collections.defaultdict(collections.Counter)   # text -> lemma counts
for f in glob.glob(os.path.join(sys.argv[3], 'files', '*', '*.conllu')):
    t = f.split(os.sep)[-2]
    t = 'Abhidharma (3 files)' if t.startswith('Abhidharma') else t
    for line in open(f, encoding='utf-8'):
        if not line[:1].isdigit(): continue
        c = line.rstrip('\n').split('\t')
        if len(c) < 10 or '-' in c[0] or c[3] in ('PUNCT', '_') or c[2] in ('_', ''): continue
        texts[t][unicodedata.normalize('NFC', c[2])] += 1

def run(held):
    train = collections.Counter()
    for t, c in texts.items():
        if t != held: train.update(c)
    pool = dict(dict_words)
    for l in train: pool.setdefault(l, False)
    by_prefix = collections.defaultdict(list)
    for w in pool:
        f = fold(w)
        for n in range(1, len(f) + 1): by_prefix[f[:n]].append(w)
    rankers = {
        'alphabetical': lambda w: w,
        'shorter first': lambda w: (len(w), w),
        'Buddhist label, then shorter': lambda w: (not pool[w], len(w), w),
        'counts from other texts': lambda w: (-train[w], len(w), w),
    }
    cache = {}
    def cost(w, name):
        f = fold(w)
        for n in range(1, len(f) + 1):
            key = (f[:n], name)
            if key not in cache: cache[key] = heapq.nsmallest(5, by_prefix.get(f[:n], []), key=rankers[name])
            if w in cache[key]: return n
        return len(f)
    out = {}
    minlen = int(os.environ.get("MINLEN", "0"))
    tokens = collections.Counter({w: k for w, k in texts[held].items() if len(fold(w)) >= minlen})
    typed = {n: 0 for n in rankers}; letters = 0; unseen = 0; seen_tok = 0
    for w, k in tokens.items():
        letters += k * len(fold(w))
        if w not in pool: unseen += k
        if train[w] > 0: seen_tok += k
        for n in rankers: typed[n] += k * cost(w, n)
    total = sum(tokens.values())
    return total, letters, unseen, seen_tok, typed

tot = collections.Counter(); names = None
print(f"{'held-out text':28} {'words':>7} {'not in pool':>11} {'seen in train':>13}   saved: alpha / short / label / counts")
for held in sorted(texts, key=lambda t: -sum(texts[t].values())):
    total, letters, unseen, seen, typed = run(held)
    names = list(typed)
    save = [100 * (1 - typed[n] / letters) for n in names]
    print(f"{held:28} {total:7,} {100*unseen/total:10.1f}% {100*seen/total:12.1f}%   " + " / ".join(f"{s:4.1f}%" for s in save))
    tot['total'] += total; tot['letters'] += letters; tot['unseen'] += unseen; tot['seen'] += seen
    for n in names: tot[n] += typed[n]
print(f"{'ALL (token-weighted)':28} {tot['total']:7,} {100*tot['unseen']/tot['total']:10.1f}% {100*tot['seen']/tot['total']:12.1f}%   "
      + " / ".join(f"{100*(1-tot[n]/tot['letters']):4.1f}%" for n in names))
