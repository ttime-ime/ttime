# Sanskrit (IAST) word list

`iast-lexicon.tsv` is the word list behind T-Time's Sanskrit suggestions: one word per
line, `word<TAB>count<TAB>flag`, accented IAST in NFC. It holds headwords and counts
only, no definitions. Rebuild it with `scripts/build-sanskrit-lexicon.py`; how it was
measured is in `docs/reference/sanskrit-spike.md`.

## Sources and licence

This file is derived from the following. Because its dictionary sources are licensed
**CC BY-NC-SA 3.0** (<https://creativecommons.org/licenses/by-nc-sa/3.0/>), the list is
distributed under that licence: credit the sources, share alike, and **non-commercial use
only**. It is separate from T-Time's code licence, which does not cover it. (Until
2026-11-19 this file said CC BY-SA 4.0, taken from the repository; that was wrong, see
below.)

- **Monier-Williams, *A Sanskrit-English Dictionary* (1899)** and **Edgerton, *Buddhist
  Hybrid Sanskrit Grammar and Dictionary*, vol. II (1953)**, as digitised by the
  Cologne Digital Sanskrit Lexicon (`github.com/sanskrit-lexicon/csl-orig`, files
  `v02/mw/mw.txt` and `v02/bhs/bhs.txt`, retrieved 2026-11-18). Headwords only,
  converted from SLP1 to IAST. The repository itself states CC BY-SA 4.0, but the
  dictionaries' own headers (`MWScan/2020/web/mwheader.xml`, `BHSScan/2020/web/bhsheader.xml`
  on sanskrit-lexicon.uni-koeln.de) read: "Copyright © 2014 The Sanskrit Library and
  Thomas Malten. All rights reserved other than those granted under the Creative Commons
  Attribution Non-Commercial Share Alike license" (3.0). We follow the stricter terms.
  **Open:** whether a plain headword list is bound by that licence, and whether the rights
  holders of Edgerton's 1953 text (Yale University Press) permit the digitisation; the
  Cologne team has not been asked yet (see the project's issue tracker).
- **Hellwig, O., *Digital Corpus of Sanskrit (DCS)*, 2010-2024**
  (`github.com/OliverHellwig/sanskrit`, `dcs/data/conllu`; CC BY 4.0 per its readme).
  Lemma counts from nine Buddhist texts: Abhidharmakośa and its bhāṣya, Avadānaśataka,
  Bodhicaryāvatāra, Buddhacarita, Lalitavistara, Laṅkāvatārasūtra,
  Saddharmapuṇḍarīkasūtra, Śikṣāsamuccaya. Lemmas that are not dictionary headwords
  are added to the list.

`flag` is `b` for an Edgerton headword or a Monier-Williams entry labelled Buddh., else `-`.
