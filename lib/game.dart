/// Game logic and supporting types for Birdle,
/// a five-letter word-guessing game similar to Wordle.
///
/// Defines the [Game] state machine and the
/// [Word], [Letter], and [HitType] data model used to
/// represent guesses and their evaluation against a hidden word.
///
/// This library is deliberately free of Flutter imports so it can be reused
/// and tested without a widget layer.
library;

import 'dart:collection';
import 'dart:math';

import 'package:bk_lottery/word_list.dart';

/// The result of evaluating a [Letter] of a guess against the hidden word.
enum HitType {
  /// The letter hasn't yet been evaluated.
  none,

  /// The letter matches the hidden word's letter at the same position.
  hit,

  /// The letter is in the hidden word, but at a different position.
  partial,

  /// The letter doesn't appear in the hidden word.
  miss,
}

/// A single character paired with its [HitType] against the hidden word.
typedef Letter = ({String char, HitType type});

/// How strongly a [HitType] claims a letter when results are merged.
///
/// A letter's best result across every guess wins, so a later [HitType.miss]
/// can never downgrade an earlier [HitType.hit].
int _rank(HitType type) => switch (type) {
      HitType.hit => 3,
      HitType.partial => 2,
      HitType.miss => 1,
      HitType.none => 0,
    };

/// Game state of a single round of Birdle,
/// a five-letter word-guessing game similar to Wordle.
///
/// Exposes the state and methods a UI needs to
/// evaluate guesses and track progress,
/// but doesn't advance play on its own.
///
/// Clients drive each round by calling [guess] to submit an attempt and
/// [resetGame] to start over.
class Game {
  /// The default maximum number of guesses allowed in a [Game].
  static const int defaultMaxGuesses = 6;

  /// Creates a new game with [maxGuesses] guesses allowed.
  ///
  /// The hidden word is chosen at random from [wordList.answers].
  /// Passing [seed], or a [random] built from one, makes that choice
  /// reproducible for tests.
  Game({
    required this.wordList,
    this.maxGuesses = defaultMaxGuesses,
    this.seed,
    Random? random,
  })  : assert(maxGuesses > 0, 'A game needs room for at least one guess.'),
        _random = random ?? (seed == null ? Random() : Random(seed)),
        _guesses = List<Word>.filled(maxGuesses, Word.empty()) {
    _wordToGuess = _pickHiddenWord();
  }

  /// The vocabulary this game draws its words from.
  final WordList wordList;

  /// The maximum number of guesses allowed in this game.
  final int maxGuesses;

  /// The seed used to choose the hidden word,
  /// or `null` if it was chosen without one.
  final int? seed;

  final Random _random;

  /// The current hidden word, exposed publicly through [hiddenWord].
  late Word _wordToGuess;

  /// Backing storage for [guesses].
  ///
  /// Holds every guess slot in order,
  /// with unfilled slots represented by empty [Word]s.
  late List<Word> _guesses;

  /// Backing storage for [keyStates].
  late final Map<String, HitType> _keyStates = {};

  /// The word the player is trying to guess.
  Word get hiddenWord => _wordToGuess;

  /// An unmodifiable view of every guess slot, including those still empty.
  UnmodifiableListView<Word> get guesses => UnmodifiableListView(_guesses);

  /// The best result every guessed letter has earned so far.
  ///
  /// Used to colour the on-screen keyboard. Letters that were never guessed
  /// are absent from the map.
  UnmodifiableMapView<String, HitType> get keyStates =>
      UnmodifiableMapView(_keyStates);

  /// The most recently submitted guess,
  /// or an empty [Word] if no guesses have been made.
  Word get previousGuess {
    final index = _guesses.lastIndexWhere((word) => word.isNotEmpty);
    return index == -1 ? Word.empty() : _guesses[index];
  }

  /// The index of the next empty guess slot, or `-1` if every slot is full.
  int get activeIndex => _guesses.indexWhere((word) => word.isEmpty);

  /// The number of guesses still available to the player.
  int get guessesRemaining {
    if (activeIndex == -1) return 0;
    return maxGuesses - activeIndex;
  }

  /// Whether the most recent guess matches the hidden word.
  bool get didWin {
    if (_guesses.first.isEmpty) return false;

    for (final letter in previousGuess) {
      if (letter.type != HitType.hit) return false;
    }

    return true;
  }

  /// Whether all allowed guesses have been used without winning.
  bool get didLose => guessesRemaining == 0 && !didWin;

  /// Whether the round is over, either by a win or by running out of guesses.
  bool get isOver => didWin || didLose;

  /// Picks a new hidden word and clears every submitted guess.
  void resetGame() {
    _wordToGuess = _pickHiddenWord();
    _guesses = List<Word>.filled(maxGuesses, Word.empty());
    _keyStates.clear();
  }

  /// Evaluates [guess] against the hidden word,
  /// records the result in [guesses], and returns it.
  ///
  /// For finer control, use [isLegalGuess] to validate input or
  /// [matchGuessOnly] to evaluate without recording the result.
  Word guess(String guess) {
    final result = matchGuessOnly(guess);
    addGuessToList(result);
    return result;
  }

  /// Whether [guess] is a legal word to guess.
  ///
  /// UIs can call this method before [guess] to
  /// show players a message when they enter an invalid word.
  bool isLegalGuess(String guess) =>
      guess.length == Word.wordLength &&
      wordList.contains(guess.toLowerCase());

  /// Evaluates [guess] against the hidden word without advancing the game.
  Word matchGuessOnly(String guess) =>
      Word.fromString(guess.toLowerCase()).evaluateGuess(_wordToGuess);

  /// Stores [guess] in the next empty slot of [guesses].
  void addGuessToList(Word guess) {
    final guessIndex = activeIndex;
    if (guessIndex == -1) {
      throw StateError('No guesses remaining.');
    }

    _guesses[guessIndex] = guess;
    _recordKeyStates(guess);
  }

  /// Folds [guess] into [keyStates], keeping each letter's best result.
  void _recordKeyStates(Word guess) {
    for (final letter in guess) {
      if (letter.char.isEmpty) continue;

      final current = _keyStates[letter.char];
      if (current == null || _rank(letter.type) > _rank(current)) {
        _keyStates[letter.char] = letter.type;
      }
    }
  }

  /// Returns the starting hidden word for a new round.
  Word _pickHiddenWord() {
    final answers = wordList.answers;
    if (answers.isEmpty) {
      throw StateError('WordList.answers is empty, so no round can be played.');
    }

    return Word.fromString(answers[_random.nextInt(answers.length)]);
  }
}

/// A five-letter word made up of [Letter]s, each tracking its [HitType].
class Word with IterableMixin<Letter> {
  /// The exact number of letters every [Word] holds.
  static const int wordLength = 5;

  /// Creates a word backed by the specified list of [Letter]s.
  Word(this._letters);

  /// Creates a word with five blank letters of [HitType.none].
  factory Word.empty() =>
      Word(List<Letter>.filled(wordLength, (char: '', type: HitType.none)));

  /// Creates a [Word] from [guess].
  ///
  /// Each character is lowercased,
  /// every [Letter] starts as [HitType.none].
  factory Word.fromString(String guess) {
    if (guess.length != wordLength) {
      throw ArgumentError.value(
        guess,
        'guess',
        'Must be exactly $wordLength characters long.',
      );
    }

    final letters = guess
        .toLowerCase()
        .split('')
        .map((char) => (char: char, type: HitType.none))
        .toList();
    return Word(letters);
  }

  /// An unmodifiable list of [Letter]s that make up this word.
  final List<Letter> _letters;

  @override
  Iterator<Letter> get iterator => _letters.iterator;

  /// Whether every [Letter] in this word has no character.
  @override
  bool get isEmpty => every((letter) => letter.char.isEmpty);

  @override
  int get length => _letters.length;

  /// The [Letter] at index [i] in word.
  Letter operator [](int i) => _letters[i];

  @override
  String toString() => _letters.map((letter) => letter.char).join().trim();

  /// Returns a multi-line string showing each [Letter] alongside its [HitType].
  ///
  /// Used to play the game from the command line.
  String toStringVerbose() => _letters
      .map((letter) => '${letter.char} - ${letter.type.name}')
      .join('\n');
}

/// Guess-evaluation logic on [Word].
extension WordUtils on Word {
  /// Compares this [Word] against the specified [hiddenWord]
  /// and returns a new [Word] with the same letters,
  /// but where each [Letter] has new a [HitType] of
  /// [HitType.hit], [HitType.partial], or [HitType.miss].
  Word evaluateGuess(Word hiddenWord) {
    assert(length == hiddenWord.length, 'Both words must be the same length.');

    final result = List<Letter>.filled(length, (char: '', type: HitType.none));
    // Counts hidden-word letters that can still be claimed as partial matches.
    final unmatchedHiddenLetterCounts = <String, int>{};

    // Reserve exact matches before scoring partial matches.
    for (var i = 0; i < length; i++) {
      final guessChar = this[i].char;
      final hiddenChar = hiddenWord[i].char;

      if (guessChar == hiddenChar) {
        result[i] = (char: guessChar, type: HitType.hit);
      } else {
        // Track non-hit hidden letters for the partial-match pass.
        final unmatchedCount = unmatchedHiddenLetterCounts[hiddenChar] ?? 0;
        unmatchedHiddenLetterCounts[hiddenChar] = unmatchedCount + 1;
      }
    }

    // Spend each remaining hidden letter only once for partial matches.
    for (var i = 0; i < length; i++) {
      if (result[i].type == HitType.hit) continue;

      final guessChar = this[i].char;
      final unmatchedCount = unmatchedHiddenLetterCounts[guessChar] ?? 0;
      final isPartial = unmatchedCount > 0;
      if (isPartial) {
        // Use one available hidden letter for this partial match.
        unmatchedHiddenLetterCounts[guessChar] = unmatchedCount - 1;
      }

      result[i] = (
        char: guessChar,
        type: isPartial ? HitType.partial : HitType.miss,
      );
    }

    return Word(result);
  }
}
