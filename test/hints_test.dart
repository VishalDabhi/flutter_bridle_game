import 'dart:convert';
import 'dart:io';

import 'package:bk_lottery/game.dart';
import 'package:bk_lottery/game_controller.dart';
import 'package:bk_lottery/hints.dart';
import 'package:bk_lottery/word_list.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// An [AssetBundle] backed by a map of asset key to contents.
class _MapAssetBundle extends CachingAssetBundle {
  _MapAssetBundle(this.assets);

  final Map<String, String> assets;

  @override
  Future<ByteData> load(String key) async {
    final value = assets[key];
    if (value == null) throw StateError('No asset named $key.');

    return ByteData.view(Uint8List.fromList(utf8.encode(value)).buffer);
  }
}

/// A game over a fixed hidden word.
Game _game({String hidden = 'abbey', int maxGuesses = Game.defaultMaxGuesses}) =>
    Game(
      wordList: InMemoryWordList(
        answers: [hidden],
        allowed: [hidden, 'crush', 'yards'],
      ),
      seed: 0,
      maxGuesses: maxGuesses,
    );

void main() {
  setUp(AssetHintBook.debugClearCache);
  tearDown(AssetHintBook.debugClearCache);

  group('InMemoryHintBook', () {
    test('looks up a clue, ignoring case', () {
      final book = InMemoryHintBook(const {'abbey': 'a monastery'});

      expect(book.descriptionOf('abbey'), 'a monastery');
      expect(book.descriptionOf('ABBEY'), 'a monastery');
      expect(book.length, 1);
    });

    test('an empty book has nothing', () {
      expect(InMemoryHintBook.empty().descriptionOf('abbey'), isNull);
    });
  });

  group('AssetHintBook.load', () {
    test('reads the asset into a book', () async {
      final book = await AssetHintBook.load(
        bundle: _MapAssetBundle({
          AssetHintBook.hintsAsset: '{"abbey":"a monastery"}',
        }),
      );

      expect(book.descriptionOf('abbey'), 'a monastery');
    });

    test('caches the first result', () async {
      final first = await AssetHintBook.load(
        bundle: _MapAssetBundle({
          AssetHintBook.hintsAsset: '{"abbey":"a monastery"}',
        }),
      );
      final second = await AssetHintBook.load(bundle: _MapAssetBundle({}));

      expect(identical(first, second), isTrue);
    });

    test('a missing asset yields an empty book instead of throwing',
        () async {
      final book = await AssetHintBook.load(bundle: _MapAssetBundle({}));

      expect(book.length, 0);
    });

    test('a corrupt asset yields an empty book', () async {
      final book = await AssetHintBook.load(
        bundle: _MapAssetBundle({AssetHintBook.hintsAsset: 'not json at all'}),
      );

      expect(book.length, 0);
    });

    test('entries that are not strings are skipped', () async {
      final book = await AssetHintBook.load(
        bundle: _MapAssetBundle({
          AssetHintBook.hintsAsset: '{"abbey":"a monastery","bad":7}',
        }),
      );

      expect(book.length, 1);
      expect(book.descriptionOf('bad'), isNull);
    });
  });

  group('SafeHint', () {
    test('passes a clue that does not give the word away', () {
      final book = InMemoryHintBook(
        const {'abbey': 'a building where monks live'},
      );

      expect(SafeHint.describe(book, 'abbey'), 'a building where monks live');
    });

    test('rejects a clue containing the word', () {
      final book = InMemoryHintBook(const {'aback': 'all yards aback'});

      expect(SafeHint.describe(book, 'aback'), isNull);
    });

    test('rejects a blank clue', () {
      expect(SafeHint.describe(InMemoryHintBook(const {'abbey': '   '}),
          'abbey'), isNull);
    });

    test('accepts a clue whose letters appear in order', () {
      // The letters-in-order rule would reject nearly every sentence, so it
      // must not be applied.
      final book = InMemoryHintBook(const {'abbey': 'a bright barn by evening'});

      expect(SafeHint.describe(book, 'abbey'), 'a bright barn by evening');
    });
  });

  group('unrevealedPositions', () {
    test('is every position before any guess', () {
      expect(unrevealedPositions(_game()), [0, 1, 2, 3, 4]);
    });

    test('leaves out positions a guess has pinned down', () {
      // 'yards' against 'abbey': y and a are partial, r d s are misses.
      final game = _game()..guess('yards');

      expect(unrevealedPositions(game), [2, 3, 4]);
      expect(firstUnrevealedPosition(game), 2);
    });

    test('is empty once every letter is known', () {
      final game = _game()..guess('abbey');

      expect(unrevealedPositions(game), isEmpty);
      expect(firstUnrevealedPosition(game), isNull);
    });
  });

  group('GameController.useHint', () {
    test('shows the clue when the word has one', () {
      final controller = GameController(
        game: _game(),
        hintBook: InMemoryHintBook(const {'abbey': 'a monastery'}),
      );

      expect(controller.canHint, isTrue);
      expect(controller.useHint(), HintStatus.described);
      expect(controller.hintText, 'a monastery');
      expect(controller.lastHintColumn, isNull);
      expect(controller.hintLetters, isEmpty);
      expect(controller.hintsUsed, 1);
    });

    test('reveals a letter when the word has no clue', () {
      final controller = GameController(game: _game());

      expect(controller.useHint(), HintStatus.revealedLetter);
      expect(controller.hintText, isNull);
      expect(controller.lastHintColumn, 0);
      expect(controller.hintLetters, {0: {0}});
    });

    test('reveals the first letter no guess has pinned down', () {
      final game = _game()..guess('yards');
      final controller = GameController(game: game);

      controller.useHint();

      expect(controller.lastHintColumn, 2);
      expect(game.hiddenWord[2].char, 'b');
    });

    test('rejects a clue that gives the word away', () {
      final controller = GameController(
        game: _game(hidden: 'aback'),
        hintBook: InMemoryHintBook(const {'aback': 'all yards aback'}),
      );

      expect(controller.useHint(), HintStatus.revealedLetter);
      expect(controller.hintText, isNull);
    });

    test('a second hint is refused while the cooldown runs', () {
      var now = DateTime(2026);
      final controller = GameController(
        game: _game(),
        hintBook: InMemoryHintBook(const {'abbey': 'a monastery'}),
        clock: () => now,
      );
      controller.useHint();

      expect(controller.canHint, isFalse);
      expect(controller.useHint(), HintStatus.coolingDown);
      expect(controller.hintsUsed, 1);

      // Halfway through the minute it is still refused.
      now = now.add(const Duration(seconds: 30));
      expect(controller.useHint(), HintStatus.coolingDown);
      expect(controller.hintsUsed, 1);
    });

    test('the hint comes back once the cooldown runs out', () {
      var now = DateTime(2026);
      final controller = GameController(
        game: _game(),
        hintBook: InMemoryHintBook(const {'abbey': 'a monastery'}),
        clock: () => now,
      );
      expect(controller.useHint(), HintStatus.described);
      expect(controller.hintCooldownRemaining, const Duration(seconds: 60));

      now = now.add(const Duration(seconds: 60));

      expect(controller.hintCooldownRemaining, Duration.zero);
      expect(controller.canHint, isTrue);
      // The clue was already shown, so this hint gives up a letter instead.
      expect(controller.useHint(), HintStatus.revealedLetter);
      expect(controller.hintsUsed, 2);
      expect(controller.hintLetters, {0: {0}});
    });

    test('a repeat hint skips the clue it already showed', () {
      var now = DateTime(2026);
      final controller = GameController(
        game: _game(),
        hintBook: InMemoryHintBook(const {'abbey': 'a monastery'}),
        clock: () => now,
      );

      expect(controller.useHint(), HintStatus.described);

      now = now.add(const Duration(seconds: 60));
      expect(controller.useHint(), HintStatus.revealedLetter);

      // Each further hint reveals the next letter no guess has pinned down
      // rather than repeating the clue.
      now = now.add(const Duration(seconds: 60));
      expect(controller.useHint(), HintStatus.revealedLetter);
      expect(controller.hintText, 'a monastery');
      expect(controller.hintLetters, {0: {0, 1}});
    });

    test('revealed letters accumulate across hints', () {
      var now = DateTime(2026);
      final controller = GameController(game: _game(), clock: () => now);
      final revealed = <int>{};

      for (var i = 0; i < 5; i++) {
        if (i > 0) now = now.add(const Duration(seconds: 60));
        controller.useHint();
        revealed.add(controller.lastHintColumn!);
      }

      expect(revealed, {0, 1, 2, 3, 4});
      expect(controller.hintLetters, {0: {0, 1, 2, 3, 4}});

      // Nothing left to reveal.
      now = now.add(const Duration(seconds: 60));
      expect(controller.useHint(), HintStatus.unavailable);
    });

    test('a hint limit is honoured when one is set', () {
      final controller = GameController(
        game: _game(),
        hintBook: InMemoryHintBook(const {'abbey': 'a monastery'}),
        hintCooldown: Duration.zero,
        hintLimit: 2,
      );
      controller.useHint();
      controller.useHint();

      expect(controller.canHint, isFalse);
      expect(controller.useHint(), HintStatus.limitReached);
      expect(controller.hintsUsed, 2);
    });

    test('is refused once every letter is on the board', () {
      // Knowing every letter means the round is already won, so the hint is
      // refused before it can reveal anything. The unavailable branch is the
      // defensive path behind that.
      final game = _game()..guess('abbey');
      final controller = GameController(game: game);

      expect(unrevealedPositions(game), isEmpty);
      expect(controller.canHint, isFalse);
      expect(controller.useHint(), HintStatus.limitReached);
    });

    test('cannot be used once the round is over', () {
      final game = _game(maxGuesses: 1)..guess('crush');
      final controller = GameController(game: game);

      expect(controller.canHint, isFalse);
      expect(controller.useHint(), HintStatus.limitReached);
    });

    test('Play Again re-arms the hint immediately', () {
      var now = DateTime(2026);
      final controller = GameController(game: _game(), clock: () => now)
        ..useHint();
      expect(controller.canHint, isFalse);

      controller.reset();

      expect(controller.hintsUsed, 0);
      expect(controller.hintText, isNull);
      expect(controller.lastHintColumn, isNull);
      expect(controller.hintLetters, isEmpty);
      expect(controller.hintCooldownRemaining, Duration.zero);
      expect(controller.canHint, isTrue);
    });
  });

  group('shipped hints.json', () {
    late Map<String, String> hints;

    setUpAll(() {
      hints = (json.decode(
        File(AssetHintBook.hintsAsset).readAsStringSync(),
      ) as Map)
          .cast<String, String>();
    });

    test('describes most of the answer list', () {
      final answers = (json.decode(
        File('assets/words/answers.json').readAsStringSync(),
      ) as List)
          .cast<String>();

      expect(hints.length / answers.length, greaterThan(0.85));
    });

    test('only describes words that can be the hidden word', () {
      final answers = (json.decode(
        File('assets/words/answers.json').readAsStringSync(),
      ) as List)
          .cast<String>()
          .toSet();

      expect(answers.containsAll(hints.keys), isTrue);
    });

    test('every key is a five letter lowercase word', () {
      final word = RegExp(r'^[a-z]{5}$');

      expect(hints.keys.where(word.hasMatch).length, hints.length);
    });

    test('no clue gives its own word away', () {
      final leaks = hints.entries
          .where((entry) => entry.value.toLowerCase().contains(entry.key))
          .toList();

      expect(leaks, isEmpty, reason: 'leaking clues: ${leaks.take(5)}');
    });

    test('every clue is a short single line of text', () {
      for (final entry in hints.entries) {
        expect(entry.value.trim(), isNotEmpty);
        expect(entry.value, isNot(contains('\n')));
        expect(entry.value.length, lessThanOrEqualTo(110));
      }
    });
  });
}