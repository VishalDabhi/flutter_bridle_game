import 'dart:math' as math;

import 'package:bk_lottery/game.dart';
import 'package:bk_lottery/widgets/tile.dart';
import 'package:flutter/material.dart';

/// A horizontal shake played every time [play] changes.
///
/// Wraps a [child] and nudges it left and right, so a rejected guess reads as
/// the board refusing the word.
class Shake extends StatelessWidget {
  /// Creates a shake that replays whenever [play] increases.
  const Shake({
    required this.play,
    required this.child,
    this.amplitude = 10,
    super.key,
  });

  /// Bumping this integer replays the shake.
  final int play;

  /// What to shake.
  final Widget child;

  /// How far the child travels at its widest, in logical pixels.
  final double amplitude;

  @override
  Widget build(BuildContext context) {
    if (play <= 0) return child;

    return TweenAnimationBuilder<double>(
      key: ValueKey(play),
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      builder: (context, progress, child) => Transform.translate(
        offset: Offset(
          math.sin(progress * math.pi * 4) * amplitude * (1 - progress),
          0,
        ),
        child: child,
      ),
      child: child,
    );
  }
}

/// The grid of guess slots, one row per allowed guess.
class Board extends StatelessWidget {
  /// Creates a board for [game].
  const Board({
    required this.game,
    required this.draft,
    required this.hintLetters,
    required this.activeIndex,
    required this.revealedRow,
    required this.revealedTiles,
    required this.step,
    required this.shake,
    super.key,
  });

  /// The round being displayed.
  final Game game;

  /// The letters typed so far, shown on the row being filled.
  final String draft;

  /// The letters spent hints have revealed, keyed by board row.
  final Map<int, Set<int>> hintLetters;

  /// Index of the row the player is currently filling, or `-1` when the round
  /// is over.
  final int activeIndex;

  /// Index of the row currently flipping, or `-1` when nothing is flipping.
  ///
  /// Rows before it have finished flipping and keep their result.
  final int revealedRow;

  /// How many tiles of [revealedRow] have finished flipping, from 0 to five.
  final int revealedTiles;

  /// The delay between two consecutive tile flips.
  final Duration step;

  /// Bumped to replay the shake after a rejected guess.
  final int shake;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const padding = 8.0;
        const gap = 6.0;
        final rows = game.maxGuesses;
        // Fit the grid to whichever axis is tighter, so a short window or a
        // landscape phone shrinks the tiles instead of overflowing. Each tile
        // is [size] wide plus its own padding, and the last row carries no gap.
        final byWidth = (math.min(constraints.maxWidth, 420.0) -
                padding * 2 -
                Word.wordLength * tilePadding * 2) /
            Word.wordLength;
        final byHeight = (constraints.maxHeight -
                padding * 2 -
                rows * tilePadding * 2 -
                (rows - 1) * gap) /
            rows;
        final size = math.min(byWidth, byHeight).clamp(20.0, 76.0);

        return Center(
          child: Shake(
            play: shake,
            child: Padding(
              padding: const EdgeInsets.all(padding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var row = 0; row < rows; row++)
                    Padding(
                      padding: EdgeInsets.only(bottom: row == rows - 1 ? 0 : gap),
                      child: _Row(
                        game: game,
                        draft: draft,
                        hintLetters: hintLetters,
                        index: row,
                        size: size,
                        step: step,
                        isActive: row == activeIndex,
                        revealedRow: revealedRow,
                        revealedTiles: revealedTiles,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.game,
    required this.draft,
    required this.hintLetters,
    required this.index,
    required this.size,
    required this.step,
    required this.isActive,
    required this.revealedRow,
    required this.revealedTiles,
  });

  final Game game;
  final String draft;
  final Map<int, Set<int>> hintLetters;
  final int index;
  final double size;
  final Duration step;
  final bool isActive;
  final int revealedRow;
  final int revealedTiles;

  @override
  Widget build(BuildContext context) {
    final guess = game.guesses[index];
    // The row being filled shows the letters typed so far, padded with blanks;
    // a row that has been submitted shows its scored letters; the rest stay
    // blank.
    final letters = guess.isEmpty
        ? isActive
            ? [
                for (var i = 0; i < Word.wordLength; i++)
                  if (i < draft.length) draft[i] else '',
              ]
            : List<String>.filled(Word.wordLength, '')
        : guess.map((letter) => letter.char).toList();
    // Once the round is over the answer is spelled out in the empty rows.
    final revealAnswer = game.isOver && guess.isEmpty;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: isActive ? 0.92 : 1, end: isActive ? 1 : 0.92),
      duration: step * 2,
      curve: Curves.easeOut,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var column = 0; column < Word.wordLength; column++)
            Tile(
              key: ValueKey('tile-$index-$column'),
              letter: switch ((revealAnswer,
                  hintLetters[index]?.contains(column) ?? false)) {
                (true, _) => game.hiddenWord[column].char,
                (_, true) => game.hiddenWord[column].char,
                (_, _) => letters[column],
              },
              type: guess.isEmpty ? HitType.none : guess[column].type,
              revealed: index < revealedRow ||
                  (index == revealedRow && column < revealedTiles),
              size: size,
              flipDuration: step * 3,
            ),
        ],
      ),
    );
  }
}
