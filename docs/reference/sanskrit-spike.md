# Sanskrit spike: IAST candidates from Monier-Williams

Date: 2026-11-18. Offline experiment, script in `experiments/sanskrit-spike/spike.py`.
Nothing is built in the product. Roman IAST only; conversion to Tibetan script is out
of scope (EWTS already covers it).

## Question

Could T-Time offer IAST candidates while the user types Sanskrit in Latin mode: typed
without diacritics (`pratitya`), accepted with Tab, moved with the arrow keys, never
substituted unless chosen? Is the Monier-Williams headword list enough to build it on?

## Method

- **Data:** the Cologne Digital Sanskrit Lexicon's Monier-Williams source,
  `csl-orig/v02/mw/mw.txt` (SLP1, about 50 MB), fetched for the experiment and not kept
  in the repository. Headwords are the `<k1>` field.
- **Conversion:** SLP1 to IAST with our own table, NFC. 30 headwords with characters
  outside the table were skipped.
- **Lookup key:** the IAST word with every combining mark removed (`ā` to `a`, `ś` and
  `ṣ` to `s`, `ṃ` to `m`, `ñ` to `n`), lowercase.
- **Sample:** 56 Buddhist terms chosen by hand (a bias: they are the words one thinks of).
- **Measure:** letters typed, without diacritics, before the word is in a list of five;
  a selection costs no extra letter here.

## Results

- 194,058 distinct IAST headwords, 178,421 distinct keys. **7.0% of keys (12,564) have
  more than one spelling**, e.g. `siva`: śiva, śivā, siva; `prajna`: prajña, prajñā,
  prājña, prājñā. So the list must offer the choice; it cannot guess.
- Headword length: median 9 letters, 90th percentile 14, longest 57.
- **49 of 56 sample terms are headwords as spelled**, including `pratītyasamutpāda`,
  `āryāṣṭāṅgamārga`, `tathāgata`, `śūnyatā`. Missing: `bodhicitta`, `vajrayāna`,
  `vipaśyanā`, `tathatā`, `ālayavijñāna`, `catuṣkoṭi`, `trisvabhāva` (mostly later
  Buddhist technical terms; MW is a general dictionary of 1899).
- 1,951 headwords carry a Buddh. label in some entry. Only 17 of the 49 found sample
  terms do (`dharma`, `nirvāṇa`, `śūnyatā` among those without), so the label is a weak
  Buddhist signal.

| Ranking | Letters saved on the 49 found terms |
|---|---|
| Alphabetical | 28% |
| Shorter first | 32% |
| Buddh.-labelled first, then shorter | 42% |

## What this does not show

- No real usage frequency exists in this data; the rankings are proxies. A frequency
  source (the Digital Corpus of Sanskrit, if its terms allow) or a curated Buddhist word
  list would rank better. Unverified: its redistribution terms.
- The sample is mine, optimistic, and small. Real typing would also hit inflected forms,
  which headwords do not contain (a later morphology layer).
- Compounds are only listed in part; a user typing a compound missing from MW gets no help.
- Diacritic dead keys and the candidate window are not designed here.

## Licence and provenance

Monier-Williams digital edition: CC BY-SA 4.0 according to the project's published
terms (not re-checked here against the repository's licence file). Share-alike applies to
a derived word list: keep it in its own data file with its own licence and attribution,
as for Wiktionary. Provenance to record: Cologne Digital Sanskrit Lexicon, file path
above, retrieval date 2026-11-18.

## Conclusion

The headword list is a usable base (large, mostly covers core Buddhist vocabulary), but
a general dictionary ranked without usage data saves roughly a third of letters on a
favourable sample. Worth building only with a Buddhist ranking layer, and worth asking
the Tibetologists first. Next steps if wanted: check the licence file, add a curated
Buddhist list as a ranking and gap-filler, and measure on real Sanskrit passages.
