import 'package:bk_lottery/theme.dart';
import 'package:flutter/material.dart';

/// A subtle banner shown above the board with the hidden word's clue.
class ClueBanner extends StatelessWidget {
  const ClueBanner({required this.clue, super.key});

  /// The safe clue text to display.
  final String clue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: BirdleColors.toast,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: SizedBox(
            width: double.infinity,
            child: Text(
              'Clue: $clue',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: BirdleColors.ink,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
