import 'package:bk_lottery/hints.dart';
import 'package:bk_lottery/level_store.dart';
import 'package:bk_lottery/pages/game_page.dart';
import 'package:bk_lottery/theme.dart';
import 'package:bk_lottery/word_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

export 'package:bk_lottery/widgets/hint_button.dart' show HintButton;
export 'package:bk_lottery/widgets/result_panel.dart' show PlayAgainButton;
export 'package:bk_lottery/widgets/tile.dart' show Tile;

/// Loads the bundled word lists and clues, then starts the app.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  final wordList = await AssetWordList.load();
  final hints = await AssetHintBook.load();
  final levelStore = PrefsLevelStore(await SharedPreferences.getInstance());
  runApp(MainApp(wordList: wordList, hints: hints, levelStore: levelStore));
}

/// The Birdle application.
class MainApp extends StatelessWidget {
  /// Creates the app around [wordList] and [levelStore].
  const MainApp({
    required this.wordList,
    required this.levelStore,
    this.hints,
    this.seed,
    this.step = const Duration(milliseconds: 120),
    this.hintCooldown,
    this.hintLimit,
    super.key,
  });

  /// The vocabulary every round is drawn from.
  final WordList wordList;

  /// Remembers the level the next round should start at.
  final LevelStore levelStore;

  /// Clues for the hint button.
  final HintBook? hints;

  /// The seed for the hidden word, or `null` to choose at random.
  ///
  /// Tests pass a seed to make a round predictable.
  final int? seed;

  /// The delay between two consecutive tile flips.
  final Duration step;

  /// Overrides the level's hint cooldown when set.
  final Duration? hintCooldown;

  /// The most hints one round allows, or `null` for no limit.
  final int? hintLimit;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Birdle',
      debugShowCheckedModeBanner: false,
      theme: birdleTheme(),
      home: GamePage(
        wordList: wordList,
        levelStore: levelStore,
        hints: hints,
        seed: seed,
        step: step,
        hintCooldown: hintCooldown,
        hintLimit: hintLimit,
      ),
    );
  }
}
