# Birdle

A five-letter word-guessing game in the style of Wordle, built with Flutter.

Guess the hidden five-letter word in six tries. Each tile reports how its
letter scored: green for the right letter in the right place, yellow for the
right letter in the wrong place, grey for a letter that isn't in the word.
Letters already scored as misses grey out on the on-screen keyboard.

## Playing

```bash
flutter run
```

Type on the on-screen keyboard or on a physical one, then press enter.

## How it is put together

| File | Responsibility |
| --- | --- |
| `lib/game.dart` | The rules: `Game`, `Word`, `Letter`, `HitType`. Pure Dart, no Flutter imports. |
| `lib/word_list.dart` | The vocabulary: `WordList`, `AssetWordList`, `InMemoryWordList`. |
| `lib/game_controller.dart` | UI-facing controller holding the round and the letters being typed. |
| `lib/theme.dart` | Wordle's light palette and the app theme. |
| `lib/pages/game_page.dart` | Board, keyboard, reveal cascade, and rejections. |
| `lib/widgets/` | Board, tile flip, keyboard, hidden input, result panel. |
| `assets/words/` | The bundled word lists: 2,315 answers and 14,855 legal guesses. |

`main()` loads the word lists from `assets/words/` before the first frame, so
the game never guesses from a hard-coded list and the UI never waits on I/O.

The engine takes its vocabulary as a parameter, which keeps it free of Flutter
and lets tests play a round against a two-word list. `Game(seed: n)` and an
injected `Random` make the hidden word reproducible; `Game.keyStates` collapses
every submitted guess into the best result per letter for the keyboard.

## Tests

```bash
flutter analyze
flutter test
```

- `test/game_test.dart` covers scoring, including repeated letters, plus a guard
  that keeps `lib/game.dart` free of Flutter imports.
- `test/word_list_test.dart` validates the shipped word files and the loader.
- `test/widget_test.dart` plays real rounds: typing on both keyboards,
  rejections, the flip cascade, key colours, and the end-of-round panel. Pass
  `step: Duration.zero` to `MainApp` to settle animations instantly.

## Not built yet

Stats and streaks, a shareable result grid, and hard mode.
