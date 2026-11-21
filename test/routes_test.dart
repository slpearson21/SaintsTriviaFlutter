import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saints_trivia_flutter/data/questions/scripture_volume.dart';
import 'package:saints_trivia_flutter/game/game_engine.dart';
import 'package:saints_trivia_flutter/game/game_providers.dart';
import 'package:saints_trivia_flutter/routing/routes.dart';

import 'pump_app.dart';

/// Results opens from Next on the last question. This file checks the route
/// stack, so it jumps there with the same `go` Next uses.
///
/// The question screen does not finish a game by itself, and Results
/// redirects home without a finished session. The jump installs one first.
Future<void> _openResults(WidgetTester tester) async {
  final element = tester.element(find.text('Question'));
  final router = GoRouter.of(element);
  final container = ProviderScope.containerOf(element);
  (container.read(gameControllerProvider.notifier) as _RouteGame).show(
    _routeGame(),
  );
  router.go(AppRoutes.results);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('every route renders and is reachable', (tester) async {
    await pumpApp(tester, overrides: _routeController());
    expect(find.text('LDS Scripture Trivia'), findsOneWidget);
    expect(find.text('Start a game'), findsOneWidget);

    await tester.tap(find.text('Start a game'));
    await tester.pumpAndSettle();
    expect(find.text('New game'), findsOneWidget);

    await tester.tap(find.textContaining('Start game'));
    await tester.pumpAndSettle();
    expect(find.text('Question'), findsOneWidget);

    await _openResults(tester);
    expect(find.text('Results'), findsOneWidget);

    await tester.ensureVisible(find.text('Review'));
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    expect(find.text('Review answers'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Results'), findsOneWidget);

    await tester.ensureVisible(find.text('Done'));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('LDS Scripture Trivia'), findsOneWidget);

    await tester.tap(find.byTooltip('Stats'));
    await tester.pumpAndSettle();
    expect(find.text('Stats'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('LDS Scripture Trivia'), findsOneWidget);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('back from results lands on home, not the game', (tester) async {
    await pumpApp(tester, overrides: _routeController());
    await tester.tap(find.text('Start a game'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Start game'));
    await tester.pumpAndSettle();
    await _openResults(tester);
    expect(find.text('Results'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('LDS Scripture Trivia'), findsOneWidget);
    expect(find.text('Question'), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('back from setup after new game lands on home', (tester) async {
    await pumpApp(tester, overrides: _routeController());
    await tester.tap(find.text('Start a game'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Start game'));
    await tester.pumpAndSettle();
    await _openResults(tester);
    await tester.ensureVisible(find.text('New game'));
    await tester.tap(find.text('New game'));
    await tester.pumpAndSettle();
    expect(find.text('Select all'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('LDS Scripture Trivia'), findsOneWidget);
    expect(find.text('Select all'), findsNothing);
    expect(find.text('Question'), findsNothing);
  });
}

List<Override> _routeController() {
  return [gameControllerProvider.overrideWith(_RouteGame.new)];
}

class _RouteGame extends GameController {
  void show(GameSession session) => state = session;
}

GameSession _routeGame() {
  final question = GameQuestion(
    id: 'bom-0001',
    volume: ScriptureVolume.bom,
    reference: '1 Nephi 1:1',
    prompt: 'Who made this record?',
    options: const ['Nephi', 'Lehi', 'Sam', 'Laman'],
    answerIndex: 0,
    explanation: 'Nephi made the record.',
  );
  return GameSession(
    volumes: ScriptureVolume.values,
    requestedCount: 10,
    questions: [question],
    currentIndex: 1,
    answers: const [
      GameAnswer(questionId: 'bom-0001', selectedIndex: 0, correct: true),
    ],
    score: 1,
    currentStreak: 1,
    bestStreak: 1,
  );
}
