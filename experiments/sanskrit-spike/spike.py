"""Sanskrit IAST completion spike. Reads Monier-Williams (Cologne, SLP1) from the path
given as argv[1]; writes nothing but prints the measurements used in
docs/reference/sanskrit-spike.md. The dictionary itself is never stored in the repo."""
import re, sys, unicodedata, collections, statistics

SLP1 = {'a':'a','A':'ā','i':'i','I':'ī','u':'u','U':'ū','f':'ṛ','F':'ṝ','x':'ḷ','X':'ḹ',
        'e':'e','E':'ai','o':'o','O':'au','M':'ṃ','H':'ḥ','k':'k','K':'kh','g':'g','G':'gh',
        'N':'ṅ','c':'c','C':'ch','j':'j','J':'jh','Y':'ñ','w':'ṭ','W':'ṭh','q':'ḍ','Q':'ḍh',
        'R':'ṇ','t':'t','T':'th','d':'d','D':'dh','n':'n','p':'p','P':'ph','b':'b','B':'bh',
        'm':'m','y':'y','r':'r','l':'l','v':'v','S':'ś','z':'ṣ','s':'s','h':'h','L':'ḻ',
        '~':'̐',"'":"’"}

def iast(slp):
    return unicodedata.normalize('NFC', ''.join(SLP1.get(c, '?') for c in slp))

def fold(s):
    """What a user types without diacritics: strip marks (ā->a, ś->s, ṃ->m, ñ->n)."""
    d = unicodedata.normalize('NFD', s)
    return ''.join(c for c in d if not unicodedata.combining(c)).replace('’', '').lower()

entry = re.compile(r'<L>([^<]+)<pc>[^<]*<k1>([^<]+)<k2>[^<]*(?:<h>[^<]*)?<e>[^\n]*\n(.*?)<LEND>', re.S)
text = open(sys.argv[1], encoding='utf-8').read()
heads = collections.OrderedDict()   # slp1 -> buddhist flag
bad = 0
for m in entry.finditer(text):
    k1, body = m.group(2), m.group(3)
    if not re.fullmatch(r"[aAiIuUfFxXeEoOMHkKgGNcCjJYwWqQRtTdDnpPbBmyrlvSzshL~']+", k1):
        bad += 1; continue
    b = 'Buddh.' in body
    heads[k1] = heads.get(k1, False) or b
print(f"entries parsed: {len(heads):,} distinct headwords ({bad} skipped, odd characters)")
buddh = sum(heads.values())
print(f"headwords with a Buddh. label in some entry: {buddh:,}")

words = {iast(k): b for k, b in heads.items()}
print(f"distinct IAST words: {len(words):,}")
keys = collections.defaultdict(list)
for w in words: keys[fold(w)].append(w)
print(f"distinct diacritic-free keys: {len(keys):,}; keys with >1 spelling: {sum(len(v)>1 for v in keys.values()):,} "
      f"({100*sum(len(v)>1 for v in keys.values())/len(keys):.1f}%)")
print("examples of collisions:", [keys[k] for k in ('siva','sunya','prajna','sutra') if k in keys])
L = [len(w) for w in words]
print(f"headword length: median {statistics.median(L)}, 90th pct {sorted(L)[int(.9*len(L))]}, max {max(L)}")

terms = """prajñā śūnyatā bodhisattva tathāgata saṃsāra pratītyasamutpāda āryāṣṭāṅgamārga
nirvāṇa dharma karuṇā bodhicitta abhidharma madhyamaka vijñāna skandha dhātu āyatana
anātman anitya duḥkha upāya pāramitā śrāvaka pratyekabuddha mahāyāna vajrayāna tantra
maṇḍala mantra dhāraṇī sūtra vinaya prātimokṣa śamatha vipaśyanā samādhi dhyāna
tathatā dharmakāya nirmāṇakāya sambhogakāya tathāgatagarbha ālayavijñāna svabhāva
niḥsvabhāva catuṣkoṭi trisvabhāva abhisamaya lokeśvara avalokiteśvara mañjuśrī
sukhāvatī vajra cakravartin arhat bhikṣu""".split()
def lookup(t):
    n = unicodedata.normalize('NFC', t)
    return n in words
found = [t for t in terms if lookup(t)]
miss = [t for t in terms if not lookup(t)]
print(f"sample of {len(terms)} Buddhist terms: {len(found)} are headwords as spelled")
print("not headwords:", ' '.join(miss))
# Prefix matches for the misses: is the term a prefix of a longer headword, or built from headwords?
for t in miss:
    pre = [w for w in words if w.startswith(t)][:3]
    print(f"  {t}: longer headwords starting with it: {pre}")

# Typing cost: letters typed (no diacritics) before the entry is in a 5-item list.
def cost(term, rank):
    f = fold(term)
    for n in range(1, len(f)+1):
        pool = [w for k, ws in keys.items() if k.startswith(f[:n]) for w in ws]
        top = sorted(pool, key=rank)[:5]
        if term in top: return n
    return len(f)
rankers = {
  'alphabetical': lambda w: w,
  'shorter first': lambda w: (len(w), w),
  'Buddh.-labelled first, then shorter': lambda w: (not words[w], len(w), w),
}
for name, r in rankers.items():
    tot_t = tot_l = 0
    for t in found:
        c = cost(t, r); tot_t += c; tot_l += len(fold(t))
    print(f"ranking '{name}': typed {tot_t} of {tot_l} letters ({100*(1-tot_t/tot_l):.0f}% saved) over {len(found)} found terms")
print(f"of the found terms, {sum(words[t] for t in found)} carry a Buddh. label")
print("found without label:", ' '.join(t for t in found if not words[t]))
