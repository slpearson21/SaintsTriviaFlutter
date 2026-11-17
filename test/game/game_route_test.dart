import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:saints_trivia_flutter/app.dart';
import 'package:saints_trivia_flutter/data/questions/questions.dart';
import 'package:saints_trivia_flutter/data/questions/question_bank_provider.dart';
import 'package:saints_trivia_flutter/game/game_launch.dart';
import 'package:saints_trivia_flutter/game/game_providers.dart';
import 'package:saints_trivia_flutter/progress/home_snapshot.dart';
import 'package:saints_trivia_flutter/routing/app_router.dart';
import 'package:saints_trivia_flutter/routing/routes.dart';
import 'package:saints_trivia_flutter/screens/game_screen.dart';

import '../pump_app.dart';
import '../support/fixed_home_snapshot.dart';

const _routeSettings = LastGameSettings(
  volumes: [ScriptureVolume.bom],
  questionCount: 4,
);

const _savedSettings = LastGameSettings(
  volumes: [ScriptureVolume.nt, ScriptureVolume.ot],
  questionCount: 6,
);

final _returning = HomeSnapshot(
  gamesPlayed: 2,
  accuracyPercent: 50,
  bestStreak: 3,
  lastSettings: _savedSettings,
);

void main() {
  test('extra is used only when it is LastGameSettings', () {
    const snapshot = HomeSnapshot.firstRun();
    expect(gameSettingsFromRoute(_routeSettings, snapshot), _routeSettings);
    expect(gameSettingsFromRoute(null, snapshot), isNull);
    expect(gameSettingsFromRoute('restored', snapshot), isNull);
    expect(gameSettingsFromRoute(42, _returning), _savedSettings);
    expect(gameSettingsFromRoute(null, _returning), _savedSettings);
    expect(gameSettingsFromRoute(_routeSettings, _returning), _routeSettings);
  });

  testWidgets('a game link with no settings opens setup', (tester) async {
    await pumpApp(tester);

    final router = GoRouter.of(tester.element(find.text('Scripture Trivia')));
    router.go(AppRoutes.game);
    await tester.pumpAndSettle();

    expect(find.text('New game'), findsOneWidget);
    expect(find.byType(GameScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a non-settings extra is not cast and falls back', (
    tester,
  ) async {
    await pumpApp(tester, overrides: [fixedHomeSnapshot(_returning)]);

    final router = GoRouter.of(tester.element(find.text('Scripture Trivia')));
    router.go(AppRoutes.game, extra: 'deep link');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      tester.widget<GameScreen>(find.byType(GameScreen)).settings,
      _savedSettings,
    );
  });

  testWidgets('route extra wins over the saved game', (tester) async {
    await pumpApp(tester, overrides: [fixedHomeSnapshot(_returning)]);

    final router = GoRouter.of(tester.element(find.text('Scripture Trivia')));
    router.go(AppRoutes.game, extra: _routeSettings);
    await tester.pumpAndSettle();

    expect(
      tester.widget<GameScreen>(find.byType(GameScreen)).settings,
      _routeSettings,
    );
  });

  testWidgets('a null extra uses the saved game', (tester) async {
    await pumpApp(tester, overrides: [fixedHomeSnapshot(_returning)]);

    final router = GoRouter.of(tester.element(find.text('Scripture Trivia')));
    router.go(AppRoutes.game);
    await tester.pumpAndSettle();

    expect(
      tester.widget<GameScreen>(find.byType(GameScreen)).settings,
      _savedSettings,
    );
  });

  testWidgets('deals when the bank resolves after the game screen mounts', (
    tester,
  ) async {
    final gate = Completer<QuestionBank>();
    final bank = QuestionBank(
      schemaVersion: 1,
      questions: [
        for (var i = 0; i < 8; i++)
          TriviaQuestion(
            id: 'bom-${(i + 1).toString().padLeft(4, '0')}',
            volume: ScriptureVolume.bom,
            reference: '1 Nephi 1:${i + 1}',
            prompt: 'Prompt $i',
            options: const ['Nephi', 'Lehi', 'Sam', 'Laman'],
            answerIndex: i % 4,
            explanation: 'Because $i.',
            reviewStatus: ReviewStatus.draft,
          ),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        questionBankLoaderProvider.overrideWith(
          (ref) =>
              () => gate.future,
        ),
        gameRandomProvider.overrideWith((ref) => Random(3)),
      ],
    );
    addTearDown(container.dispose);
    // The load is already running when the screen mounts, and it resolves
    // after that. The screen listens instead of starting its own load.
    final pending = container.read(questionBankProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SaintsTriviaApp(),
      ),
    );
    await tester.pump();

    container.read(appRouterProvider).go(AppRoutes.game, extra: _routeSettings);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(container.read(gameControllerProvider), isNull);
    expect(find.text('Question'), findsOneWidget);

    gate.complete(bank);
    await pending;
    await tester.pump();
    await tester.pump();

    final session = container.read(gameControllerProvider);
    expect(session, isNotNull);
    expect(session!.volumes, _routeSettings.volumes);
    expect(session.requestedCount, _routeSettings.questionCount);
    expect(session.questions, hasLength(4));
    expect(find.text('Question'), findsOneWidget);
  });

  testWidgets('an empty deal shows the no-questions error', (tester) async {
    final bank = QuestionBank(
      schemaVersion: 1,
      questions: [
        TriviaQuestion(
          id: 'ot-0001',
          volume: ScriptureVolume.ot,
          reference: 'Genesis 1:1',
          prompt: 'Prompt',
          options: const ['a', 'b', 'c', 'd'],
          answerIndex: 0,
          explanation: 'Because.',
          reviewStatus: ReviewStatus.draft,
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        questionBankLoaderProvider.overrideWith(
          (ref) =>
              () async => bank,
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(questionBankProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SaintsTriviaApp(),
      ),
    );
    container
        .read(appRouterProvider)
        .go(
          AppRoutes.game,
          extra: const LastGameSettings(
            volumes: [ScriptureVolume.pgp],
            questionCount: 5,
          ),
        );
    await tester.pumpAndSettle();

    expect(find.byType(GameScreen), findsOneWidget);
    expect(find.text('Couldn’t start this game'), findsOneWidget);
    expect(find.text('Back to setup'), findsOneWidget);
    expect(find.text('Question'), findsNothing);
    expect(find.text('Prompt'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a previous session is hidden until the new deal is showing', (
    tester,
  ) async {
    final bank = QuestionBank(
      schemaVersion: 1,
      questions: [
        for (var i = 0; i < 8; i++)
          TriviaQuestion(
            id: 'ot-${(i + 1).toString().padLeft(4, '0')}',
            volume: ScriptureVolume.ot,
            reference: 'Genesis 1:${i + 1}',
            prompt: 'Prompt $i',
            options: const ['a', 'b', 'c', 'd'],
            answerIndex: 0,
            explanation: 'Because $i.',
            reviewStatus: ReviewStatus.draft,
          ),
        for (var i = 0; i < 8; i++)
          TriviaQuestion(
            id: 'bom-${(i + 1).toString().padLeft(4, '0')}',
            volume: ScriptureVolume.bom,
            reference: '1 Nephi 1:${i + 1}',
            prompt: 'Prompt $i',
            options: const ['Nephi', 'Lehi', 'Sam', 'Laman'],
            answerIndex: i % 4,
            explanation: 'Because $i.',
            reviewStatus: ReviewStatus.draft,
          ),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        questionBankLoaderProvider.overrideWith(
          (ref) =>
              () async => bank,
        ),
        gameRandomProvider.overrideWith((ref) => Random(3)),
      ],
    );
    addTearDown(container.dispose);
    await container.read(questionBankProvider.future);
    container
        .read(gameControllerProvider.notifier)
        .start(
          bank: bank,
          volumes: const [ScriptureVolume.ot],
          requestedCount: 4,
        );
    final finished = container
        .read(gameControllerProvider)!
        .questions
        .map((question) => question.id)
        .toList();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SaintsTriviaApp(),
      ),
    );
    container.read(appRouterProvider).go(AppRoutes.game, extra: _routeSettings);
    await tester.pump();

    expect(find.text('Question'), findsNothing);
    final dealt = container.read(gameControllerProvider);
    expect(dealt, isNotNull);
    expect(dealt!.volumes, _routeSettings.volumes);
    expect(
      dealt.questions.map((question) => question.id).toList(),
      isNot(finished),
    );

    await tester.pump();
    expect(find.text('Question'), findsOneWidget);
    expect(
      container
          .read(gameControllerProvider)!
          .questions
          .map((question) => question.id)
          .toList(),
      dealt.questions.map((question) => question.id).toList(),
    );
  });

  testWidgets('a loaded bank is dealt when the game route opens', (
    tester,
  ) async {
    final bank = QuestionBank(
      schemaVersion: 1,
      questions: [
        for (var i = 0; i < 8; i++)
          TriviaQuestion(
            id: 'bom-${(i + 1).toString().padLeft(4, '0')}',
            volume: ScriptureVolume.bom,
            reference: '1 Nephi 1:${i + 1}',
            prompt: 'Prompt $i',
            options: const ['Nephi', 'Lehi', 'Sam', 'Laman'],
            answerIndex: i % 4,
            explanation: 'Because $i.',
            reviewStatus: ReviewStatus.draft,
          ),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        questionBankLoaderProvider.overrideWith(
          (ref) =>
              () async => bank,
        ),
        gameRandomProvider.overrideWith((ref) => Random(3)),
      ],
    );
    addTearDown(container.dispose);
    await container.read(questionBankProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SaintsTriviaApp(),
      ),
    );
    container.read(appRouterProvider).go(AppRoutes.game, extra: _routeSettings);
    await tester.pump();
    await tester.pump();

    final session = container.read(gameControllerProvider);
    expect(session, isNotNull);
    expect(session!.volumes, _routeSettings.volumes);
    expect(session.requestedCount, _routeSettings.questionCount);
    expect(session.questions, hasLength(4));
    expect(
      session.questions.map((question) => question.id).toSet(),
      hasLength(4),
    );
    expect(session.score, 0);
    expect(session.currentStreak, 0);
    expect(session.bestStreak, 0);
  });
}
