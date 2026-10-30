import 'package:bk_lottery/level_config.dart';
import 'package:bk_lottery/level_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LevelConfig', () {
    test('cycles through the difficulty tiers', () {
      expect(LevelConfig.forLevel(1).difficulty, LevelDifficulty.easy);
      expect(LevelConfig.forLevel(3).difficulty, LevelDifficulty.easy);
      expect(LevelConfig.forLevel(4).difficulty, LevelDifficulty.medium);
      expect(LevelConfig.forLevel(6).difficulty, LevelDifficulty.medium);
      expect(LevelConfig.forLevel(7).difficulty, LevelDifficulty.hard);
      expect(LevelConfig.forLevel(9).difficulty, LevelDifficulty.hard);
      expect(LevelConfig.forLevel(10).difficulty, LevelDifficulty.easy);
    });

    test('later tiers allow fewer guesses and slower hints', () {
      final easy = LevelConfig.forLevel(1);
      final medium = LevelConfig.forLevel(4);
      final hard = LevelConfig.forLevel(7);

      expect([easy.maxGuesses, medium.maxGuesses, hard.maxGuesses], [6, 5, 4]);
      expect(
        [
          easy.hintCooldown.inSeconds,
          medium.hintCooldown.inSeconds,
          hard.hintCooldown.inSeconds,
        ],
        [60, 90, 120],
      );
    });

    test('treats levels below one as level one', () {
      expect(LevelConfig.forLevel(0).difficulty, LevelDifficulty.easy);
      expect(
        LevelConfig.forLevel(-4).maxGuesses,
        LevelConfig.forLevel(1).maxGuesses,
      );
    });
  });

  group('PrefsLevelStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('defaults to level one', () async {
      final store = PrefsLevelStore(await SharedPreferences.getInstance());

      expect(store.currentLevel, 1);
    });

    test('saves the level for the next launch', () async {
      final preferences = await SharedPreferences.getInstance();
      final store = PrefsLevelStore(preferences);

      await store.saveLevel(4);

      expect(store.currentLevel, 4);
      expect(preferences.getInt(PrefsLevelStore.storageKey), 4);
    });

    test('ignores stored levels below one', () async {
      SharedPreferences.setMockInitialValues({
        PrefsLevelStore.storageKey: 0,
      });

      final store = PrefsLevelStore(await SharedPreferences.getInstance());

      expect(store.currentLevel, 1);
    });
  });
}
