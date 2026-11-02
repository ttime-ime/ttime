# Completion spike: how many EWTS keystrokes would a top-5 list save?
import pickle, random, sys, json
from collections import defaultdict
d = pickle.load(open(sys.argv[1], "rb"))
ewts = [l.rstrip("\n") for l in open(sys.argv[2], encoding="utf-8")]
vocab = d["vocab"]; assert len(ewts) == len(vocab), (len(ewts), len(vocab))
E = {s: e for s, e in zip(vocab, ewts) if e}; uni = d["uni"]; big = d["big"]; K = 5
by_uni = sorted(E, key=lambda s: -uni[s])
# prefix -> top-K unigram candidates (precomputed over every prefix of every vocab EWTS)
pref = defaultdict(list)
for s in by_uni:
    e = E[s]
    for k in range(len(e) + 1):
        lst = pref[e[:k]]
        if len(lst) < K: lst.append(s)
def cands(prev, p, use_ctx):
    out = []
    if use_ctx and prev in big:
        for s, _ in sorted(big[prev].items(), key=lambda kv: -kv[1]):
            if s in E and E[s].startswith(p):
                out.append(s)
                if len(out) == K: return out
    for s in pref.get(p, ()):
        if s not in out:
            out.append(s)
            if len(out) == K: break
    return out
test = d["test"]; random.seed(2); random.shuffle(test)
res = {}
for name, ctx in (("no context (frequency only)", False), ("previous syllable as context", True)):
    toks = oov = top1 = topk = 0; chars = saved = 0; n_pos = 0
    for seg in test:
        prev = None
        for s in seg:
            toks += 1
            if s not in E:
                oov += 1; prev = None; continue
            n_pos += 1
            e = E[s]; L = len(e)
            c0 = cands(prev, "", ctx)
            top1 += bool(c0) and c0[0] == s
            topk += s in c0
            cost = L
            for k in range(L + 1):
                if s in cands(prev, e[:k], ctx):
                    cost = min(L, k + 1) if k < L else L
                    break
            chars += L; saved += L - cost
            prev = s
        if toks >= 300000: break
    res[name] = dict(tokens=toks, oov_rate=oov / toks, next_top1=top1 / n_pos, next_top5=topk / n_pos,
                     keystrokes_saved=saved / chars, evaluated_syllables=n_pos)
print(json.dumps(dict(
    train_syllables=d["n_train"], unique_train_syllables=d["unique_train"], vocab=len(E),
    test_files=d["test_files"], test_syllables_total=d["test_syllables"], results=res), indent=2, ensure_ascii=False))
