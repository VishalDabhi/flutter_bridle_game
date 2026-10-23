import 'dart:async';

import 'package:bk_lottery/game_controller.dart';
import 'package:bk_lottery/theme.dart';
import 'package:flutter/material.dart';

/// The button that spends a hint, with a countdown while one recharges.
///
/// It owns its own one second ticker rather than asking the controller to
/// notify every second, so a countdown never rebuilds the board or keyboard.
/// The clock is the controller's, so the countdown stays truthful if the app
/// is backgrounded.
class HintButton extends StatefulWidget {
  /// Creates a button that calls [onPressed] while a hint is available.
  const HintButton({
    required this.hintReadyAt,
    required this.enabled,
    required this.cooldownRemaining,
    required this.onPressed,
    super.key,
  });

  /// When the next hint becomes available, or `null` when one is ready.
  final DateTime? hintReadyAt;

  /// Whether the round allows a hint at all.
  final bool enabled;

  /// How long until the next hint is ready, sampled when the button builds.
  final Duration cooldownRemaining;

  /// Called to spend the hint.
  final VoidCallback onPressed;

  @override
  State<HintButton> createState() => _HintButtonState();
}

class _HintButtonState extends State<HintButton> {
  Timer? _ticker;
  late Duration _remaining = widget.cooldownRemaining;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(HintButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.cooldownRemaining != oldWidget.cooldownRemaining ||
        widget.hintReadyAt != oldWidget.hintReadyAt) {
      _remaining = widget.cooldownRemaining;
      _sync();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// Starts or stops the ticker to match the remaining time.
  ///
  /// The ticker counts down on its own rather than re-reading the controller,
  /// which only notifies when the hint state actually changes. A rebuild from
  /// elsewhere refreshes [Duration.cooldownRemaining] from the wall clock, so
  /// the countdown cannot drift away from the real deadline.
  void _sync() {
    if (_remaining <= Duration.zero) {
      _ticker?.cancel();
      _ticker = null;
      return;
    }

    final ticker = _ticker;
    if (ticker == null || !ticker.isActive) {
      _ticker = Timer.periodic(const Duration(seconds: 1), _tick);
    }
  }

  /// Advances the countdown and retires the ticker at zero.
  ///
  /// Clearing [_ticker] is what lets the next cooldown start its own timer;
  /// a cancelled timer left in the field would look active to [_sync].
  void _tick(Timer timer) {
    if (!mounted) {
      timer.cancel();
      _ticker = null;
      return;
    }

    setState(() => _remaining -= const Duration(seconds: 1));
    if (_remaining <= Duration.zero) {
      timer.cancel();
      _ticker = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final waiting = _remaining > Duration.zero;
    final ready = widget.enabled && !waiting;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.lightbulb_outline),
          color: ready ? null : BirdleColors.tileEmptyBorder,
          tooltip: !widget.enabled
              ? 'No hint available'
              : waiting
                  ? 'Hint ready in ${_clock(_remaining)}'
                  : 'Hint',
          onPressed: ready ? widget.onPressed : null,
        ),
        if (waiting && widget.enabled)
          Text(
            _clock(_remaining),
            style: const TextStyle(
              color: BirdleColors.ink,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        const SizedBox(width: 8),
      ],
    );
  }

  /// Formats [duration] as `m:ss`, rounding up so a fresh minute reads `1:00`
  /// rather than `0:59` because a few milliseconds have already passed.
  static String _clock(Duration duration) {
    final milliseconds = duration.inMilliseconds;
    final total = milliseconds <= 0 ? 0 : (milliseconds / 1000).ceil();
    final minutes = total ~/ 60;
    final seconds = total % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Shows what spending the hint produced.
///
/// [description] is the clue when the hidden word has one; [letterIndex] is
/// the position of the letter this hint revealed, if it revealed one.
Future<void> showHintDialog(
  BuildContext context, {
  required HintStatus status,
  required String hiddenWord,
  String? description,
  int? letterIndex,
  Duration cooldownRemaining = Duration.zero,
}) =>
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hint'),
        content: Text(_body(
          status,
          hiddenWord,
          description,
          letterIndex,
          cooldownRemaining,
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );

String _body(
  HintStatus status,
  String hiddenWord,
  String? description,
  int? letterIndex,
  Duration cooldownRemaining,
) =>
    switch (status) {
      HintStatus.described => 'The word means: $description',
      HintStatus.revealedLetter =>
        'The letter at position ${letterIndex! + 1} is '
            '"${hiddenWord[letterIndex].toUpperCase()}"',
      HintStatus.coolingDown =>
        'Your next hint is ready in ${cooldownRemaining.inSeconds} seconds.',
      HintStatus.limitReached =>
        'You have used every hint this round allows.',
      HintStatus.roundOver => 'This round is over, so there is no hint.',
      HintStatus.busy => 'Wait for the current guess to finish revealing.',
      HintStatus.unavailable => 'There is nothing left to reveal this round.',
    };
