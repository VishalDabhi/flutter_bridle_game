import 'package:bk_lottery/game.dart';
import 'package:bk_lottery/main.dart';
import 'package:bk_lottery/widgets/keyboard.dart';
import 'package:bk_lottery/word_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The hidden word every test plays, so a round is fully predictable.
const String hidden = 'abbey';

/// Legal guesses that can never win, used to burn a round down to a loss.
const List<String> wrongGuesses = [
  'crush',
  'yards',
  'scllb',
  'babes',
  'geese',
  'jolly',
];

const List<String> letters = ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p',
  'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l',
  'z', 'x', 'c', 'v', 'b', 'n', 'm'];

void main() {
  Future<void> pumpGame(
    WidgetTester tester, {
    String word = hidden,
    List<String>? allowed,
  }) async {
    await tester.pumpWidget(
      MainApp(
        wordList: InMemoryWordList(
          answers: [word],
          allowed: allowed ?? const [hidden, ...wrongGuesses],
        ),
        step: Duration.zero,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String guess) async {
    await tester.enterText(find.byType(TextField), guess);
    await tester.pump();
  }

  Future<void> submit(WidgetTester tester, String guess) async {
    await type(tester, guess);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String letter) async {
    await tester.tap(find.byKey(ValueKey('key-$letter')));
    await tester.pump();
  }

  /// The [Container] that paints the tile keyed [id].
  Container tileBox(WidgetTester tester, String id) => tester.widget<Container>(
        find.descendant(
          of: find.byKey(ValueKey(id)),
          matching: find.byType(Container),
        ),
      );

  /// The fill colour of the tile keyed [id].
  Color tileFillColor(WidgetTester tester, String id) =>
      (tileBox(tester, id).decoration! as BoxDecoration).color!;

  /// How far the tile keyed [id] is painted vertically, 1 being full size.
  ///
  /// Reads the vertical scale out of the paint matrix rather than the layout
  /// box, so a tile that is laid out correctly but squashed to nothing still
  /// reports 0.
  double tileScale(WidgetTester tester, String id) => tester
      .widget<Transform>(
        find.descendant(
          of: find.byKey(ValueKey(id)),
          matching: find.byType(Transform),
        ),
      )
      .transform
      .entry(1, 1)
      .abs();

  group('layout', () {
    testWidgets('starts with six empty rows and a full keyboard',
        (tester) async {
      await pumpGame(tester);

      expect(find.byType(Tile), findsNWidgets(Game.defaultMaxGuesses * 5));
      expect(find.byType(PlayAgainButton), findsNothing);

      for (final letter in letters) {
        expect(find.byKey(ValueKey('key-$letter')), findsOneWidget,
            reason: 'the keyboard needs a $letter key');
      }
      expect(find.byKey(const ValueKey('key-enter')), findsOneWidget);
      expect(find.byKey(const ValueKey('key-backspace')), findsOneWidget);
    });

    testWidgets('the keyboard matches the three QWERTY rows',
        (tester) async {
      await pumpGame(tester);

      expect(
        Keyboard.rows.expand((row) => row),
        letters,
      );
    });

    testWidgets('the enter label never wraps', (tester) async {
      await pumpGame(tester);

      expect(
        tester
            .widget<Text>(find.descendant(
              of: find.byKey(const ValueKey('key-enter')),
              matching: find.text('ENTER'),
            ))
            .maxLines,
        1,
      );
    });
  });

  group('tiles are visible', () {
    testWidgets('every tile is painted at full height before any guess',
        (tester) async {
      await pumpGame(tester);

      for (var row = 0; row < Game.defaultMaxGuesses; row++) {
        for (var column = 0; column < 5; column++) {
          expect(tileScale(tester, 'tile-$row-$column'), closeTo(1, 0.01),
              reason: 'tile $row,$column must be visible');
        }
      }
    });

    testWidgets('a revealed tile returns to full height', (tester) async {
      await pumpGame(tester);

      await submit(tester, wrongGuesses.first);

      for (var column = 0; column < 5; column++) {
        expect(tileScale(tester, 'tile-0-$column'), closeTo(1, 0.01));
      }
    });

    testWidgets('a tile flips through edge-on and back to full height',
        (tester) async {
      await tester.pumpWidget(
        MainApp(
          wordList: InMemoryWordList(
            answers: const [hidden],
            allowed: const [hidden, ...wrongGuesses],
          ),
          step: const Duration(milliseconds: 50),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), wrongGuesses.first);
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);

      final samples = <double>[];
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 25));
        samples.add(tileScale(tester, 'tile-0-0'));
      }

      // Full height to start, edge-on in the middle of the flip, and full
      // height again once the result is showing.
      expect(samples.first, closeTo(1, 0.01));
      expect(samples.any((scale) => scale < 0.2), isTrue,
          reason: 'the flip must pass through edge-on, but saw $samples');
      expect(samples.last, closeTo(1, 0.01));
    });
  });

  group('typing', () {
    testWidgets('on-screen keys fill the hidden field', (tester) async {
      await pumpGame(tester);

      for (final letter in 'yards'.split('')) {
        await tapKey(tester, letter);
      }

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'yards');
    });

    testWidgets('a sixth letter is ignored', (tester) async {
      await pumpGame(tester);

      for (final letter in 'yardsq'.split('')) {
        await tapKey(tester, letter);
      }

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'yards');
    });

    testWidgets('backspace removes the last letter', (tester) async {
      await pumpGame(tester);

      for (final letter in 'yard'.split('')) {
        await tapKey(tester, letter);
      }
      await tester.tap(find.byKey(const ValueKey('key-backspace')));
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'yar');
    });

    testWidgets('the enter key submits what was typed', (tester) async {
      await pumpGame(tester);

      for (final letter in 'yards'.split('')) {
        await tapKey(tester, letter);
      }
      await tester.tap(find.byKey(const ValueKey('key-enter')));
      await tester.pumpAndSettle();

      expect(find.text('Out of guesses.'), findsNothing);
      expect(find.byType(PlayAgainButton), findsNothing);
      // The guess is on the board and the field is empty again.
      expect(find.text('Y'), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, isEmpty);
    });
  });

  group('showing the draft', () {
    String letterAt(WidgetTester tester, String id) =>
        tester.widget<Tile>(find.byKey(ValueKey(id))).letter;

    testWidgets('on-screen keys fill the active row', (tester) async {
      await pumpGame(tester);

      for (final letter in 'yar'.split('')) {
        await tapKey(tester, letter);
      }

      expect(letterAt(tester, 'tile-0-0'), 'y');
      expect(letterAt(tester, 'tile-0-1'), 'a');
      expect(letterAt(tester, 'tile-0-2'), 'r');
      expect(letterAt(tester, 'tile-0-3'), isEmpty);
      expect(letterAt(tester, 'tile-0-4'), isEmpty);
    });

    testWidgets('the hidden field feeds the active row too', (tester) async {
      await pumpGame(tester);

      await type(tester, 'yards');

      expect(letterAt(tester, 'tile-0-0'), 'y');
      expect(letterAt(tester, 'tile-0-4'), 's');
    });

    testWidgets('backspace clears the last letter on the board',
        (tester) async {
      await pumpGame(tester);

      for (final letter in 'yar'.split('')) {
        await tapKey(tester, letter);
      }
      await tester.tap(find.byKey(const ValueKey('key-backspace')));
      await tester.pump();

      expect(letterAt(tester, 'tile-0-2'), isEmpty);
      expect(letterAt(tester, 'tile-0-1'), 'a');
    });

    testWidgets('a row further down is not filled while typing',
        (tester) async {
      await pumpGame(tester);

      for (final letter in 'yar'.split('')) {
        await tapKey(tester, letter);
      }

      expect(letterAt(tester, 'tile-1-0'), isEmpty);
    });

    testWidgets('the draft clears once the guess is submitted',
        (tester) async {
      await pumpGame(tester);

      for (final letter in 'yards'.split('')) {
        await tapKey(tester, letter);
      }
      await tester.tap(find.byKey(const ValueKey('key-enter')));
      await tester.pumpAndSettle();

      // Row one holds the scored guess, row two is empty again.
      expect(letterAt(tester, 'tile-0-0'), 'y');
      expect(letterAt(tester, 'tile-1-0'), isEmpty);
    });
  });

  group('enter key readiness', () {
    Color enterFill(WidgetTester tester) => tester
        .widget<Material>(find.descendant(
          of: find.byKey(const ValueKey('key-enter')),
          matching: find.byType(Material),
        ))
        .color!;

    testWidgets('enter is dark until five letters are typed', (tester) async {
      await pumpGame(tester);

      expect(enterFill(tester), const Color(0xFF121213));

      for (final letter in 'yard'.split('')) {
        await tapKey(tester, letter);
      }
      expect(enterFill(tester), const Color(0xFF121213));
    });

    testWidgets('enter turns green when the word is legal', (tester) async {
      await pumpGame(tester);

      for (final letter in 'yards'.split('')) {
        await tapKey(tester, letter);
      }

      expect(enterFill(tester), const Color(0xFF6AAA64));
    });

    testWidgets('enter stays dark when five letters are not a word',
        (tester) async {
      await pumpGame(tester);

      for (final letter in 'zzzzz'.split('')) {
        await tapKey(tester, letter);
      }

      expect(enterFill(tester), const Color(0xFF121213));
    });

    testWidgets('enter drops back to dark once the letters are cleared',
        (tester) async {
      await pumpGame(tester);

      for (final letter in 'yards'.split('')) {
        await tapKey(tester, letter);
      }
      expect(enterFill(tester), const Color(0xFF6AAA64));

      await tester.tap(find.byKey(const ValueKey('key-backspace')));
      await tester.pump();

      expect(enterFill(tester), const Color(0xFF121213));
    });
  });

  group('rejecting a guess', () {
    testWidgets('rejects a word that is not in the word list',
        (tester) async {
      await pumpGame(tester);

      await submit(tester, 'house');

      expect(find.text("'house' isn't in the word list."), findsOneWidget);
    });

    testWidgets('rejects a guess that is not five letters', (tester) async {
      await pumpGame(tester);

      await submit(tester, 'ab');

      expect(find.text('Guesses must be exactly 5 letters.'), findsOneWidget);
    });

    testWidgets('a rejected guess does not consume a turn', (tester) async {
      await pumpGame(tester);

      await submit(tester, 'house');
      await submit(tester, 'ab');
      await submit(tester, wrongGuesses.first);

      expect(find.text('C'), findsOneWidget);
      expect(find.byType(PlayAgainButton), findsNothing);
    });

    testWidgets('a rejected guess keeps the letters on the field',
        (tester) async {
      await pumpGame(tester);

      await submit(tester, 'house');

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'house');
    });
  });

  group('scoring', () {
    testWidgets('a recorded guess renders five letters', (tester) async {
      await pumpGame(tester);

      await submit(tester, wrongGuesses.first);

      for (final letter in wrongGuesses.first.split('')) {
        expect(find.text(letter.toUpperCase()), findsOneWidget);
      }
    });

    testWidgets('a miss paints every letter key grey', (tester) async {
      await pumpGame(tester);

      await submit(tester, wrongGuesses.first);

      final key = tester.widget<Material>(find.descendant(
        of: find.byKey(ValueKey('key-${wrongGuesses.first[0]}')),
        matching: find.byType(Material),
      ));
      expect(key.color, const Color(0xFF86888A));
    });

    testWidgets('key states are cleared by Play Again', (tester) async {
      await pumpGame(tester);

      await submit(tester, wrongGuesses.first);
      final afterGuess = tester.widget<Material>(find.descendant(
        of: find.byKey(ValueKey('key-${wrongGuesses.first[0]}')),
        matching: find.byType(Material),
      ));
      expect(afterGuess.color, const Color(0xFF86888A));

      await loseRound(tester);
      await tester.tap(find.byType(PlayAgainButton));
      await tester.pumpAndSettle();

      final afterReset = tester.widget<Material>(find.descendant(
        of: find.byKey(ValueKey('key-${wrongGuesses.first[0]}')),
        matching: find.byType(Material),
      ));
      expect(afterReset.color, const Color(0xFFD3D6DA));
    });

    testWidgets('an unrevealed tile is outlined on white', (tester) async {
      await pumpGame(tester);

      final decoration =
          tileBox(tester, 'tile-0-0').decoration! as BoxDecoration;

      expect(decoration.color, const Color(0xFFFFFFFF));
      expect((decoration.border! as Border).top.color, const Color(0xFF3A3A3C));
    });

    testWidgets("revealed tiles keep Wordle's colours", (tester) async {
      await pumpGame(tester);

      // 'yards' against 'abbey': a partial y and a missing r.
      await submit(tester, 'yards');

      expect(tileFillColor(tester, 'tile-0-0'), const Color(0xFFC9B458));
      expect(tileFillColor(tester, 'tile-0-2'), const Color(0xFF787C7E));
    });

    testWidgets('the answer fill returns to white after Play Again',
        (tester) async {
      await pumpGame(tester);

      await submit(tester, 'yards');
      await loseRound(tester);
      await tester.tap(find.byType(PlayAgainButton));
      await tester.pumpAndSettle();

      expect(tileFillColor(tester, 'tile-0-0'), const Color(0xFFFFFFFF));
    });

    testWidgets('enter and backspace stay dark in the light theme',
        (tester) async {
      await pumpGame(tester);

      Color keyColor(String id) => tester.widget<Material>(find.descendant(
            of: find.byKey(ValueKey('key-$id')),
            matching: find.byType(Material),
          )).color!;

      // Enter is disabled until five letters are typed, and a disabled key is
      // drawn faded, so fill the board first. Four letters keeps it dark
      // rather than turning green.
      for (final letter in 'yard'.split('')) {
        await tapKey(tester, letter);
      }
      await tester.pump();

      expect(keyColor('enter'), const Color(0xFF121213));
      expect(keyColor('backspace'), const Color(0xFF121213));
      expect(keyColor('y'), const Color(0xFFD3D6DA));
    });
  });

  group('revealing', () {
    testWidgets('earlier rows keep their result after the next guess',
        (tester) async {
      await pumpGame(tester);

      // 'yards' against 'abbey': a partial y, a partial a, three misses.
      await submit(tester, 'yards');
      expect(tester.widget<Tile>(find.byKey(const ValueKey('tile-0-0'))).type,
          HitType.partial);

      await submit(tester, 'crush');
      final firstRowFirstTile =
          tester.widget<Tile>(find.byKey(const ValueKey('tile-0-0')));
      expect(firstRowFirstTile.type, HitType.partial);
      expect(firstRowFirstTile.revealed, isTrue);
      expect(
        tester.widget<Tile>(find.byKey(const ValueKey('tile-1-0'))).type,
        HitType.miss,
      );
    });

    testWidgets('the cascade locks input and then unlocks it', (tester) async {
      const step = Duration(milliseconds: 50);
      await tester.pumpWidget(
        MainApp(
          wordList: InMemoryWordList(
            answers: const [hidden],
            allowed: const [hidden, ...wrongGuesses],
          ),
          step: step,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), wrongGuesses.first);
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      // Mid cascade: one tile has flipped and input is locked.
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      expect(
        tester.widget<Tile>(find.byKey(const ValueKey('tile-0-0'))).revealed,
        isTrue,
      );
      expect(
        tester.widget<Tile>(find.byKey(const ValueKey('tile-0-4'))).revealed,
        isFalse,
      );

      // Once every tile has flipped the board settles and input returns.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
      for (var column = 0; column < 5; column++) {
        expect(
          tester
              .widget<Tile>(find.byKey(ValueKey('tile-0-$column')))
              .revealed,
          isTrue,
        );
      }
    });

    testWidgets('a rejected guess shakes the board instead', (tester) async {
      await pumpGame(tester);

      await submit(tester, 'house');

      // The word stays visible as an unscored draft so it can be corrected.
      final tile = tester.widget<Tile>(find.byKey(const ValueKey('tile-0-0')));
      expect(tile.letter, 'h');
      expect(tile.type, HitType.none);
      expect(tile.revealed, isFalse);
      expect(find.byType(PlayAgainButton), findsNothing);
    });
  });

  group('losing', () {
    testWidgets('six wrong guesses end the round and name the word',
        (tester) async {
      await pumpGame(tester);

      for (final guess in wrongGuesses) {
        await submit(tester, guess);
      }

      expect(find.byType(PlayAgainButton), findsOneWidget);
      expect(find.text('Out of guesses'), findsOneWidget);
      expect(find.text('The word was ABBEY.'), findsOneWidget);
    });

    testWidgets('input is disabled once the round is over', (tester) async {
      await pumpGame(tester);

      await loseRound(tester);

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.enabled, isFalse);
    });

    testWidgets('a win spells the answer in the rows left empty',
        (tester) async {
      await pumpGame(tester);

      await submit(tester, wrongGuesses.first);
      await submit(tester, hidden);

      // Rows two to five were never guessed, so they show the answer.
      const answer = {
        'tile-2-0': 'a',
        'tile-2-1': 'b',
        'tile-3-3': 'e',
        'tile-5-4': 'y',
      };
      for (final entry in answer.entries) {
        expect(
          tester.widget<Tile>(find.byKey(ValueKey(entry.key))).letter,
          entry.value,
        );
      }
    });

    testWidgets('Play Again clears the board and re-enables input',
        (tester) async {
      await pumpGame(tester);

      await loseRound(tester);
      await tester.tap(find.byType(PlayAgainButton));
      await tester.pumpAndSettle();

      expect(find.byType(PlayAgainButton), findsNothing);
      expect(find.text('Out of guesses'), findsNothing);
      expect(find.byType(Tile), findsNWidgets(Game.defaultMaxGuesses * 5));
      expect(find.text('Y'), findsNothing);

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.enabled, isTrue);
      expect(field.controller!.text, isEmpty);
    });
    testWidgets('Play Again restores focus for a physical keyboard',
        (tester) async {
      await pumpGame(tester);

      await loseRound(tester);
      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
        isFalse,
      );

      await tester.tap(find.byType(PlayAgainButton));
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
        isTrue,
      );
    });
  });

  group('winning', () {
    testWidgets('guessing the hidden word wins the round', (tester) async {
      await pumpGame(tester);

      await submit(tester, hidden);

      expect(find.byType(PlayAgainButton), findsOneWidget);
      expect(find.text('You won!'), findsOneWidget);
      expect(find.text('Solved in 1 try.'), findsOneWidget);
    });

    testWidgets('the winner is drawn from the real word list', (tester) async {
      // Plays a round against the bundled vocabulary, reproducing the same
      // seeded game the page builds so the answer is known up front. Reading
      // an asset needs runAsync, because the test runs on a fake clock.
      final words = (await tester.runAsync(AssetWordList.load))!;
      final answer = Game(wordList: words, seed: 0).hiddenWord.toString();

      await tester.pumpWidget(
        MainApp(wordList: words, seed: 0, step: Duration.zero),
      );
      await tester.pumpAndSettle();

      await submit(tester, answer);

      expect(find.text('You won!'), findsOneWidget);
    });

    testWidgets('Play Again after a win starts a fresh round',
        (tester) async {
      await pumpGame(tester);

      await submit(tester, hidden);
      await tester.tap(find.byType(PlayAgainButton));
      await tester.pumpAndSettle();

      expect(find.text('You won!'), findsNothing);
      expect(find.byType(PlayAgainButton), findsNothing);

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.enabled, isTrue);
    });
  });
}

/// Burns every guess so the round ends in a loss.
Future<void> loseRound(WidgetTester tester) async {
  for (final guess in wrongGuesses) {
    await tester.enterText(find.byType(TextField), guess);
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }
}
