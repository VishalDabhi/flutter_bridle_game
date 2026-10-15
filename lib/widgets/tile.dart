import 'dart:math' as math;

import 'package:bk_lottery/game.dart';
import 'package:bk_lottery/theme.dart';
import 'package:flutter/material.dart';

/// The space around a [Tile] that separates it from its neighbours.
const double tilePadding = 3;

/// One letter box that flips to reveal its [HitType].
class Tile extends StatelessWidget {
  /// Creates a tile showing [letter], scored as [type].
  ///
  /// While [revealed] is false the tile shows the letter on an empty
  /// background. Once it turns true the tile flips and shows [type].
  const Tile({
    required this.letter,
    required this.type,
    required this.revealed,
    required this.size,
    required this.flipDuration,
    super.key,
  });

  /// The character this tile holds, or an empty string for a blank tile.
  final String letter;

  /// How this tile scored against the hidden word.
  final HitType type;

  /// Whether the flip that shows [type] has run.
  final bool revealed;

  /// The width and height of the tile.
  final double size;

  /// How long the flip takes.
  final Duration flipDuration;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(tilePadding),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: revealed ? 1 : 0),
        duration: flipDuration,
        curve: Curves.easeInOut,
        builder: (context, progress, _) {
          final angle = progress * math.pi;
          final showingResult = angle >= math.pi / 2;
          // Full height while hidden, edge-on halfway through the flip, and
          // full height again once the result is showing.
          final scaleY = (2 * progress - 1).abs().clamp(0.0, 1.0);

          return Transform.scale(
            scaleY: scaleY,
            child: _face(showingResult ? type : HitType.none),
          );
        },
      ),
    );
  }

  Widget _face(HitType shown) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: tileFill(shown),
          border: Border.all(color: tileBorder(shown), width: 2),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          letter.toUpperCase(),
          style: TextStyle(
            color: tileTextColor(shown),
            fontSize: size * 0.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
}
