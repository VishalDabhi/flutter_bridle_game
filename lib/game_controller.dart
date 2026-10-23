/// The UI-facing controller that drives one round of Birdle.
library;

import 'dart:collection';
import 'dart:math';

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

  /// A letter was revealed on the board.
  revealedLetter,

  /// There is nothing left for the hint to show this round.
  unavailable,

  /// The cooldown since the last hint has not run out yet.
  coolingDown,

  /// This round's hint limit was reached.
  limitReached,

  /// The round is already over, so hints no longer apply.
  roundOver,

  /// The latest guess is still revealing, so hints wait for it.
  busy,
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
  ///
  /// Pass [random] to make the positions a hint reveals reproducible in tests.
  GameController({
    required this.game,
    this.hintBook = const _NoHints(),
    this.hintCooldown = defaultHintCooldown,
    this.hintLimit,
    this.clock = DateTime.now,
    Random? random,
  }) : _random = random ?? Random() {
    text.addListener(notifyListeners);
  }

  /// How long a hint stays unavailable after it is used.
  static const Duration defaultHintCooldown = Duration(seconds: 60);

  static const int _maxHintLetters = 2;

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

  final Random _random;

  /// The letters typed so far, which the hidden text field mirrors.
  final TextEditingController text = TextEditingController();

  bool _isRevealing = false;
  bool _lastHintWasClue = false;
  String? _hintText;
  DateTime? _hintReadyAt;
  int _hintsUsed = 0;
  int _hintLettersRevealed = 0;
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

  /// Whether a hint could still give the player something this round.
  ///
  /// The cooldown is deliberately left out: the hint button tracks it locally
  /// so a ticking countdown never rebuilds the board.
  bool get hintAvailable {
    if (game.isOver || _isRevealing) return false;
    if (hintLimit != null && _hintsUsed >= hintLimit!) return false;

    return _clue != null || _canRevealLetter;
  }

  /// Whether the hint button can be pressed right now.
  bool get canHint => hintAvailable && hintCooldownRemaining == Duration.zero;

  /// The column the most recent hint revealed, if it revealed one.
  int? get lastHintColumn => _lastHintColumn;

  /// The safe clue for the hidden word, or `null` when there isn't one.
  String? get _clue => SafeHint.describe(hintBook, game.hiddenWord.toString());

  /// Positions a new hint may reveal.
  ///
  /// Positions pinned down by a guess, already revealed by a hint on this row,
  /// or typed by the player are left out.
  List<int> get _revealablePositions {
    final revealedHere = _hintLetters[game.activeIndex] ?? const <int>{};
    final excluded = <int>{
      ...revealedHere,
      for (var i = 0; i < input.length; i++) i,
    };
    return [
      for (final position in unrevealedPositions(game))
        if (!excluded.contains(position)) position,
    ];
  }

  /// Whether another letter hint is still allowed this round.
  bool get _canRevealLetter =>
      _hintLettersRevealed < _maxHintLetters &&
      _revealablePositions.isNotEmpty;

  /// Spends a hint and explains what came back.
  ///
  /// The first hint shows the clue, the second reveals a random letter, the
  /// third shows the clue again, and the fourth reveals a second random
  /// letter. Once both letters are out, later hints repeat the clue. Words
  /// with no usable clue reveal one letter on each of the first two hints and
  /// then run out. A hint that cannot show anything is not spent.
  HintStatus useHint() {
    if (game.isOver) return HintStatus.roundOver;
    if (_isRevealing) return HintStatus.busy;
    if (hintCooldownRemaining > Duration.zero) return HintStatus.coolingDown;
    if (hintLimit != null && _hintsUsed >= hintLimit!) {
      return HintStatus.limitReached;
    }

    final clue = _clue;
    final positions = _revealablePositions;
    final canRevealLetter =
        _hintLettersRevealed < _maxHintLetters && positions.isNotEmpty;
    final wantsClue = !_lastHintWasClue;
    final showClue =
        wantsClue ? clue != null : clue != null && !canRevealLetter;
    final revealPosition = showClue || !canRevealLetter
        ? null
        : positions[_random.nextInt(positions.length)];

    if (!showClue && revealPosition == null) return HintStatus.unavailable;

    _hintsUsed++;
    _hintReadyAt = clock().add(hintCooldown);
    _lastHintWasClue = showClue;
    _lastHintColumn = revealPosition;

    if (showClue) {
      _hintText = clue;
      notifyListeners();
      return HintStatus.described;
    }

    _hintLettersRevealed++;
    _hintLetters
        .putIfAbsent(game.activeIndex, () => <int>{})
        .add(revealPosition!);
    notifyListeners();
    return HintStatus.revealedLetter;
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

    final row = game.activeIndex;
    game.guess(input);
    _hintLetters.remove(row);
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
    _hintLettersRevealed = 0;
    _lastHintWasClue = false;
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
