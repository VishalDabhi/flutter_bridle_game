import 'dart:async';

import 'package:bk_lottery/game.dart';
import 'package:bk_lottery/game_controller.dart';
import 'package:bk_lottery/word_list.dart';
import 'package:bk_lottery/widgets/board.dart';
import 'package:bk_lottery/widgets/guess_input.dart';
import 'package:bk_lottery/widgets/keyboard.dart';
import 'package:bk_lottery/widgets/result_panel.dart';
import 'package:flutter/material.dart';

/// The playable board, the keyboard, and everything in between.
class GamePage extends StatefulWidget {
  /// Creates a page that plays a round drawn from [wordList].
  ///
  /// [seed] makes the hidden word reproducible, and [step] controls how long
  /// the tile flip cascade takes; tests pass a zero [step] to skip it.
  const GamePage({
    required this.wordList,
    this.seed,
    this.step = const Duration(milliseconds: 120),
    super.key,
  });

  /// The vocabulary the round is drawn from.
  final WordList wordList;

  /// The seed for the hidden word, or `null` to choose at random.
  final int? seed;

  /// The delay between two consecutive tile flips.
  final Duration step;

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late final GameController _controller;
  final FocusNode _focusNode = FocusNode();

  Timer? _revealTimer;
  int _revealedRow = -1;
  int _revealedTiles = 0;
  int _shake = 0;

  @override
  void initState() {
    super.initState();
    _controller = GameController(
      game: Game(wordList: widget.wordList, seed: widget.seed),
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
        _startReveal();
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

  /// Starts a new round with a fresh board and keyboard.
  void _onPlayAgain() {
    _revealTimer?.cancel();
    _clearToast();
    setState(() {
      _revealedRow = -1;
      _revealedTiles = 0;
      _shake = 0;
    });
    _controller.reset();
    // Disabling the field at the end of a round drops focus, so take it back
    // once the rebuilt field is enabled again.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  /// Shows [message] as a toast, replacing any toast already on screen.
  void _showToast(String message, {bool persist = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), persist: persist));
  }

  void _clearToast() => ScaffoldMessenger.of(context).clearSnackBars();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final game = _controller.game;

        return Column(
          children: [
            Expanded(
              child: Board(
                game: game,
                draft: _controller.input,
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
                onPlayAgain: _onPlayAgain,
              )
            else
              Keyboard(
                keyStates: game.keyStates,
                canType: _controller.canType,
                canSubmit: _controller.canSubmit,
                canBackspace: _controller.canType && _controller.input.isNotEmpty,
                draftIsLegal:
                    _controller.input.length == Word.wordLength &&
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
        );
      },
    );
  }
}
