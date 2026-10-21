/// The UI-facing controller that drives one round of Birdle.
library;

import 'dart:collection';

import 'package:bk_lottery/game.dart';
import 'package:bk_lottery/hints.dart';
import 'package:flutter/widgets.dart';

/// Why [GameController.submit] accepted or rejected a guess.
enum SubmitStatus {
  /// The guess was scored and recorded.
  accepted,

  /// Fewer than five letters had been typed.
  tooShort,

  /// The five letters don't spell a word the game accepts.
  notInList,

  /// The round is already won or lost.
  roundOver,
}

/// Why [GameController.useHint] did what it did.
enum HintStatus {
  /// The word's meaning was shown.
  described,

  /// No safe meaning was left to show, so a letter was revealed instead.
  revealedLetter,

  /// Every letter is already on the board, so there is nothing left to give.
  unavailable,

  /// The cooldown since the last hint has not run out yet.
  coolingDown,

  /// This round's hint limit was reached.
  limitReached,
}

/// A [HintBook] with nothing in it, used when no clues are available.
class _NoHints implements HintBook {
  const _NoHints();

  @override
  String? descriptionOf(String word) => null;
}

/// Owns the [Game] for the current round and the letters being typed.
///
/// Holds the text the player is entering so the on-screen keyboard and a
/// physical keyboard stay in sync: both write into [text], and listeners
/// rebuild the board and keys from it.
class GameController extends ChangeNotifier {
  /// Creates a controller around [game].
  GameController({
    required this.game,
    this.hintBook = const _NoHints(),
    this.hintCooldown = defaultHintCooldown,
    this.hintLimit,
    this.clock = DateTime.now,
  }) {
    text.addListener(notifyListeners);
  }

  /// How long a hint stays unavailable after it is used.
  static const Duration defaultHintCooldown = Duration(seconds: 60);

  /// The round this controller drives.
  final Game game;

  /// Where clues for the hidden word come from.
  final HintBook hintBook;

  /// How long a spent hint takes to come back.
  final Duration hintCooldown;

  /// The most hints one round allows, or `null` for no limit.
  final int? hintLimit;

  /// Reads the current time, so tests can drive the hint cooldown.
  final DateTime Function() clock;

  /// The letters typed so far, which the hidden text field mirrors.
  final TextEditingController text = TextEditingController();

  bool _isRevealing = false;
  String? _hintText;
  DateTime? _hintReadyAt;
  int _hintsUsed = 0;
  int? _lastHintColumn;
  final Map<int, Set<int>> _hintLetters = {};

  /// The letters typed so far.
  String get input => text.text;

  /// Whether the latest guess is still flipping into place.
  bool get isRevealing => _isRevealing;

  /// Whether the player may type another letter.
  bool get canType => !game.isOver && !_isRevealing;

  /// Whether the typed letters can be submitted.
  bool get canSubmit => canType && input.length == Word.wordLength;

  /// How many guesses have been scored this round.
  int get guessesUsed => game.guesses.where((word) => word.isNotEmpty).length;

  /// How many hints have been spent this round.
  int get hintsUsed => _hintsUsed;

  /// When the next hint becomes available, or `null` when one is ready now.
  DateTime? get hintReadyAt => _hintReadyAt;

  /// The clue shown for the hidden word, if there is one.
  String? get hintText => _hintText;

  /// Every letter a hint has revealed, keyed by the board row it sits in.
  ///
  /// A hint reveals a letter on the row the player is filling, so it must
  /// remember that row rather than painting it across the whole board.
  Map<int, Set<int>> get hintLetters => {
    for (final entry in _hintLetters.entries)
      entry.key: UnmodifiableSetView(entry.value),
  };

  /// How long until the next hint is ready, or [Duration.zero] right now.
  Duration get hintCooldownRemaining {
    final readyAt = _hintReadyAt;
    if (readyAt == null) return Duration.zero;

    final left = readyAt.difference(clock());
    return left.isNegative ? Duration.zero : left;
  }

  /// Whether the hint button can still do something.
  bool get canHint =>
      !game.isOver &&
      !_isRevealing &&
      hintCooldownRemaining == Duration.zero &&
      (hintLimit == null || _hintsUsed < hintLimit!);

  /// The column the most recent hint revealed, if it revealed one.
  int? get lastHintColumn => _lastHintColumn;

  /// Spends a hint and explains what came back.
  ///
  /// The first hint of a round shows the word's meaning. After that the
  /// cooldown runs, and once it is over the hint falls back to revealing the
  /// next letter no guess has pinned down, so repeated hints keep helping
  /// without repeating themselves.
  HintStatus useHint() {
    if (game.isOver || _isRevealing) return HintStatus.limitReached;
    if (hintCooldownRemaining > Duration.zero) return HintStatus.coolingDown;
    if (hintLimit != null && _hintsUsed >= hintLimit!) {
      return HintStatus.limitReached;
    }

    _hintsUsed++;
    _hintReadyAt = clock().add(hintCooldown);
    _lastHintColumn = null;

    final clue =
        _hintText ?? SafeHint.describe(hintBook, game.hiddenWord.toString());
    // A clue is worth showing once. After that every hint gives up another
    // letter, so a repeated hint never just repeats itself.
    if (clue != null && _hintsUsed == 1) {
      _hintText = clue;
      notifyListeners();
      return HintStatus.described;
    }

    final revealedHere = _hintLetters[game.activeIndex] ?? const <int>{};
    final position = firstUnrevealedPosition(game, revealedHere);
    if (position != null) {
      _hintLetters.putIfAbsent(game.activeIndex, () => <int>{}).add(position);
      _lastHintColumn = position;
    }
    notifyListeners();

    return position == null ? HintStatus.unavailable : HintStatus.revealedLetter;
  }

  /// Appends [letter], ignoring anything that isn't a-z or would run past
  /// five letters.
  void type(String letter) {
    if (!canType) return;

    final next = input + letter.toLowerCase();
    if (next.length > Word.wordLength) return;
    if (!RegExp(r'^[a-z]*$').hasMatch(next)) return;

    text.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }

  /// Removes the last typed letter.
  void backspace() {
    if (!canType || input.isEmpty) return;

    final next = input.substring(0, input.length - 1);
    text.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }

  /// Scores the typed letters, clearing them on success.
  SubmitStatus submit() {
    if (game.isOver || _isRevealing) return SubmitStatus.roundOver;
    if (input.length != Word.wordLength) return SubmitStatus.tooShort;
    if (!game.isLegalGuess(input)) return SubmitStatus.notInList;

    game.guess(input);
    text.clear();
    return SubmitStatus.accepted;
  }

  /// Blocks typing while the latest guess is revealed.
  void beginReveal() {
    if (_isRevealing) return;

    _isRevealing = true;
    notifyListeners();
  }

  /// Unblocks typing once the latest guess has been revealed.
  void endReveal() {
    if (!_isRevealing) return;

    _isRevealing = false;
    notifyListeners();
  }

  /// Starts a fresh round with a new hidden word and an empty input.
  void reset() {
    game.resetGame();
    text.clear();
    _hintsUsed = 0;
    _hintText = null;
    _hintReadyAt = null;
    _lastHintColumn = null;
    _hintLetters.clear();
    if (!_isRevealing) return;

    _isRevealing = false;
    notifyListeners();
  }

  @override
  void dispose() {
    text.removeListener(notifyListeners);
    text.dispose();
    super.dispose();
  }
}
