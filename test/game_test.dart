import 'dart:io';

import 'package:bk_lottery/game.dart';
import 'package:bk_lottery/word_list.dart';
import 'package:flutter_test/flutter_test.dart';

/// A tiny list so engine tests stay fast and deterministic.
WordList testWordList({
  List<String> answers = const ['abbey'],
  List<String> allowed = const ['abbey', 'babes', 'crush', 'scllb', 'yards'],
}) =>
    InMemoryWordList(answers: answers, allowed: allowed);

/// A game over [testWordList] with a predictable hidden word.
Game testGame({
  List<String> answers = const ['abbey'],
  List<String> allowed = const ['abbey', 'babes', 'crush', 'scllb', 'yards'],
  int maxGuesses = Game.defaultMaxGuesses,
}) =>
    Game(
      wordList: testWordList(answers: answers, allowed: allowed),
      maxGuesses: maxGuesses,
      seed: 0,
    );

void main() {
  group('game.dart stays free of Flutter', () {
    test('imports no package:flutter library', () {
      final source = File('lib/game.dart').readAsStringSync();

      expect(source, isNot(contains("package:flutter")));
    });
  });

  group('Word.fromString', () {
    test('lowercases every character', () {
      expect(Word.fromString('ABBEY').toString(), 'abbey');
    });

    test('starts every letter as HitType.none', () {
      expect(
        Word.fromString('abbey').every((letter) => letter.type == HitType.none),
        isTrue,
      );
    });

    test('throws when the guess is not five characters', () {
      expect(() => Word.fromString('abbe'), throwsArgumentError);
      expect(() => Word.fromString('abbeys'), throwsArgumentError);
    });
  });

  group('Word.empty', () {
    test('is five blank letters typed none', () {
      final word = Word.empty();
      expect(word.length, Word.wordLength);
      expect(word.isEmpty, isTrue);
      expect(word.every((letter) => letter.char.isEmpty), isTrue);
    });
  });

  group('evaluateGuess', () {
    test('scores an exact match as all hits', () {
      final result = Word.fromString('abbey').evaluateGuess(
        Word.fromString('abbey'),
      );
      expect(result.every((letter) => letter.type == HitType.hit), isTrue);
    });

    test('scores a present letter in the wrong spot as partial', () {
      // Guess 'yards' against hidden 'abbey': the leading 'y' exists in the
      // hidden word but sits at the last index, so it is a partial.
      final result = Word.fromString('yards').evaluateGuess(
        Word.fromString('abbey'),
      );
      expect(result[0].type, HitType.partial); // y is present, wrong slot
      expect(result[1].type, HitType.partial); // a is present, wrong slot
      expect(result[2].type, HitType.miss); // r is not in abbey
      expect(result[3].type, HitType.miss); // d is not in abbey
      expect(result[4].type, HitType.miss); // s is not in abbey
    });

    test('scores an absent letter as a miss', () {
      final result = Word.fromString('crush').evaluateGuess(
        Word.fromString('abbey'),
      );
      expect(result.every((letter) => letter.type == HitType.miss), isTrue);
    });

    test('each hidden letter is claimed at most once by partials', () {
      // Guess 'geese' has three 'e' letters; hidden 'abbey' has two, at
      // indices 3 and 4. Both are claimed as hits, so no 'e' is left over.
      final result = Word.fromString('geese').evaluateGuess(
        Word.fromString('abbey'),
      );
      expect(result[1].type, HitType.partial); // first 'e' claims one
      expect(result[2].type, HitType.miss); // second 'e' has nothing left
      expect(result[4].type, HitType.miss); // third 'e' has nothing left
    });

    test('the hidden word is returned untouched', () {
      final hidden = Word.fromString('abbey');
      Word.fromString('yards').evaluateGuess(hidden);

      expect(hidden.every((letter) => letter.type == HitType.none), isTrue);
    });
  });

  group('Game construction', () {
    test('a seeded game picks a deterministic hidden word', () {
      final first = Game(wordList: testWordList(), seed: 2);
      final second = Game(wordList: testWordList(), seed: 2);

      expect(first.hiddenWord.toString(), second.hiddenWord.toString());
    });

    test('an unseeded game still picks one of the answers', () {
      final game = Game(
        wordList: testWordList(answers: ['abbey', 'babes']),
      );

      expect(['abbey', 'babes'], contains(game.hiddenWord.toString()));
    });

    test('picks from answers, never from the wider guess list', () {
      for (var seed = 0; seed < 20; seed++) {
        final game = Game(
          wordList: testWordList(
            answers: ['abbey'],
            allowed: const ['abbey', 'babes', 'crush'],
          ),
          seed: seed,
        );

        expect(game.hiddenWord.toString(), 'abbey');
      }
    });

    test('defaults to six guesses', () {
      expect(Game.defaultMaxGuesses, 6);

      final game = Game(wordList: testWordList());
      expect(game.guesses.length, 6);
      expect(game.activeIndex, 0);
      expect(game.guessesRemaining, 6);
      expect(game.previousGuess.isEmpty, isTrue);
    });

    test('honours a custom maxGuesses', () {
      final game = Game(wordList: testWordList(), maxGuesses: 3);

      expect(game.guesses.length, 3);
      expect(game.guessesRemaining, 3);
    });
  });

  group('Game.guess', () {
    test('records the evaluated guess in the next empty slot', () {
      final game = testGame();

      expect(game.guess('yards').toString(), 'yards');
      expect(game.previousGuess.toString(), 'yards');
      expect(game.activeIndex, 1);
      expect(game.guessesRemaining, Game.defaultMaxGuesses - 1);
    });

    test('fills each slot in order, leaving later slots empty', () {
      final game = testGame();
      game.guess('yards');
      game.guess('crush');

      expect(game.guesses[0].toString(), 'yards');
      expect(game.guesses[1].toString(), 'crush');
      expect(game.guesses[2].isEmpty, isTrue);
      expect(game.guesses[5].isEmpty, isTrue);
    });

    test('accepts an upper-case guess', () {
      expect(testGame().guess('YARDS').toString(), 'yards');
    });

    test('winning sets didWin and isOver', () {
      final game = testGame();
      game.guess('abbey');

      expect(game.didWin, isTrue);
      expect(game.didLose, isFalse);
      expect(game.isOver, isTrue);
    });

    test('using every guess without winning sets didLose', () {
      final game = Game(
        wordList: testWordList(
          answers: const ['abbey'],
          allowed: const ['crush', 'yards', 'babes', 'scllb'],
        ),
        seed: 0,
      );
      for (final guess in ['crush', 'yards', 'babes', 'scllb', 'yards', 'babes']) {
        game.guess(guess);
      }

      expect(game.didWin, isFalse);
      expect(game.didLose, isTrue);
      expect(game.isOver, isTrue);
      expect(game.guessesRemaining, 0);
      expect(game.activeIndex, -1);
    });

    test('throws once no guesses remain', () {
      final game = testGame(maxGuesses: 1);
      game.guess('yards');

      expect(() => game.guess('crush'), throwsStateError);
    });
  });

  group('Game.isLegalGuess', () {
    final game = testGame();

    test('accepts a word from the list', () {
      expect(game.isLegalGuess('yards'), isTrue);
    });

    test('accepts the hidden word itself', () {
      expect(game.isLegalGuess('abbey'), isTrue);
    });

    test('ignores case', () {
      expect(game.isLegalGuess('YARDS'), isTrue);
    });

    test('rejects a word that is not listed', () {
      expect(game.isLegalGuess('house'), isFalse);
    });

    test('rejects a word of the wrong length without throwing', () {
      expect(game.isLegalGuess('yard'), isFalse);
      expect(game.isLegalGuess('yardss'), isFalse);
    });
  });

  group('Game.matchGuessOnly', () {
    test('evaluates without advancing the game', () {
      final game = testGame();

      expect(game.matchGuessOnly('yards').toString(), 'yards');
      expect(game.previousGuess.isEmpty, isTrue);
      expect(game.activeIndex, 0);
      expect(game.guessesRemaining, Game.defaultMaxGuesses);
    });
  });

  group('Game.keyStates', () {
    test('is empty before any guess', () {
      expect(testGame().keyStates, isEmpty);
    });

    test('records every result of the latest guess', () {
      final game = testGame(allowed: const ['yards', 'babes', 'crush']);
      game.guess('yards');

      expect(game.keyStates['y'], HitType.partial);
      expect(game.keyStates['a'], HitType.partial);
      expect(game.keyStates['r'], HitType.miss);
    });

    test('upgrades a letter to the better result it earns later', () {
      final game = testGame(allowed: const ['yards', 'babes']);
      game.guess('yards'); // 'a' is a partial
      expect(game.keyStates['a'], HitType.partial);

      game.guess('babes'); // 'a' is still a partial, 'b' and 'e' are hits
      expect(game.keyStates['a'], HitType.partial);
      expect(game.keyStates['b'], HitType.hit);
      expect(game.keyStates['e'], HitType.hit);
    });

    test('never downgrades a hit to a later miss', () {
      // 'lllll' against 'belle' claims both hidden 'l' letters as hits, so
      // the three 'l' letters left over in that same guess are misses.
      final game = testGame(
        answers: const ['belle'],
        allowed: const ['yards', 'lllll'],
      );
      game.guess('yards');
      expect(game.keyStates.containsKey('l'), isFalse);

      game.guess('lllll');
      final guess = game.previousGuess;
      expect(guess[0].type, HitType.miss);
      expect(guess[2].type, HitType.hit);
      expect(guess[4].type, HitType.miss);
      expect(game.keyStates['l'], HitType.hit);

      // A later guess that misses entirely leaves the best result standing.
      game.guess('yards');
      expect(game.keyStates['l'], HitType.hit);
      expect(game.keyStates['y'], HitType.miss);
    });
  });

  group('Game.guesses', () {
    test('is an unmodifiable view', () {
      expect(
        () => testGame().guesses.add(Word.fromString('abbey')),
        throwsUnsupportedError,
      );
    });
  });

  group('Game.resetGame', () {
    test('clears every submitted guess and key state', () {
      final game = testGame();
      game.guess('yards');
      game.guess('crush');

      game.resetGame();

      expect(game.previousGuess.isEmpty, isTrue);
      expect(game.activeIndex, 0);
      expect(game.guessesRemaining, Game.defaultMaxGuesses);
      expect(game.didWin, isFalse);
      expect(game.didLose, isFalse);
      expect(game.guesses.every((word) => word.isEmpty), isTrue);
      expect(game.keyStates, isEmpty);
    });

    test('picks a hidden word from the answers again', () {
      final game = Game(
        wordList: testWordList(answers: const ['abbey', 'babes']),
        seed: 3,
      );
      final original = game.hiddenWord.toString();
      game.guess('yards');

      game.resetGame();

      expect(['abbey', 'babes'], contains(game.hiddenWord.toString()));
      expect(original, isNotEmpty);
    });
  });
}
