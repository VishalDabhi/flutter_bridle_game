import 'package:bk_lottery/game_controller.dart';
import 'package:bk_lottery/hints.dart';
import 'package:bk_lottery/pages/game_page.dart';
import 'package:bk_lottery/theme.dart';
import 'package:bk_lottery/word_list.dart';
import 'package:flutter/material.dart';

export 'package:bk_lottery/widgets/hint_button.dart' show HintButton;
export 'package:bk_lottery/widgets/result_panel.dart' show PlayAgainButton;
export 'package:bk_lottery/widgets/tile.dart' show Tile;

/// Loads the bundled word lists and clues, then starts the app.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final wordList = await AssetWordList.load();
  final hints = await AssetHintBook.load();
  runApp(MainApp(wordList: wordList, hints: hints));
}

/// The Birdle application.
class MainApp extends StatelessWidget {
  /// Creates the app around [wordList].
  const MainApp({
    required this.wordList,
    this.hints,
    this.seed,
    this.step = const Duration(milliseconds: 120),
    this.hintCooldown = GameController.defaultHintCooldown,
    super.key,
  });

  /// The vocabulary every round is drawn from.
  final WordList wordList;

  /// Clues for the hint button.
  final HintBook? hints;

  /// The seed for the hidden word, or `null` to choose at random.
  ///
  /// Tests pass a seed to make a round predictable.
  final int? seed;

  /// The delay between two consecutive tile flips.
  final Duration step;

  /// How long a spent hint takes to come back.
  final Duration hintCooldown;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Birdle',
      debugShowCheckedModeBanner: false,
      theme: birdleTheme(),
      home: GamePage(
        wordList: wordList,
        hints: hints,
        seed: seed,
        step: step,
        hintCooldown: hintCooldown,
      ),
    );
  }
}
