import 'package:bk_lottery/theme.dart';
import 'package:flutter/material.dart';

/// The panel shown instead of the keyboard once a round is over.
class ResultPanel extends StatelessWidget {
  /// Creates a panel describing how [hiddenWord] was guessed.
  const ResultPanel({
    required this.didWin,
    required this.attempts,
    required this.hiddenWord,
    required this.onContinue,
    super.key,
  });

  /// Whether the round was won.
  final bool didWin;

  /// How many guesses it took.
  final int attempts;

  /// The word that was hidden.
  final String hiddenWord;

  /// Called to advance after a win or retry after a loss.
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: BirdleColors.toast,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                didWin ? 'You won!' : 'Out of guesses',
                style: const TextStyle(
                  color: BirdleColors.ink,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                didWin
                    ? 'Solved in ${_ordinal(attempts)}.'
                    : 'The word was ${hiddenWord.toUpperCase()}.',
                style: const TextStyle(color: Color(0xFF6A6A6A), fontSize: 15),
              ),
              const SizedBox(height: 18),
              PlayAgainButton(
                onPressed: onContinue,
                label: didWin ? 'Next Level' : 'Try Again',
                icon: didWin ? Icons.arrow_forward : Icons.refresh,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _ordinal(int attempts) => switch (attempts) {
        1 => '1 try',
        2 => '2 tries',
        3 => '3 tries',
        _ => '$attempts tries',
      };
}

/// The primary button shown once the current round is over.
class PlayAgainButton extends StatelessWidget {
  /// Creates a button that calls [onPressed] when tapped.
  const PlayAgainButton({
    required this.onPressed,
    this.label = 'Play Again',
    this.icon = Icons.refresh,
    super.key,
  });

  /// Called when the player continues.
  final VoidCallback onPressed;

  /// Text shown on the button.
  final String label;

  /// Icon shown before [label].
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: BirdleColors.hit,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}
