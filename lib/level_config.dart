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

  /// The repeating 7-level difficulty cycle:
  /// 2 Easy -> 1 Medium -> 3 Easy -> 1 Hard.
  static const List<LevelDifficulty> difficultyCycle = [
    LevelDifficulty.easy, // 1
    LevelDifficulty.easy, // 2
    LevelDifficulty.medium, // 3
    LevelDifficulty.easy, // 4
    LevelDifficulty.easy, // 5
    LevelDifficulty.easy, // 6
    LevelDifficulty.hard, // 7
  ];

  /// The number of levels in a complete cycle.
  static int get cycleLength => difficultyCycle.length;

  /// The rules for [level], which must be at least one.
  ///
  /// Difficulty cycles infinitely through [difficultyCycle].
  static LevelConfig forLevel(int level) {
    final safeLevel = level < 1 ? 1 : level;
    final difficulty =
        difficultyCycle[(safeLevel - 1) % difficultyCycle.length];

    return switch (difficulty) {
      LevelDifficulty.easy => const LevelConfig(
          difficulty: LevelDifficulty.easy,
          maxGuesses: 6,
          hintCooldown: Duration(seconds: 60),
        ),
      LevelDifficulty.medium => const LevelConfig(
          difficulty: LevelDifficulty.medium,
          maxGuesses: 5,
          hintCooldown: Duration(seconds: 90),
        ),
      LevelDifficulty.hard => const LevelConfig(
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
