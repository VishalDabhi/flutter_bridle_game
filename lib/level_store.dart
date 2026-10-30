/// Local persistence for the level the player should resume from.
library;

import 'package:shared_preferences/shared_preferences.dart';

/// Stores the current level without requiring a player account.
abstract interface class LevelStore {
  /// The level to resume from, which is always at least one.
  int get currentLevel;

  /// Saves [level] as the level to resume from.
  Future<void> saveLevel(int level);
}

/// A [LevelStore] backed by the platform's local preferences.
class PrefsLevelStore implements LevelStore {
  /// Creates a store backed by [preferences].
  PrefsLevelStore(this._preferences);

  /// Preference key holding the current level.
  static const String storageKey = 'birdle.currentLevel';

  final SharedPreferences _preferences;

  @override
  int get currentLevel {
    final stored = _preferences.getInt(storageKey);
    return stored == null || stored < 1 ? 1 : stored;
  }

  @override
  Future<void> saveLevel(int level) =>
      _preferences.setInt(storageKey, level < 1 ? 1 : level);
}
