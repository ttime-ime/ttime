# Higher-order syllable n-gram model with stupid backoff, compared on held-out text.
# usage: ngram.py <parquet> <counts.pkl> <ewts_ok.txt> <held-out collection> <out.json>
import pyarrow.parquet as pq, numpy as np, re, pickle, sys, time, json, random
from collections import defaultdict
SRC, PKL, EW, HOLD, OUT = sys.argv[1:6]
t0 = time.time()
def log(*a): print(f"[{time.time()-t0:5.0f}s]", *a, flush=True)
d = pickle.load(open(PKL, "rb")); vocab = d["vocab"]; V = len(vocab); BOS = V; B = V + 1
vmap = {s: i for i, s in enumerate(vocab)}
ewts = [l.rstrip("\n") for l in open(EW, encoding="utf-8")]
E = {i: e for i, e in enumerate(ewts) if e}
SEG = re.compile(r"[^ཀ-ྼ་]+")
# ---- training tokens ----
parts = []
f = pq.ParquetFile(SRC)
for batch in f.iter_batches(batch_size=16, columns=["collection", "text"]):
    for coll, text in zip(batch["collection"].to_pylist(), batch["text"].to_pylist()):
        if coll == HOLD: continue
        out = []
        for seg in SEG.split(text):
            syl = [s for s in seg.split("་") if s]
            if syl:
                out.append(BOS); out.extend(vmap.get(s, BOS) for s in syl)
        if out: parts.append(np.array(out, dtype=np.int32))
tok = np.concatenate(parts); del parts
log("tokens", len(tok))
# ---- n-gram tables ----
NB = 8
def table(n, minc):
    """keys (sorted) and counts of every n-gram window with BOS only in first position."""
    ks, cs = [], []
    last = len(tok) - n + 1
    for b in range(NB):
        sel = []
        for a in range(0, last, 20_000_000):
            z = min(a + 20_000_000, last)
            ok = np.ones(z - a, dtype=bool)
            key = np.zeros(z - a, dtype=np.int64)
            for j in range(n):
                w = tok[a + j: z + j]
                if j >= 1: ok &= (w != BOS)
                key = key * B + w
            key = key[ok]
            sel.append(key[key % NB == b])
        sub = np.concatenate(sel); del sel
        u, c = np.unique(sub, return_counts=True); del sub
        m = c >= minc
        ks.append(u[m]); cs.append(c[m].astype(np.int32))
    keys = np.concatenate(ks); counts = np.concatenate(cs)
    o = np.argsort(keys); keys, counts = keys[o], counts[o]
    log(f"order {n}: {len(keys):,} n-grams with count >= {minc}")
    return keys, counts
T = {1: (np.arange(V + 1, dtype=np.int64), np.bincount(tok, minlength=V + 1).astype(np.int32))}
T[2] = table(2, 2); T[3] = table(3, 2); T[4] = table(4, 3)
del tok
# successor lists per context: top 100 by count
TOPN = 100
S = {}
for n in (2, 3, 4):
    keys, counts = T[n]
    ctx = keys // B; nxt = (keys % B).astype(np.int32)
    o = np.lexsort((-counts, ctx)); ctx, nxt, cnt = ctx[o], nxt[o], counts[o]
    uc, first = np.unique(ctx, return_index=True)
    rank = np.arange(len(ctx)) - np.repeat(first, np.diff(np.append(first, len(ctx))))
    m = rank < TOPN
    ctx, nxt, cnt = ctx[m], nxt[m], cnt[m]
    uc, first = np.unique(ctx, return_index=True)
    S[n] = (uc, np.append(first, len(ctx)), nxt, cnt)
    log(f"order {n}: {len(uc):,} contexts kept")
def total(n_ctx, ctxkey):
    keys, counts = T[n_ctx] if n_ctx in T else (None, None)
    i = np.searchsorted(keys, ctxkey)
    return int(counts[i]) if i < len(keys) and keys[i] == ctxkey else 0
def succ(n, ctxkey):
    uc, st, nxt, cnt = S[n]
    i = np.searchsorted(uc, ctxkey)
    if i < len(uc) and uc[i] == ctxkey:
        return nxt[st[i]:st[i + 1]], cnt[st[i]:st[i + 1]]
    return (), ()
# ---- evaluation ----
K = 5; ALPHA = 0.4
uni_n = T[1][1]; uni_total = int(uni_n[:V].sum())
byuni = sorted(E, key=lambda i: -uni_n[i]); pref = defaultdict(list)
for i in byuni:
    e = E[i]
    for k in range(len(e) + 1):
        if len(pref[e[:k]]) < K: pref[e[:k]].append(i)
def candidates(hist, maxn):
    """scored candidates (id -> score) from orders maxn..2, hist = ids so far incl. leading BOS."""
    sc = {}
    for n in range(maxn, 1, -1):
        if len(hist) < n - 1: continue
        ctx = hist[-(n - 1):]
        key = 0
        for x in ctx: key = key * B + int(x)
        nx, ct = succ(n, key)
        if len(nx) == 0: continue
        tot = total(n - 1, key)
        if tot <= 0: continue
        w = ALPHA ** (maxn - n)
        for s, c in zip(nx, ct):
            v = w * c / tot
            if v > sc.get(int(s), 0): sc[int(s)] = v
    return sc
def top(sc, p, maxn):
    c = [(v, s) for s, v in sc.items() if s in E and E[s].startswith(p)]
    c.sort(reverse=True)
    out = [s for _, s in c[:K]]
    if len(out) < K:
        for s in pref.get(p, ()):
            if s not in out:
                out.append(s)
                if len(out) == K: break
    return out
test = d["test"]; random.seed(2); random.shuffle(test)
NPOS = 60000
results = {}
for maxn, label in ((1, "frequency only"), (2, "bigram (previous syllable)"), (3, "trigram"), (4, "4-gram")):
    n_pos = oov = top1 = topk = chars = saved = toks = 0
    for seg in test:
        hist = [BOS]
        for s in seg:
            toks += 1
            i = vmap.get(s)
            if i is None or i not in E:
                oov += 1; hist = [BOS]; continue
            n_pos += 1
            e = E[i]; L = len(e)
            sc = candidates(hist, maxn) if maxn >= 2 else {}
            c0 = top(sc, "", maxn)
            top1 += bool(c0) and c0[0] == i; topk += i in c0
            cost = L
            for k in range(L + 1):
                if i in top(sc, e[:k], maxn):
                    cost = min(L, k + 1) if k < L else L; break
            chars += L; saved += L - cost
            hist.append(i)
        if n_pos >= NPOS: break
    results[label] = dict(tokens=toks, oov_rate=oov / toks, next_top1=top1 / n_pos, next_top5=topk / n_pos,
                          keystrokes_saved=saved / chars, evaluated_syllables=n_pos)
    log(label, json.dumps(results[label]))
json.dump(dict(held_out=HOLD, train_tokens=int(uni_total), vocab=len(E), orders=results), open(OUT, "w"), indent=2, ensure_ascii=False)
log("done")
