# Symbol catalogue

`crates/ttime-core/data/symbols.tsv` lists Tibetan punctuation, marks and Sanskrit
letters with the EWTS that produces each. `ttime_core::symbols` embeds it and
provides `catalogue()`, `categories()` and `search(query)`. The Wasm bridge exports
`search_symbols_json` and `symbol_categories_json`, and the playground's Writing
Room draws the palette from them. A native panel would use the same functions.

**Status: draft.** Nothing here has been reviewed by a Tibetologist.

## Columns

`id`, `category`, code points (hex), EWTS, Unicode name, label, note, evidence.

- **Code points and EWTS** are checked against the engine by
  `crates/ttime-core/tests/symbols.rs`: every EWTS must convert to exactly the
  entry's text. An entry the engine cannot produce has an empty EWTS (none yet).
- **Names** come from the Unicode Character Database (version in the file header).
- **Labels and notes** are plain descriptions. They are not usage guidance and
  need review before anyone relies on them.
- **Evidence** is the fixture file that lists the same EWTS to Unicode pair, or
  `engine` when only the engine shows it. A test checks that a cited pair really
  is in that file. Fixtures for which pyewts, `ewts-rs` or Keyman agree are
  independent support; `engine` entries have none beyond our own output.

## Search

Every word of the query must appear in the id, category, label, name, note, EWTS,
code points (`0F0D` or `U+0F0D`) or the character itself, ignoring case. An exact
EWTS match (case-sensitive, so `Ta` is not `ta`) is listed first.

## Adding or changing an entry

Edit the TSV and run `cargo test -p ttime-core --test symbols`. Do not invent an
EWTS: use one the engine accepts, and leave the column empty otherwise. For a
mapping with open questions (see the specification's section 12), prefer
leaving it out until a specialist has ruled.

## For the reviewer

Please check: whether each label is how a scholar would name the mark, whether
the category is sensible, which entries are missing, and whether any entry is
misleading. Record answers as issues on `ttime-ime/ttime`.
