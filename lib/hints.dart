/// One-line clues for the hidden word.
///
/// [HintBook] looks up the meaning of a word, [SafeHint] rejects any clue that
/// would give the word away, and [unrevealedPositions] finds letters a hint
/// can reveal.
library;

import 'dart:convert';

import 'package:bk_lottery/game.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;

/// Clues for the words a game may hide.
abstract interface class HintBook {
  /// A short meaning of [word], or `null` when none is available.
  String? descriptionOf(String word);
}

/// A [HintBook] backed by an in-memory map.
class InMemoryHintBook implements HintBook {
  /// Creates a book from [hints], keyed by lowercase word.
  InMemoryHintBook(Map<String, String> hints)
      : _hints = {
          for (final entry in hints.entries)
            entry.key.toLowerCase(): entry.value,
        };

  /// A book that never has a clue, standing in for a missing asset.
  InMemoryHintBook.empty() : _hints = const {};

  final Map<String, String> _hints;

  @override
  String? descriptionOf(String word) => _hints[word.toLowerCase()];

  /// How many words this book can describe.
  int get length => _hints.length;
}

/// A [HintBook] backed by the JSON clues bundled with the app.
///
/// Loading never throws: a game with no clues still plays, it just falls back
/// to revealing a letter. That is the opposite of [AssetWordList], which must
/// fail loudly because the game cannot run without words.
class AssetHintBook extends InMemoryHintBook {
  AssetHintBook._(super.hints);

  /// Asset holding the clue for each word.
  static const String hintsAsset = 'assets/words/hints.json';

  static AssetHintBook? _cache;

  /// Loads the bundled clues, reusing the previous result when possible.
  ///
  /// Pass [bundle] to read the asset from somewhere other than [rootBundle].
  static Future<AssetHintBook> load({AssetBundle? bundle}) async {
    final cached = _cache;
    if (cached != null) return cached;

    try {
      final decoded =
          json.decode(await (bundle ?? rootBundle).loadString(hintsAsset));
      if (decoded is! Map) return _cache = AssetHintBook._(const {});
      return _cache = AssetHintBook._({
        for (final entry in decoded.entries)
          if (entry.key is String && entry.value is String)
            entry.key as String: entry.value as String,
      });
    } on Object {
      // A missing or corrupt clue file must not stop the game from starting.
      return _cache = AssetHintBook._(const {});
    }
  }

  /// Clears the cached clues, so the next [load] reads the asset again.
  static void debugClearCache() => _cache = null;
}

/// Guards against a clue that hands the player the answer.
abstract final class SafeHint {
  /// The clue for [word] from [book], or `null` when it is unusable.
  ///
  /// A clue that contains the word is dropped: the sense of `aback` reads
  /// "having the wind against the forward side of the sails", while another of
  /// its senses repeats the word itself.
  static String? describe(HintBook book, String word) {
    final description = book.descriptionOf(word);
    if (description == null || description.trim().isEmpty) return null;
    if (leaks(word, description)) return null;

    return description.trim();
  }

  /// Whether [description] spells out [word].
  ///
  /// Letters in order are deliberately not tested. Clues are sentences, and
  /// almost every sentence contains a five letter word's letters in order.
  static bool leaks(String word, String description) =>
      description.toLowerCase().contains(word.toLowerCase());
}

/// The positions no submitted guess has pinned down yet.
///
/// A letter counts as known once any guess marked it a hit or a partial, so
/// revealing one of the rest is as useful as it can be.
List<int> unrevealedPositions(Game game) => [
      for (var i = 0; i < Word.wordLength; i++)
        if (!game.guesses.any((guess) =>
            guess.length > i &&
            guess[i].type != HitType.none &&
            guess[i].type != HitType.miss))
          i,
    ];

/// The first position a hint can usefully reveal, or `null` once every letter
/// is known.
///
/// [excluded] holds positions earlier hints have given away or the player has
/// already typed, so repeated hints walk along the word instead of returning
/// the same letter or hiding something the player entered.
int? firstUnrevealedPosition(
  Game game, [
  Set<int> excluded = const {},
]) {
  for (final position in unrevealedPositions(game)) {
    if (!excluded.contains(position)) return position;
  }
  return null;
}
