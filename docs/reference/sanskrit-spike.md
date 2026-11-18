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

## Second run: adding Edgerton's Buddhist Hybrid Sanskrit Dictionary

Added `csl-orig/v02/bhs/bhs.txt` (7.6 MB, same Cologne repository, same SLP1 format),
fetched 2026-11-18. Every Edgerton headword counts as Buddhist for the ranking.

- 17,777 BHS headwords, **11,236 of them not in Monier-Williams**. Combined: 205,294
  distinct IAST words, 188,079 keys, 7.3% of keys ambiguous (13,738).
- **Coverage rises from 49 to 54 of the 56 sample terms.** Now found: `bodhicitta`,
  `vajrayāna`, `vipaśyanā`, `tathatā`, `ālayavijñāna`. Still missing: `catuṣkoṭi`
  (only `catuṣkoṭikā`) and `trisvabhāva`.
- **Typing saved did not improve.** On the 54 found terms: alphabetical 28%, shorter first
  31%, Buddhist first 39%. On the same 49 terms as before: 26%, 30%, 38% (was 28%, 32%,
  42%). The Buddhist pool grew ten-fold (1,951 to 18,770 headwords), so there is more
  competition inside the top five. More vocabulary helps coverage, not ranking.
- Only 43 of the 54 found terms are Buddhist-labelled; `nirvāṇa`, `duḥkha`, `anātman`,
  `bhikṣu`, `mantra`, `āryāṣṭāṅgamārga` are not Edgerton headwords.
- The repository's licence is CC BY-SA 4.0; the Edgerton text's own terms were not checked.

## Third run: usage counts from the Digital Corpus of Sanskrit

Fetched 2026-11-18 from `github.com/OliverHellwig/sanskrit`, `dcs/data/conllu/`: nine
Buddhist texts (84 files, 17 MB; Abhidharmakośa and bhāṣya, Avadānaśataka,
Bodhicaryāvatāra, Buddhacarita, Lalitavistara, Laṅkāvatārasūtra, Saddharmapuṇḍarīka,
Śikṣāsamuccaya) and `lookup/dictionary.csv` (not used further). The repository's readme
states the data is **CC BY 4.0**; cite Hellwig, *Digital Corpus of Sanskrit*. The other 260
texts (about 5.3 million of 5.46 million words) were not fetched, so these are counts for
Buddhist texts only, not corpus-wide.

- 125,552 words, 8,793 distinct lemmas. 87% of the lemmas are headwords in Monier-Williams
  or Edgerton, covering 96% of running words. Adding the other lemmas to the pool adds
  1,164 words (206,458 in all) but still does not find `catuṣkoṭi` or `trisvabhāva`.
- 46 of the 56 sample terms occur as lemmas; the 10 that do not: `āryāṣṭāṅgamārga`,
  `bodhicitta`, `vajrayāna`, `tantra`, `prātimokṣa`, `nirmāṇakāya`, `sambhogakāya`,
  `catuṣkoṭi`, `trisvabhāva`, `arhat`. Rare ones: `madhyamaka` 1, `abhidharma` 1,
  `sukhāvatī` 1.
- **Ranking by these counts saves 55 to 56% of letters** on the 54 found terms (38% with
  the labelled ranking; Buddhist-label as a tie-break adds about 1 point). On the same
  49 terms: 56%, against 42% (Monier-Williams alone) and 38% (with Edgerton).

Caution: the test terms were chosen by me and counted in the same nine texts, so the
figure is optimistic; and these texts are Mahāyāna sūtras, a poem and a ślokas manual,
not the commentarial or Madhyamaka prose scholars write about. The honest reading is
"counts rank far better than any dictionary label", not "56%". Held-out text would be
the next test.

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

Monier-Williams plus Edgerton is a usable base (205,000 words, 54 of 56 sample terms),
but ranked without usage data it saves roughly a third of letters on a favourable sample,
and more vocabulary does not fix that. Usage counts from the Digital Corpus of Sanskrit
(CC BY 4.0) lift the same measure to the mid-fifties, with the optimism noted above. Worth building only with a Buddhist ranking layer, and worth asking
the Tibetologists first. Next steps if wanted: confirm the licences against the repository files, test on held-out
passages (fit counts on seven texts, test on two), consider fetching the rest of the
corpus for general counts, and ask the Tibetologists which texts matter.
