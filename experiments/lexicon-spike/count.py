# Pass 1/2 over BoCorpus: syllable unigram and bigram counts on a train split,
# and a sample of held-out syllable sequences for evaluation.
import pyarrow.parquet as pq, re, pickle, zlib, random, sys, time
from collections import Counter, defaultdict
SRC = sys.argv[1]; OUT = sys.argv[2]; HOLD = sys.argv[3] if len(sys.argv) > 3 else None
SEG = re.compile(r"[^ཀ-ྼ་]+")      # anything else breaks a segment
def segments(text):
    for seg in SEG.split(text):
        syl = [s for s in seg.split("་") if s]
        if syl: yield syl
def is_test(fn, coll=None):
    if HOLD: return coll == HOLD
    return zlib.crc32(fn.encode()) % 20 == 0
t0 = time.time()
f = pq.ParquetFile(SRC)
uni = Counter(); n_train = 0; test = []; per_coll = Counter(); test_files = 0
# Pass 1: unigrams (train only) to fix the vocabulary.
texts_seen = 0
for batch in f.iter_batches(batch_size=16, columns=["collection","filename","text"]):
    for coll, fn, text in zip(batch["collection"].to_pylist(), batch["filename"].to_pylist(), batch["text"].to_pylist()):
        texts_seen += 1
        if is_test(fn, coll):
            test_files += 1
            for seg in segments(text): test.append(seg)
            continue
        per_coll[coll] += len(text)
        for seg in segments(text):
            uni.update(seg); n_train += len(seg)
    print(f"pass1 {texts_seen} texts, {n_train:,} train syllables, {time.time()-t0:.0f}s", flush=True)
VOCAB_N = 30000
vocab = [s for s,_ in uni.most_common(VOCAB_N)]
vs = set(vocab)
cover = sum(uni[s] for s in vocab) / n_train
print("vocab", len(vocab), "unique train syllables", len(uni), f"train coverage {cover:.4f}", flush=True)
# Pass 2: bigrams within the vocabulary (train only).
big = defaultdict(Counter)
seen = 0
for batch in f.iter_batches(batch_size=16, columns=["collection","filename","text"]):
    for coll, fn, text in zip(batch["collection"].to_pylist(), batch["filename"].to_pylist(), batch["text"].to_pylist()):
        seen += 1
        if is_test(fn, coll): continue
        for seg in segments(text):
            p = None
            for s in seg:
                if p is not None and p in vs and s in vs: big[p][s] += 1
                p = s
    print(f"pass2 {seen} texts, {len(big)} contexts, {time.time()-t0:.0f}s", flush=True)
# Keep the 200 most frequent successors of each context.
big = {p: dict(c.most_common(200)) for p, c in big.items()}
random.seed(1)
random.shuffle(test)
pickle.dump(dict(vocab=vocab, uni={s: uni[s] for s in vocab}, big=big, test=test[:20000], n_train=n_train,
                 test_syllables=sum(len(t) for t in test), test_files=test_files, per_coll=dict(per_coll),
                 uni_total=n_train, unique_train=len(uni)), open(OUT, "wb"))
print("done", f"{time.time()-t0:.0f}s", flush=True)
