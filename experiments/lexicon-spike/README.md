# Lexicon spike

An offline experiment, not product code. It asks how much typing a completion
list would save, using syllable counts from OpenPecha's BoCorpus (CC0 on its
dataset card). No corpus text or count file is stored in this repository.

Inputs (download them yourself): `bo_corpus.parquet` from
https://huggingface.co/datasets/openpecha/BoCorpus. Needs Python 3 with `pyarrow`
and a built `ttime-cli` (`cargo build -p ttime-cli`).

```sh
# 1. count syllables; the optional 3rd argument holds out one whole collection
python3 -I count.py bo_corpus.parquet counts.pkl ["Tsadra Collection"]
# 2. map the vocabulary to EWTS with our reverse converter, and drop syllables
#    that do not round-trip (blank lines mark them)
python3 -I -c "import pickle;d=pickle.load(open('counts.pkl','rb'));open('vocab.txt','w').write('\n'.join(d['vocab'])+'\n')"
ttime-cli --reverse < vocab.txt > ewts.txt;  ttime-cli < ewts.txt > back.txt
#    (blank out lines where vocab.txt and back.txt differ -> ewts_ok.txt)
# 3. evaluate
python3 -I eval.py counts.pkl ewts_ok.txt
```

Results and caveats: `docs/reference/lexicon-spike.md`.
