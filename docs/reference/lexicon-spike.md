# Lexicon spike: would completion save typing?

Date: 2026-11-02. Offline experiment, scripts in `experiments/lexicon-spike/`.

## Question

If T-Time showed a list of five syllable candidates while the user types EWTS,
how many EWTS letters would a user save?

## Method

- **Data:** OpenPecha BoCorpus (1,039 classical texts, about 603 million
  characters; CC0 on its dataset card). Texts split on tsheg into syllables;
  anything else (shad, page markers such as `{ 1 }`, Latin text) breaks a segment.
- **Model:** the 30,000 most frequent syllables (99.94% of training tokens), their
  frequencies, and, for each syllable, its 200 most frequent successors.
  Candidates are ranked by successor count after the previous syllable, then by
  frequency. A five-item list.
- **EWTS:** each syllable is mapped to EWTS with our own reverse converter. 150
  syllables (0.5%) that do not convert back to themselves (mostly `ཨོཾ` versus
  `ༀ`, the open `oM` question) are excluded and counted as unknown.
- **Measure:** for each held-out syllable, the fewest letters the user must type
  before the right syllable is in the list. A selection costs one keystroke; a
  syllable never reaching the list costs its full length. "Saved" is the share of
  EWTS letters not typed.

## Results

| Test set (not in training) | Frequency only | With previous syllable |
|---|---|---|
| Random 5% of texts (57 files) | 29.9% saved | **45.8%** saved |
| Whole collection held out: Tsadra (266 files) | 29.3% | **43.0%** |
| Whole collection held out: DharmaEbook (98 files) | 29.0% | **42.0%** |

With the previous syllable as context, the right next syllable is in the top
five **before any typing** about 35% of the time on the held-out collections
(top-1 about 15.5%); frequency alone gives about 13%. Unknown syllables: 0.11%.

## What this does not show

- **Syllables, not words.** A word model would likely do better; it needs a tokenizer.
- **Classical Buddhist prose only.** The corpus is Kangyur, Tengyur, Bon and
  Tsadra material. Modern or colloquial Tibetan is not represented, so the figures
  do not transfer to a "Modern" profile.
- **Optimistic in some ways.** Parallel texts and quotations still occur across
  collections, so held-out text is not fully novel. Formulaic scripture repeats a lot.
- **Optimistic about the interface.** It counts letters, assumes a top-five list the
  user always reads, and charges one keystroke for choosing. It ignores the
  attention cost of scanning a list, which could cancel part of the saving.
- **No user evidence.** This says what the data could predict, not whether
  scholars want completion. That is what the planned Tibetologist sessions are for.
- **Counts depend on the converter.** Each syllable's EWTS comes from our own
  reverse conversion, so an error there would shift the numbers.

## Data and licensing notes

- Only counts would ever ship, not source texts. The BoCorpus card gives no terms
  for its source collections, and it says "model" where it means dataset; ask
  OpenPecha or BDRC for a per-collection statement before shipping derived data.
- botok-data was downloaded but not used here. Its "public domain" statement is the
  repository's own; its `tsikchen` word list derives from a copyrighted 1985
  dictionary and its `modern_botok` pack from Monlam and other dictionaries. Use
  only the small wordlists (`ancient`, `exceptions`, `dagdra`, `uncompound_lexicon`)
  unless the terms are confirmed. Anything from `Tibetan.DICT` needs a CC BY 4.0
  credit to Meelen, Hill and Handy (2017).
- Wiktionary was not touched; its share-alike terms mean keeping it in a separate file.

## Next steps, if the evaluation sessions want completion

1. Word-level candidates from a tokenizer plus botok headwords, on top of syllables.
2. A small embedded frequency file (the top syllables and successors fit in a few MB).
3. A candidate list in the playground first, so a scholar can say whether it helps.
