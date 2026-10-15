/// The palette and [ThemeData] Birdle uses.
library;

import 'package:bk_lottery/game.dart';
import 'package:flutter/material.dart';

/// Colours borrowed from Wordle, tuned for its light theme.
abstract final class BirdleColors {
  /// Fill of a tile whose letter sits in the right place.
  static const Color hit = Color(0xFF6AAA64);

  /// Fill of a tile whose letter is in the word but misplaced.
  static const Color partial = Color(0xFFC9B458);

  /// Fill of a tile whose letter is not in the word.
  static const Color miss = Color(0xFF787C7E);

  /// Background of the whole app.
  static const Color background = Color(0xFFFFFFFF);

  /// Border, and later fill, of a tile that hasn't been revealed.
  static const Color tileEmptyBorder = Color(0xFF3A3A3C);

  /// Fill of a keyboard key that hasn't been guessed yet.
  static const Color keyIdle = Color(0xFFD3D6DA);

  /// Fill of a keyboard key already scored as a miss.
  static const Color keyMiss = Color(0xFF86888A);

  /// Text on a coloured tile or key.
  static const Color onFilled = Colors.white;

  /// Text on a tile that hasn't been revealed.
  static const Color onTileEmpty = Color(0xFF121213);

  /// Text on an unscored keyboard key.
  static const Color onKeyIdle = Color(0xFF121213);

  /// Text on a keyboard key already scored as a miss.
  static const Color onKeyMiss = Colors.white;

  /// Page background behind the keyboard.
  static const Color keyBackground = Color(0xFFFFFFFF);

  /// Body text, titles, and the keyboard action keys.
  static const Color ink = Color(0xFF121213);

  /// Background of transient surfaces such as the result panel.
  static const Color toast = Color(0xFFEEEEEE);
}

/// The fill colour a tile with [type] shows once revealed.
Color tileFill(HitType type) => switch (type) {
      HitType.hit => BirdleColors.hit,
      HitType.partial => BirdleColors.partial,
      HitType.miss => BirdleColors.miss,
      HitType.none => BirdleColors.background,
    };

/// The border colour a tile with [type] shows.
Color tileBorder(HitType type) =>
    type == HitType.none ? BirdleColors.tileEmptyBorder : tileFill(type);

/// The text colour a tile with [type] shows.
Color tileTextColor(HitType type) =>
    type == HitType.none ? BirdleColors.onTileEmpty : BirdleColors.onFilled;

/// The fill colour a keyboard key with [type] shows.
Color keyFill(HitType? type) => switch (type) {
      HitType.hit => BirdleColors.hit,
      HitType.partial => BirdleColors.partial,
      HitType.miss => BirdleColors.keyMiss,
      HitType.none || null => BirdleColors.keyIdle,
    };

/// The text colour a keyboard key with [type] shows.
Color keyTextColor(HitType? type) => switch (type) {
      HitType.hit || HitType.partial => BirdleColors.onFilled,
      HitType.miss => BirdleColors.onKeyMiss,
      HitType.none || null => BirdleColors.onKeyIdle,
    };

/// The app theme, using Wordle's light palette.
ThemeData birdleTheme() {
  const scheme = ColorScheme.light(
    primary: BirdleColors.hit,
    secondary: BirdleColors.partial,
    surface: BirdleColors.background,
    onSurface: BirdleColors.ink,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: BirdleColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: BirdleColors.background,
      foregroundColor: BirdleColors.ink,
      elevation: 0,
      centerTitle: true,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: BirdleColors.toast,
      contentTextStyle: TextStyle(color: BirdleColors.ink),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
