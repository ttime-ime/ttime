"""(accuracy variant) Held-out test: rank with counts from the other texts, then 'type' every word of the
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
    by_key = collections.defaultdict(list)
    for w in pool: by_key[fold(w)].append(w)
    rankers = {
        'alphabetical': lambda w: w,
        'shorter first': lambda w: (len(w), w),
        'Buddhist label': lambda w: (not pool[w], len(w), w),
        'counts': lambda w: (-train[w], len(w), w),
    }
    r = collections.Counter()
    for w, k in texts[held].items():
        cands = by_key.get(fold(w), [])
        amb = len(cands) > 1
        accented = fold(w) != w
        groups = ['all']
        if accented: groups.append('accented')
        if amb: groups.append('ambiguous')
        if amb and accented: groups.append('ambiguous+accented')
        for g in groups:
            r[g, 'n'] += k
            if w in cands:
                for name, rk in rankers.items():
                    order = sorted(cands, key=rk)
                    pos = order.index(w)
                    if pos == 0: r[g, name, 1] += k
                    if pos < 5: r[g, name, 5] += k
            # a word missing from the pool counts as a miss everywhere
    return r

tot = collections.Counter()
for held in texts:
    tot.update(run(held))
names = ['alphabetical', 'shorter first', 'Buddhist label', 'counts']
for g in ['all', 'accented', 'ambiguous', 'ambiguous+accented']:
    n = tot[g, 'n']
    print(f"{g:20} {n:8,} words   top-1 / top-5 correct:  " +
          "   ".join(f"{nm}: {100*tot[g,nm,1]/n:4.1f}/{100*tot[g,nm,5]/n:4.1f}" for nm in names))
