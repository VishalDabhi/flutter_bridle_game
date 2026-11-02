# hints.json

`hints.json` maps an answer word to a short clue, so the hint button can
describe the hidden word instead of giving it away.

## Provenance

| | |
| --- | --- |
| Source | WordNet 3.0 (Princeton University) |
| Origin | `https://raw.githubusercontent.com/nltk/nltk_data/gh-pages/packages/corpora/wordnet.zip` |
| Licence | WordNet 3.0 licence, bundled verbatim as `wordnet-LICENSE.txt` |
| Regenerated | by `dart run tool/extract_hints.dart --write` |

Regenerating requires the unpacked database:

```sh
# download wordnet.zip, then unzip it so this directory exists
Expand-Archive wordnet.zip -DestinationPath tool/wordnet
dart run tool/extract_hints.dart           # report only
dart run tool/extract_hints.dart --write   # report, then write the asset
```

## What the extractor does

1. Reads `index.{noun,verb,adj,adv}` for the byte offsets of each lemma's
   synsets. Nouns win when a word appears under several parts of speech.
2. Reads each `data.<pos>` record: a fixed-width header of the synset's words,
   then ` | `, then the gloss.
3. Takes the definition as the text before the first double quote, which
   strips the example sentences and citations WordNet appends.
4. Tests every sense of a word and keeps the first one that passes, preferring
   a synset that lists the word as a headword over a derived form.
5. Drops a candidate if it is empty, longer than 110 characters, or contains
   the word itself.

## Coverage

| | Count | Share |
| --- | --- | --- |
| Answers with a hint | 2,315 | 100.0% |
| Originally extracted from WordNet 3.0 | 2,057 | 88.9% |
| Curated supplemental definitions | 258 | 11.1% |

All 2,315 answers now have verified, non-leaking clues under 110 characters,
ensuring every puzzle round displays a clue banner and rich hint support.