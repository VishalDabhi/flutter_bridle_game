/// The vocabulary a [Game] plays with.
///
/// A [WordList] splits the words it knows into two groups: the [answers] that
/// can be chosen as the hidden word, and the [guesses] that are legal to
/// submit. The real lists ship as JSON assets and are loaded by
/// [AssetWordList]; tests and previews build an [InMemoryWordList] instead.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

/// The words a game may draw its hidden word from and accept as guesses.
abstract interface class WordList {
  /// Words that can be chosen as the hidden word.
  List<String> get answers;

  /// Every word that can legally be entered as a guess.
  ///
  /// Always a superset of [answers], so a hidden word is never rejected.
  List<String> get guesses;

  /// Whether [word] is present in [guesses], ignoring case.
  bool contains(String word);
}

/// A [WordList] backed by an in-memory list and a lookup set.
class InMemoryWordList implements WordList {
  /// Creates a list from [answers] and [allowed].
  ///
  /// [allowed] only needs to hold the words that are legal to guess but can
  /// never be the hidden word; it is merged with [answers] so that [guesses]
  /// is always a superset of [answers].
  InMemoryWordList({
    required List<String> answers,
    List<String> allowed = const [],
  })  : assert(
          answers.every(_isWord),
          'Every answer must be exactly five lowercase letters.',
        ),
        assert(
          allowed.every(_isWord),
          'Every allowed guess must be exactly five lowercase letters.',
        ),
        answers = List.unmodifiable(answers),
        guesses = List.unmodifiable(<String>{...answers, ...allowed}),
        _guessesLookup = <String>{...answers, ...allowed};

  @override
  final List<String> answers;

  @override
  final List<String> guesses;

  final Set<String> _guessesLookup;

  @override
  bool contains(String word) => _guessesLookup.contains(word.toLowerCase());

  static bool _isWord(String word) => RegExp(r'^[a-z]{5}$').hasMatch(word);
}

/// A [WordList] backed by the JSON word lists bundled with the app.
///
/// The lists are fetched once per process and cached, so calling [load] again
/// returns the same instance without touching the asset bundle again.
class AssetWordList extends InMemoryWordList {
  AssetWordList._({required super.answers, required super.allowed});

  /// Asset holding the words that can be chosen as the hidden word.
  static const String answersAsset = 'assets/words/answers.json';

  /// Asset holding every word that can legally be guessed.
  static const String guessesAsset = 'assets/words/allowed.json';

  static AssetWordList? _cache;

  /// Loads the bundled word lists, reusing the previous result when possible.
  ///
  /// Pass [bundle] to read the assets from somewhere other than [rootBundle],
  /// which is how tests point the loader at prepared JSON.
  static Future<AssetWordList> load({AssetBundle? bundle}) async {
    final cached = _cache;
    if (cached != null) return cached;

    final loader = bundle ?? rootBundle;
    final answers = await _decodeWords(loader, answersAsset);
    final allowed = await _decodeWords(loader, guessesAsset);
    final wordList =
        AssetWordList._(answers: answers, allowed: allowed);
    if (wordList.answers.isEmpty) {
      throw StateError('$answersAsset is empty, so no round can be played.');
    }

    return _cache = wordList;
  }

  /// Clears the cached lists, so the next [load] reads the assets again.
  static void debugClearCache() => _cache = null;

  static Future<List<String>> _decodeWords(
    AssetBundle bundle,
    String asset,
  ) async {
    final decoded = json.decode(await bundle.loadString(asset));
    if (decoded is! List) {
      throw FormatException('$asset must hold a JSON list of words.');
    }

    return decoded.cast<String>().toList();
  }
}
