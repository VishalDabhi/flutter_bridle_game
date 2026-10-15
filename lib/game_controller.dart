/// The UI-facing controller that drives one round of Birdle.
library;

import 'package:bk_lottery/game.dart';
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

/// Owns the [Game] for the current round and the letters being typed.
///
/// Holds the text the player is entering so the on-screen keyboard and a
/// physical keyboard stay in sync: both write into [text], and listeners
/// rebuild the board and keys from it.
class GameController extends ChangeNotifier {
  /// Creates a controller around [game].
  GameController({required this.game}) {
    text.addListener(notifyListeners);
  }

  /// The round this controller drives.
  final Game game;

  /// The letters typed so far, which the hidden text field mirrors.
  final TextEditingController text = TextEditingController();

  bool _isRevealing = false;

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
