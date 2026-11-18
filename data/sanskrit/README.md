# Sanskrit (IAST) word list

`iast-lexicon.tsv` is the word list behind T-Time's Sanskrit suggestions: one word per
line, `word<TAB>count<TAB>flag`, accented IAST in NFC. It holds headwords and counts
only, no definitions. Rebuild it with `scripts/build-sanskrit-lexicon.py`; how it was
measured is in `docs/reference/sanskrit-spike.md`.

## Sources and licence

This file is derived from the following, and is distributed under **CC BY-SA 4.0**
(<https://creativecommons.org/licenses/by-sa/4.0/>), which the share-alike sources require.
It is separate from T-Time's code licence, which does not cover it.

- **Monier-Williams, *A Sanskrit-English Dictionary* (1899)** and **Edgerton, *Buddhist
  Hybrid Sanskrit Grammar and Dictionary*, vol. II (1953)**, as digitised by the
  Cologne Digital Sanskrit Lexicon (`github.com/sanskrit-lexicon/csl-orig`, files
  `v02/mw/mw.txt` and `v02/bhs/bhs.txt`, retrieved 2026-11-18; CC BY-SA 4.0 per that
  repository). Headwords only, converted from SLP1 to IAST. The Edgerton text's own
  terms have not been checked separately from the repository's licence.
- **Hellwig, O., *Digital Corpus of Sanskrit (DCS)*, 2010-2024**
  (`github.com/OliverHellwig/sanskrit`, `dcs/data/conllu`; CC BY 4.0 per its readme).
  Lemma counts from nine Buddhist texts: Abhidharmakośa and its bhāṣya, Avadānaśataka,
  Bodhicaryāvatāra, Buddhacarita, Lalitavistara, Laṅkāvatārasūtra,
  Saddharmapuṇḍarīkasūtra, Śikṣāsamuccaya. Lemmas that are not dictionary headwords
  are added to the list.

`flag` is `b` for an Edgerton headword or a Monier-Williams entry labelled Buddh., else `-`.
