import 'package:flutter/material.dart';

/// A transparent text field that mirrors [controller] and reports submissions.
///
/// It stays in the widget tree, on stage, but takes up a single pixel and
/// ignores taps, so a physical keyboard and the on-screen keyboard feed the
/// same text without a soft keyboard covering the board.
class GuessInput extends StatelessWidget {
  /// Creates an input bound to [controller].
  const GuessInput({
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    required this.enabled,
    super.key,
  });

  /// The text being typed.
  final TextEditingController controller;

  /// The field's focus, which the page reclaims after a round.
  final FocusNode focusNode;

  /// Called when the player presses enter.
  final VoidCallback onSubmitted;

  /// Whether the field accepts text.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 1,
      height: 1,
      child: Opacity(
        opacity: 0,
        child: IgnorePointer(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: true,
            enabled: enabled,
            // Keeps the soft keyboard down while still taking key presses.
            keyboardType: TextInputType.none,
            textInputAction: TextInputAction.done,
            maxLength: 5,
            showCursor: false,
            autocorrect: false,
            enableSuggestions: false,
            style: const TextStyle(color: Colors.transparent),
            cursorColor: Colors.transparent,
            decoration: const InputDecoration(
              counterText: '',
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            onSubmitted: (_) => onSubmitted(),
          ),
        ),
      ),
    );
  }
}
