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

## Round 2: longer contexts and where the savings fall

Same data, same strict test (Tsadra held out entirely, about 60,000 syllables).
`experiments/lexicon-spike/ngram.py` adds trigram and 4-gram contexts with stupid
backoff (alpha 0.4); n-grams seen only once (twice for 4-grams) are dropped.

| Model | Right syllable first in the list, no typing | In top 5, no typing | Letters saved |
|---|---|---|---|
| Frequency only | 4.5% | 12.4% | 29.2% |
| Previous syllable (bigram) | 16.4% | 36.0% | 43.1% |
| Last two syllables (trigram) | 21.8% | 44.9% | 47.9% |
| Last three syllables (4-gram) | 25.5% | 48.6% | 49.4% |

Longer contexts help, with sharply diminishing returns: the 4-gram adds only 1.5
points of saved letters over the trigram, which is roughly 0.05 keystrokes per
syllable (the average syllable is 3.6 letters). Higher orders also memorize
repeated passages, which are common in this corpus (formulae, quotations, parallel
translations), so some of the gain would not carry over to new text. The tables are
not small: about 4.9 million trigrams and 4.9 million 4-grams survive pruning, tens
of megabytes before compression, far more than a web page or input method wants to
carry without aggressive pruning.

Where the savings fall (bigram model, Tsadra held out, 200,000 syllables):

| EWTS letters | Share of syllables | Letters saved | In top 5 before typing |
|---|---|---|---|
| 2 | 23% | 31% | 63% |
| 3 | 26% | 38% | 40% |
| 4 | 28% | 43% | 24% |
| 5 | 18% | 49% | 17% |
| 6+ | 5% | 54% | 17% |

The average syllable is 3.6 letters, so the bigram model saves about 1.5
keystrokes per syllable, and the space after each syllable (the tsheg) is not saved.

## Conclusion

A conventional statistical model reaches about 43% (bigram) to 49% (4-gram) of
letters saved on classical prose, under optimistic assumptions about how the user
reads and uses the list. It cannot predict rare terms, names or Sanskrit, which are
the costly cases for scholars. The next gains would need a different kind of model
(word-level, or a neural language model) and, more importantly, evidence from
users that they want completion at all. Until then, the better-supported direction
is personal and project dictionaries (see the scholarly functionality roadmap).

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
