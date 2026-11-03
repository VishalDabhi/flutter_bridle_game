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

/// Starts the app by immediately rendering the bootstrap splash screen
/// while loading assets concurrently in the background.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const AppBootstrap());
}

/// Bundle of core dependencies needed by [MainApp].
class AppData {
  /// Creates the dependency bundle.
  const AppData({
    required this.wordList,
    required this.hints,
    required this.levelStore,
  });

  /// Loaded word list.
  final WordList wordList;

  /// Loaded hint dictionary.
  final HintBook hints;

  /// Loaded level store.
  final LevelStore levelStore;
}

/// The bootstrap widget that mounts immediately to show a loading screen
/// while asynchronously loading words, clues, and preferences in parallel.
class AppBootstrap extends StatefulWidget {
  /// Creates the bootstrap loader.
  const AppBootstrap({
    this.loader,
    super.key,
  });

  /// Optional loader callback for testing. When `null`, loads real assets.
  final Future<AppData> Function()? loader;

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  late final Future<AppData> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = (widget.loader ?? _loadAppData)();
  }

  static Future<AppData> _loadAppData() async {
    final results = await Future.wait([
      AssetWordList.load(),
      AssetHintBook.load(),
      SharedPreferences.getInstance(),
    ]);
    return AppData(
      wordList: results[0] as WordList,
      hints: results[1] as HintBook,
      levelStore: PrefsLevelStore(results[2] as SharedPreferences),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppData>(
      future: _initFuture,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data != null) {
          return MainApp(
            wordList: data.wordList,
            hints: data.hints,
            levelStore: data.levelStore,
          );
        }
        if (snapshot.hasError) {
          return MaterialApp(
            title: 'Birdle',
            debugShowCheckedModeBanner: false,
            theme: birdleTheme(),
            home: Scaffold(
              backgroundColor: BirdleColors.background,
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    'Failed to load Birdle: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: BirdleColors.ink),
                  ),
                ),
              ),
            ),
          );
        }
        return MaterialApp(
          title: 'Birdle',
          debugShowCheckedModeBanner: false,
          theme: birdleTheme(),
          home: const Scaffold(
            backgroundColor: BirdleColors.background,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'BIRDLE',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                      color: BirdleColors.ink,
                    ),
                  ),
                  SizedBox(height: 24),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: BirdleColors.hit,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
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
