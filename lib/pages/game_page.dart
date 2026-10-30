import 'dart:async';

import 'package:bk_lottery/game.dart';
import 'package:bk_lottery/game_controller.dart';
import 'package:bk_lottery/hints.dart';
import 'package:bk_lottery/level_config.dart';
import 'package:bk_lottery/level_store.dart';
import 'package:bk_lottery/word_list.dart';
import 'package:bk_lottery/widgets/board.dart';
import 'package:bk_lottery/widgets/clue_banner.dart';
import 'package:bk_lottery/widgets/guess_input.dart';
import 'package:bk_lottery/widgets/hint_button.dart';
import 'package:bk_lottery/widgets/keyboard.dart';
import 'package:bk_lottery/widgets/result_panel.dart';
import 'package:flutter/material.dart';

/// The playable board, the keyboard, and everything in between.
class GamePage extends StatefulWidget {
  /// Creates a page that plays a round drawn from [wordList].
  ///
  /// [levelStore] supplies the level to resume from and remembers the next
  /// one. [seed] makes the hidden word reproducible, [step] controls how long
  /// the tile flip cascade takes; tests pass a zero [step] to skip it.
  /// [hints] supplies clues for the hint button, and [hintLimit] caps how many
  /// hints a round allows. [hintCooldown] overrides the level's cooldown.
  const GamePage({
    required this.wordList,
    required this.levelStore,
    this.seed,
    this.step = const Duration(milliseconds: 120),
    this.hintCooldown,
    this.hintLimit,
    this.hints,
    super.key,
  });

  /// The vocabulary the round is drawn from.
  final WordList wordList;

  /// Remembers the level the next round should start at.
  final LevelStore levelStore;

  /// The seed for the hidden word, or `null` to choose at random.
  final int? seed;

  /// The delay between two consecutive tile flips.
  final Duration step;

  /// Overrides the level's hint cooldown when set.
  final Duration? hintCooldown;

  /// The most hints one round allows, or `null` for no limit.
  final int? hintLimit;

  /// Clues for the hint button, or `null` for none.
  final HintBook? hints;

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late GameController _controller;
  late int _level;
  final FocusNode _focusNode = FocusNode();

  Timer? _revealTimer;
  int _revealedRow = -1;
  int _revealedTiles = 0;
  int _shake = 0;

  LevelConfig get _levelConfig => LevelConfig.forLevel(_level);

  String? _resolveAutoClue(Game game) {
    final hintBook = widget.hints;
    if (hintBook == null) return null;
    final word = game.hiddenWord.toString();
    return SafeHint.describe(hintBook, word);
  }

  @override
  void initState() {
    super.initState();
    _level = widget.levelStore.currentLevel;
    _controller = _createController();
  }

  GameController _createController() {
    final config = _levelConfig;
    return GameController(
      game: Game(
        wordList: widget.wordList,
        maxGuesses: config.maxGuesses,
        seed: widget.seed,
      ),
      hintBook: widget.hints ?? InMemoryHintBook.empty(),
      hintCooldown: widget.hintCooldown ?? config.hintCooldown,
      hintLimit: widget.hintLimit,
    );
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onSubmit() {
    final typed = _controller.input;

    switch (_controller.submit()) {
      case SubmitStatus.accepted:
        if (_controller.game.didWin) {
          unawaited(_rememberNextLevel());
        }
        _startReveal();
        setState(() {});
      case SubmitStatus.tooShort:
        _reject('Guesses must be exactly ${Word.wordLength} letters.');
      case SubmitStatus.notInList:
        _reject("'$typed' isn't in the word list.");
      case SubmitStatus.roundOver:
        break;
    }
  }

  /// Shakes the board and explains why the guess was refused.
  void _reject(String message) {
    setState(() => _shake++);
    _showToast(message);
  }

  /// Flips the newest row in from left to right.
  void _startReveal() {
    final row = _controller.game.activeIndex - 1;
    _revealTimer?.cancel();
    setState(() {
      _revealedRow = row;
      _revealedTiles = 0;
    });
    _controller.beginReveal();

    // A zero step means the caller wants the board settled immediately.
    if (widget.step <= Duration.zero) {
      _finishReveal();
      return;
    }

    var revealed = 0;
    _revealTimer = Timer.periodic(widget.step, (timer) {
      revealed++;
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (revealed >= Word.wordLength) {
        timer.cancel();
        _revealTimer = null;
        _finishReveal();
        return;
      }

      setState(() => _revealedTiles = revealed);
    });
  }

  void _finishReveal() {
    setState(() => _revealedTiles = Word.wordLength);
    _controller.endReveal();
  }

  /// Saves the level that should be resumed after a win.
  Future<void> _rememberNextLevel() =>
      widget.levelStore.saveLevel(_level + 1);

  /// Starts the level after a win.
  void _onNextLevel() => _beginLevel(_level + 1);

  /// Replays the current level after a loss.
  void _onRetry() => _beginLevel(_level);

  /// Starts [level] with a fresh board and keyboard.
  void _beginLevel(int level) {
    _revealTimer?.cancel();
    _clearToast();
    final oldController = _controller;
    _level = level;
    _controller = _createController();
    setState(() {
      _revealedRow = -1;
      _revealedTiles = 0;
      _shake = 0;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      oldController.dispose();
      if (!mounted) return;
      _focusNode.requestFocus();
    });
  }

  /// Shows [message] as a toast, replacing any toast already on screen.
  void _showToast(String message, {bool persist = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), persist: persist));
  }

  void _clearToast() => ScaffoldMessenger.of(context).clearSnackBars();

  /// Spends a hint and explains what came back.
  void _onHint() {
    final status = _controller.useHint();
    showHintDialog(
      context,
      status: status,
      hiddenWord: _controller.game.hiddenWord.toString(),
      description: _controller.hintText,
      letterIndex: _controller.lastHintColumn,
      cooldownRemaining: _controller.hintCooldownRemaining,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final game = _controller.game;
        final autoClue = (widget.hints != null &&
                !game.isOver &&
                _controller.guessesUsed == 0)
            ? _resolveAutoClue(game)
            : null;
        final hasClueBanner = autoClue != null;

        return Scaffold(
          appBar: AppBar(
            leading: const Padding(
              padding: EdgeInsets.only(left: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Birdle',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            leadingWidth: 70,
            title: Text(
              '$_level/${_levelConfig.difficulty.label}',
              textAlign: TextAlign.center,
            ),
            centerTitle: true,
            actions: [
              HintButton(
                hintReadyAt: _controller.hintReadyAt,
                enabled: _controller.hintAvailable && !hasClueBanner,
                cooldownRemaining: _controller.hintCooldownRemaining,
                onPressed: _onHint,
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: Column(
            children: [
              if (hasClueBanner)
                ClueBanner(key: const ValueKey('auto-clue'), clue: autoClue),
              Expanded(
                child: Board(
                  game: game,
                  draft: _controller.input,
                  hintLetters: _controller.hintLetters,
                  activeIndex: game.isOver ? -1 : game.activeIndex,
                  revealedRow: _revealedRow,
                  revealedTiles: _revealedTiles,
                  step: widget.step,
                  shake: _shake,
                ),
              ),
              if (game.isOver)
                ResultPanel(
                  didWin: game.didWin,
                  attempts: _controller.guessesUsed,
                  hiddenWord: game.hiddenWord.toString(),
                  onContinue: game.didWin ? _onNextLevel : _onRetry,
                )
              else
                Keyboard(
                  keyStates: game.keyStates,
                  canType: _controller.canType,
                  canSubmit: _controller.canSubmit,
                  canBackspace:
                      _controller.canType && _controller.input.isNotEmpty,
                  draftIsLegal: _controller.input.length == Word.wordLength &&
                      game.isLegalGuess(_controller.input),
                  onLetter: _controller.type,
                  onBackspace: _controller.backspace,
                  onSubmit: _onSubmit,
                ),
              GuessInput(
                controller: _controller.text,
                focusNode: _focusNode,
                onSubmitted: _onSubmit,
                enabled: _controller.canType,
              ),
            ],
          ),
        );
      },
    );
  }
}
