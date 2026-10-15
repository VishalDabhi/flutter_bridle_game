import 'dart:convert';
import 'dart:io';

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

    final bytes = utf8.encode(value);
    return ByteData.view(Uint8List.fromList(bytes).buffer);
  }
}

void main() {
  setUp(AssetWordList.debugClearCache);
  tearDown(AssetWordList.debugClearCache);

  group('shipped word list assets', () {
    late List<String> answers;
    late List<String> guesses;

    setUpAll(() {
      answers = (json.decode(
        File(AssetWordList.answersAsset).readAsStringSync(),
      ) as List)
          .cast<String>();
      guesses = (json.decode(
        File(AssetWordList.guessesAsset).readAsStringSync(),
      ) as List)
          .cast<String>();
    });

    test('hold thousands of words', () {
      expect(answers.length, greaterThan(2000));
      expect(guesses.length, greaterThanOrEqualTo(answers.length));
    });

    test('hold only unique five-letter lowercase words', () {
      final word = RegExp(r'^[a-z]{5}$');

      for (final list in [answers, guesses]) {
        expect(list.where(word.hasMatch).length, list.length,
            reason: 'every entry must match ^[a-z]{5}\$');
        expect(list.toSet().length, list.length, reason: 'no duplicates');
      }
    });

    test('accept every possible hidden word as a guess', () {
      expect(guesses.toSet().containsAll(answers), isTrue);
    });

    test('start and end with plausible words', () {
      expect(answers, isNotEmpty);
      expect(guesses, isNotEmpty);
      expect(answers.first, matches(RegExp(r'^[a-z]{5}$')));
      expect(guesses.last, matches(RegExp(r'^[a-z]{5}$')));
    });
  });

  group('AssetWordList.load', () {
    test('reads both assets into one list', () async {
      final wordList = await AssetWordList.load(
        bundle: _MapAssetBundle({
          AssetWordList.answersAsset: '["abbey"]',
          AssetWordList.guessesAsset: '["abbey","yards"]',
        }),
      );

      expect(wordList.answers, ['abbey']);
      expect(wordList.guesses, containsAll(['abbey', 'yards']));
      expect(wordList.contains('YARDS'), isTrue);
      expect(wordList.contains('house'), isFalse);
    });

    test('caches the first result', () async {
      final bundle = _MapAssetBundle({
        AssetWordList.answersAsset: '["abbey"]',
        AssetWordList.guessesAsset: '["abbey","yards"]',
      });

      final first = await AssetWordList.load(bundle: bundle);
      final second = await AssetWordList.load(bundle: _MapAssetBundle({}));

      expect(identical(first, second), isTrue);
    });

    test('throws when an asset is not a JSON list', () async {
      await expectLater(
        AssetWordList.load(
          bundle: _MapAssetBundle({
            AssetWordList.answersAsset: '{"word":"abbey"}',
            AssetWordList.guessesAsset: '["abbey"]',
          }),
        ),
        throwsFormatException,
      );
    });

    test('throws when the answers are empty', () async {
      await expectLater(
        AssetWordList.load(
          bundle: _MapAssetBundle({
            AssetWordList.answersAsset: '[]',
            AssetWordList.guessesAsset: '["abbey"]',
          }),
        ),
        throwsStateError,
      );
    });

    test('throws when an asset is missing', () async {
      await expectLater(
        AssetWordList.load(bundle: _MapAssetBundle({})),
        throwsStateError,
      );
    });
  });

  group('InMemoryWordList', () {
    test('merges answers into the guess list', () {
      final wordList = InMemoryWordList(
        answers: const ['abbey'],
        allowed: const ['yards'],
      );

      expect(wordList.guesses, containsAll(['abbey', 'yards']));
      expect(wordList.contains('abbey'), isTrue);
      expect(wordList.contains('yards'), isTrue);
      expect(wordList.contains('house'), isFalse);
    });

    test('rejects malformed words in debug builds', () {
      expect(
        () => InMemoryWordList(answers: const ['ABBEY']),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => InMemoryWordList(answers: const ['abbe']),
        throwsA(isA<AssertionError>()),
      );
    });

    test('exposes unmodifiable views', () {
      final wordList = InMemoryWordList(answers: const ['abbey']);

      expect(() => wordList.answers.add('babes'), throwsUnsupportedError);
      expect(() => wordList.guesses.add('babes'), throwsUnsupportedError);
    });
  });
}
