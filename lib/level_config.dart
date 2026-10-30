/// The difficulty tiers that drive the unlimited level progression.
library;

/// The three difficulty tiers a level can use.
enum LevelDifficulty {
  /// More guesses and a faster hint recharge.
  easy('Easy'),

  /// Fewer guesses and a slower hint recharge.
  medium('Medium'),

  /// The fewest guesses and the slowest hint recharge.
  hard('Hard');

  const LevelDifficulty(this.label);

  /// Text shown next to the level number.
  final String label;
}

/// The rules for one level.
class LevelConfig {
  const LevelConfig({
    required this.difficulty,
    required this.maxGuesses,
    required this.hintCooldown,
  });

  /// How many levels each difficulty lasts before moving to the next tier.
  static const int levelsPerDifficulty = 3;

  /// The rules for [level], which must be at least one.
  ///
  /// Difficulty cycles through easy, medium, and hard every
  /// [levelsPerDifficulty] levels, so the progression never runs out.
  static LevelConfig forLevel(int level) {
    final safeLevel = level < 1 ? 1 : level;
    final tier = (safeLevel - 1) ~/ levelsPerDifficulty;

    return switch (tier % LevelDifficulty.values.length) {
      0 => const LevelConfig(
          difficulty: LevelDifficulty.easy,
          maxGuesses: 6,
          hintCooldown: Duration(seconds: 60),
        ),
      1 => const LevelConfig(
          difficulty: LevelDifficulty.medium,
          maxGuesses: 5,
          hintCooldown: Duration(seconds: 90),
        ),
      _ => const LevelConfig(
          difficulty: LevelDifficulty.hard,
          maxGuesses: 4,
          hintCooldown: Duration(seconds: 120),
        ),
    };
  }

  /// The difficulty tier this level belongs to.
  final LevelDifficulty difficulty;

  /// How many guesses the player gets this level.
  final int maxGuesses;

  /// How long a hint takes to recharge this level.
  final Duration hintCooldown;
}
