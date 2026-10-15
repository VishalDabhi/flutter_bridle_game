import 'package:bk_lottery/pages/game_page.dart';
import 'package:bk_lottery/theme.dart';
import 'package:bk_lottery/word_list.dart';
import 'package:flutter/material.dart';

export 'package:bk_lottery/widgets/result_panel.dart' show PlayAgainButton;
export 'package:bk_lottery/widgets/tile.dart' show Tile;

/// Loads the bundled word lists, then starts the app.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final wordList = await AssetWordList.load();
  runApp(MainApp(wordList: wordList));
}

/// The Birdle application.
class MainApp extends StatelessWidget {
  /// Creates the app around [wordList].
  const MainApp({
    required this.wordList,
    this.seed,
    this.step = const Duration(milliseconds: 120),
    super.key,
  });

  /// The vocabulary every round is drawn from.
  final WordList wordList;

  /// The seed for the hidden word, or `null` to choose at random.
  ///
  /// Tests pass a seed to make a round predictable.
  final int? seed;

  /// The delay between two consecutive tile flips.
  final Duration step;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Birdle',
      debugShowCheckedModeBanner: false,
      theme: birdleTheme(),
      home: Scaffold(
        appBar: AppBar(title: const Text('Birdle')),
        body: GamePage(wordList: wordList, seed: seed, step: step),
      ),
    );
  }
}
