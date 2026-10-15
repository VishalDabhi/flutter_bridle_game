import 'package:bk_lottery/game.dart';
import 'package:bk_lottery/theme.dart';
import 'package:flutter/material.dart';

/// The on-screen QWERTY keyboard.
class Keyboard extends StatelessWidget {
  /// Creates a keyboard that reports presses through the given callbacks.
  const Keyboard({
    required this.keyStates,
    required this.onLetter,
    required this.onBackspace,
    required this.onSubmit,
    required this.canType,
    required this.canSubmit,
    required this.canBackspace,
    required this.draftIsLegal,
    super.key,
  });

  /// The three letter rows, top to bottom.
  static const List<List<String>> rows = [
    ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'],
    ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'],
    ['z', 'x', 'c', 'v', 'b', 'n', 'm'],
  ];

  /// The best result each guessed letter has earned.
  final Map<String, HitType> keyStates;

  /// Called with a single a-z character when a letter key is pressed.
  final ValueChanged<String> onLetter;

  /// Called when the backspace key is pressed.
  final VoidCallback onBackspace;

  /// Called when the enter key is pressed.
  final VoidCallback onSubmit;

  /// Whether letter keys react to presses.
  final bool canType;

  /// Whether [onSubmit] will be accepted.
  final bool canSubmit;

  /// Whether [onBackspace] will do anything.
  final bool canBackspace;

  /// Whether the letters typed so far spell a word the game accepts.
  ///
  /// Only used to colour the enter key, so the player can tell a real word
  /// from a typo before submitting.
  final bool draftIsLegal;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: BirdleColors.keyBackground),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var row = 0; row < rows.length - 1; row++)
              _row([for (final letter in rows[row]) _letterKey(letter)]),
            _row([
              _actionKey(
                id: 'backspace',
                icon: Icons.backspace_outlined,
                onPressed: canBackspace ? onBackspace : null,
              ),
              for (final letter in rows.last) _letterKey(letter),
              _actionKey(
                id: 'enter',
                label: 'ENTER',
                isReady: draftIsLegal,
                onPressed: canSubmit ? onSubmit : null,
              ),
            ]),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _row(List<Widget> children) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 3),
        child: Row(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              children[i],
            ],
          ],
        ),
      );

  Widget _letterKey(String letter) => Expanded(
        flex: 10,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: _Key(
            key: ValueKey('key-$letter'),
            label: letter,
            type: keyStates[letter],
            onPressed: canType ? () => onLetter(letter) : null,
          ),
        ),
      );

  Widget _actionKey({
    required String id,
    required VoidCallback? onPressed,
    String? label,
    IconData? icon,
    bool isReady = false,
  }) =>
      Expanded(
        flex: 15,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: _Key(
            key: ValueKey('key-$id'),
            label: label,
            icon: icon,
            isAction: true,
            isReady: isReady,
            onPressed: onPressed,
          ),
        ),
      );
}

class _Key extends StatelessWidget {
  const _Key({
    required this.label,
    required this.onPressed,
    this.icon,
    this.type,
    this.isAction = false,
    this.isReady = false,
    super.key,
  });

  final String? label;
  final IconData? icon;
  final HitType? type;

  /// Whether this is ENTER or backspace, which stay dark in the light theme.
  final bool isAction;

  /// Whether this key currently leads somewhere, which turns it green.
  final bool isReady;

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final fill = isReady
        ? BirdleColors.hit
        : isAction
            ? BirdleColors.ink
            : keyFill(type);
    final foreground = isReady || isAction ? BirdleColors.onFilled : keyTextColor(type);

    return Material(
      color: enabled || isAction ? fill : fill.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onPressed,
        child: SizedBox(
          height: 50,
          child: Center(
            child: icon != null
                ? Icon(icon, color: foreground, size: 22)
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label!,
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
