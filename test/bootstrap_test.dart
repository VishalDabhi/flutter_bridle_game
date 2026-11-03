import 'dart:async';

import 'package:bk_lottery/hints.dart';
import 'package:bk_lottery/level_store.dart';
import 'package:bk_lottery/main.dart';
import 'package:bk_lottery/word_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockLevelStore implements LevelStore {
  int _level = 1;
  @override
  int get currentLevel => _level;
  @override
  Future<void> saveLevel(int level) async {
    _level = level;
  }
}

void main() {
  testWidgets('AppBootstrap shows loading indicator while waiting for data',
      (tester) async {
    final completer = Completer<AppData>();

    await tester.pumpWidget(
      AppBootstrap(
        loader: () => completer.future,
      ),
    );

    expect(find.text('BIRDLE'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(MainApp), findsNothing);
  });

  testWidgets('AppBootstrap transitions to MainApp once data is loaded',
      (tester) async {
    final completer = Completer<AppData>();

    await tester.pumpWidget(
      AppBootstrap(
        loader: () => completer.future,
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(
      AppData(
        wordList: InMemoryWordList(
          answers: const ['apple'],
          allowed: const ['apple'],
        ),
        hints: InMemoryHintBook(const {'apple': 'A fruit'}),
        levelStore: _MockLevelStore(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(MainApp), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('AppBootstrap shows error message on failure', (tester) async {
    final completer = Completer<AppData>();

    await tester.pumpWidget(
      AppBootstrap(
        loader: () => completer.future,
      ),
    );

    completer.completeError('Disk read error');

    await tester.pumpAndSettle();

    expect(find.textContaining('Failed to load Birdle: Disk read error'),
        findsOneWidget);
    expect(find.byType(MainApp), findsNothing);
  });
}

