import 'dart:math';
import 'dart:ui' show Tristate;

import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saints_trivia_flutter/app.dart';
import 'package:saints_trivia_flutter/data/questions/question_bank_provider.dart';
import 'package:saints_trivia_flutter/data/questions/questions.dart';
import 'package:saints_trivia_flutter/game/game_engine.dart';
import 'package:saints_trivia_flutter/game/game_providers.dart';
import 'package:saints_trivia_flutter/persistence/finished_game_record.dart';
import 'package:saints_trivia_flutter/persistence/memory_progress_repository.dart';
import 'package:saints_trivia_flutter/persistence/persistence_providers.dart';
import 'package:saints_trivia_flutter/progress/home_providers.dart';
import 'package:saints_trivia_flutter/progress/home_snapshot.dart';
import 'package:saints_trivia_flutter/report/report_sheet.dart';
import 'package:saints_trivia_flutter/routing/app_router.dart';
import 'package:saints_trivia_flutter/routing/routes.dart';
import 'package:saints_trivia_flutter/services/open_link.dart';
import 'package:saints_trivia_flutter/theme/st_theme.dart';
import 'package:url_launcher/url_launcher.dart';

import '../pump_app.dart';
import '../support/fixed_home_snapshot.dart';

final _now = DateTime(2026, 11, 15, 9);

const _playAgain = LastGameSettings(
  volumes: [ScriptureVolume.dc, ScriptureVolume.bom],
  questionCount: 10,
);

final _returning = HomeSnapshot(
  gamesPlayed: 12,
  accuracyPercent: 84,
  bestStreak: 9,
  lastGame: LastGameSummary(
    correct: 8,
    total: 10,
    playedAt: DateTime(2026, 11, 14, 20),
  ),
  lastSettings: _playAgain,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('home buttons and links expose a tap', (tester) async {
    await _surface(tester);
    await pumpApp(tester);
    _expectTaps(tester);

    await tester.pumpWidget(const SizedBox.shrink());
    await pumpApp(
      tester,
      overrides: [
        fixedHomeSnapshot(_returning),
        homeClockProvider.overrideWith(
          (ref) =>
              () => _now,
        ),
      ],
    );
    _expectTaps(tester);
  });

  testWidgets('a screen reader can tap Play again', (tester) async {
    await _surface(tester);
    await pumpApp(
      tester,
      overrides: [
        fixedHomeSnapshot(_returning),
        homeClockProvider.overrideWith(
          (ref) =>
              () => _now,
        ),
      ],
    );

    tester.semantics.tap(
      find.semantics.byLabel(playAgainSemanticsLabel(_playAgain)),
    );
    await tester.pumpAndSettle();

    expect(find.text('New game'), findsOneWidget);
    expect(find.text('Select all'), findsOneWidget);
  });

  testWidgets('setup buttons and links expose a tap on Android and iOS', (
    tester,
  ) async {
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await _openSetup(tester, platform: TargetPlatform.android);
    _expectTaps(tester);

    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await _openSetup(tester, platform: TargetPlatform.iOS);
    _expectTaps(tester);
  });

  testWidgets('a screen reader can tap a setup stepper and a preset', (
    tester,
  ) async {
    await _openSetup(tester, platform: TargetPlatform.android);

    expect(_countText(tester), '10');
    tester.semantics.tap(find.semantics.byLabel('More questions'));
    await tester.pumpAndSettle();
    expect(_countText(tester), '11');

    tester.semantics.tap(find.semantics.byLabel('20 questions'));
    await tester.pumpAndSettle();
    expect(_countText(tester), '20');
  });

  testWidgets(
    'game buttons and links expose a tap before and after an answer',
    (tester) async {
      await _pumpGame(tester);
      _expectTaps(tester);

      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();
      expect(find.text('Next question'), findsOneWidget);
      _expectTaps(tester);
    },
  );

  testWidgets('a screen reader can tap a game answer', (tester) async {
    await _pumpGame(tester);

    tester.semantics.tap(find.semantics.byLabel('Alpha'));
    await tester.pumpAndSettle();

    expect(find.text('Next question'), findsOneWidget);
    expect(find.text('Prompt 0'), findsOneWidget);
  });

  testWidgets('the report sheet exposes a tap on its enabled controls', (
    tester,
  ) async {
    await _pumpGame(tester);
    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(reportFlagTooltip));
    await tester.pumpAndSettle();

    expect(find.text(reportSheetTitle), findsOneWidget);
    _expectTaps(tester);

    await tester.tap(find.text('Wrong answer'));
    await tester.pumpAndSettle();
    _expectTaps(tester);
  });

  testWidgets('the Reported state exposes a tap', (tester) async {
    await _pumpGame(
      tester,
      canOpen: (_) async => true,
      open: (uri, {LaunchMode mode = LaunchMode.platformDefault}) async => true,
    );
    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(reportFlagTooltip));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Typo or wording'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('report-continue')));
    await tester.pumpAndSettle();

    expect(find.text('Reported'), findsOneWidget);
    _expectTaps(tester);
  });

  testWidgets('results and review expose a tap', (tester) async {
    await _surface(tester);
    final container = await _pumpApp(
      tester,
      overrides: [
        gameControllerProvider.overrideWith(() => _HeldGame(_finished())),
        fixedHomeSnapshot(const HomeSnapshot.firstRun()),
        questionBankLoaderProvider.overrideWith(
          (ref) =>
              () async => _bank(),
        ),
      ],
    );
    container.read(appRouterProvider).go(AppRoutes.results);
    await tester.pumpAndSettle();
    expect(find.text('Results'), findsOneWidget);
    _expectTaps(tester);

    container.read(appRouterProvider).go(AppRoutes.review);
    await tester.pumpAndSettle();
    expect(find.text('Review answers'), findsOneWidget);
    _expectTaps(tester);
  });

  testWidgets('stats exposes a tap', (tester) async {
    await _surface(tester);
    final container = await _pumpApp(
      tester,
      overrides: [
        progressRepositoryProvider.overrideWithValue(
          MemoryProgressRepository(games: [_storedGame]),
        ),
        homeClockProvider.overrideWith(
          (ref) =>
              () => _now,
        ),
      ],
    );
    container.read(appRouterProvider).go(AppRoutes.stats);
    await tester.pumpAndSettle();
    expect(find.text('Games played'), findsOneWidget);
    _expectTaps(tester);
  });

  testWidgets('settings exposes a tap', (tester) async {
    await _surface(tester);
    final container = await _pumpApp(tester);
    container.read(appRouterProvider).go(AppRoutes.settings);
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    _expectTaps(tester);
  });

  testWidgets('a screen reader can tap a settings theme row', (tester) async {
    await _surface(tester);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final container = await _pumpApp(tester);
    container.read(appRouterProvider).go(AppRoutes.settings);
    await tester.pumpAndSettle();

    tester.semantics.tap(find.semantics.byLabel('Dark'));
    await tester.pumpAndSettle();

    expect(
      Theme.of(tester.element(find.text('Settings'))).brightness,
      Brightness.dark,
    );
    expect(container.read(settingsProvider).themeMode, ThemeMode.dark);
  });

  testWidgets('error states expose a tap', (tester) async {
    await _surface(tester);

    final broken = await _pumpApp(
      tester,
      overrides: [
        questionBankLoaderProvider.overrideWith(
          (ref) =>
              () async => throw Exception('unreadable'),
        ),
      ],
      settle: false,
    );
    await _failBank(broken);
    broken.read(appRouterProvider).go(AppRoutes.setup);
    await tester.pumpAndSettle();
    expect(find.text('Something went wrong'), findsOneWidget);
    _expectTaps(tester);

    final empty = await _pumpApp(
      tester,
      overrides: [
        questionBankLoaderProvider.overrideWith(
          (ref) =>
              () async => _bank(),
        ),
      ],
      settle: false,
    );
    await empty.read(questionBankProvider.future);
    empty
        .read(appRouterProvider)
        .go(
          AppRoutes.game,
          extra: const LastGameSettings(
            volumes: [ScriptureVolume.pgp],
            questionCount: 5,
          ),
        );
    await tester.pumpAndSettle();
    expect(find.text('Back to setup'), findsOneWidget);
    _expectTaps(tester);
  });
}

Future<void> _surface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(400, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

/// Enabled buttons and links a screen reader can land on need a tap action.
void _expectTaps(WidgetTester tester) {
  final missing = <String>[];
  var controls = 0;

  void walk(SemanticsNode node) {
    if (!node.isMergedIntoParent && !node.areUserActionsBlocked) {
      final data = node.getSemanticsData();
      final flags = data.flagsCollection;
      final control = (flags.isButton || flags.isLink) && !flags.isHidden;
      final disabled = flags.isEnabled == Tristate.isFalse;
      if (control && !disabled) {
        controls++;
        if (!data.hasAction(SemanticsAction.tap)) {
          final label = data.label.trim().isNotEmpty
              ? data.label
              : (data.tooltip.trim().isNotEmpty ? data.tooltip : '(unlabeled)');
          missing.add(label);
        }
      }
    }
    node.visitChildren((child) {
      walk(child);
      return true;
    });
  }

  for (final view in tester.binding.renderViews) {
    final root = view.owner!.semanticsOwner?.rootSemanticsNode;
    if (root != null) walk(root);
  }

  expect(
    controls,
    greaterThan(0),
    reason:
        'A screen with no enabled button or link passes this check vacuously.',
  );
  expect(
    missing,
    isEmpty,
    reason:
        'Enabled buttons and links need SemanticsAction.tap:\n'
        '${missing.join('\n')}',
  );
}

QuestionBank _bank({int count = 2}) {
  return QuestionBank(
    schemaVersion: 1,
    questions: [
      for (var i = 0; i < count; i++)
        TriviaQuestion(
          id: 'bom-${(i + 1).toString().padLeft(4, '0')}',
          volume: ScriptureVolume.bom,
          reference: '1 Nephi 1:${i + 1}',
          prompt: 'Prompt $i',
          options: const ['Alpha', 'Beta', 'Gamma', 'Delta'],
          answerIndex: 0,
          explanation: 'Because the record says so.',
          reviewStatus: ReviewStatus.draft,
        ),
    ],
  );
}

Future<ProviderContainer> _pumpApp(
  WidgetTester tester, {
  List<Override> overrides = const [],
  bool settle = true,
}) async {
  final container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const SaintsTriviaApp(),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return container;
}

Future<void> _failBank(ProviderContainer container) async {
  try {
    await container.read(questionBankProvider.future);
  } on Object {
    // The failed future is the state the error screen has to show.
  }
}

Future<ProviderContainer> _openSetup(
  WidgetTester tester, {
  required TargetPlatform platform,
}) async {
  await _surface(tester);
  debugDefaultTargetPlatformOverride = platform;
  addTearDown(() => debugDefaultTargetPlatformOverride = null);
  final theme = buildTheme(Brightness.light).copyWith(platform: platform);
  final container = ProviderContainer(
    overrides: [
      questionBankLoaderProvider.overrideWith(
        (ref) =>
            () async => _bank(count: 40),
      ),
    ],
  );
  addTearDown(container.dispose);
  await container.read(questionBankProvider.future);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: theme,
        routerConfig: container.read(appRouterProvider),
      ),
    ),
  );
  container.read(appRouterProvider).go(AppRoutes.setup);
  await tester.pumpAndSettle();
  return container;
}

String _countText(WidgetTester tester) {
  return tester.widget<Text>(find.byKey(const Key('setup-count'))).data!;
}

Future<ProviderContainer> _pumpGame(
  WidgetTester tester, {
  CanOpenLink? canOpen,
  OpenLink? open,
}) async {
  await _surface(tester);
  final container = ProviderContainer(
    overrides: [
      questionBankLoaderProvider.overrideWith(
        (ref) =>
            () async => _bank(),
      ),
      gameRandomProvider.overrideWith((ref) => Random(1)),
      if (canOpen != null) canOpenLinkProvider.overrideWith((ref) => canOpen),
      if (open != null) openLinkProvider.overrideWith((ref) => open),
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
  await tester.pump();
  container
      .read(appRouterProvider)
      .go(
        AppRoutes.game,
        extra: const LastGameSettings(
          volumes: [ScriptureVolume.bom],
          questionCount: 2,
        ),
      );
  await tester.pump();
  await tester.pumpAndSettle();
  return container;
}

class _HeldGame extends GameController {
  _HeldGame(this.session);

  final GameSession? session;

  @override
  GameSession? build() => session;
}

GameSession _finished() {
  const question = 'Where was the Church organized?';
  return GameSession(
    volumes: const [ScriptureVolume.bom],
    requestedCount: 1,
    questions: [
      GameQuestion(
        id: 'bom-0001',
        volume: ScriptureVolume.bom,
        reference: '1 Nephi 1:1',
        prompt: question,
        options: const ['Nephi', 'Lehi', 'Sam', 'Laman'],
        answerIndex: 0,
        explanation: 'See the reference.',
      ),
    ],
    currentIndex: 1,
    answers: const [
      GameAnswer(questionId: 'bom-0001', selectedIndex: 0, correct: true),
    ],
    score: 1,
    currentStreak: 1,
    bestStreak: 1,
  );
}

final _storedGame = FinishedGameRecord(
  score: 8,
  total: 10,
  percent: 80,
  bestStreak: 4,
  playedAt: DateTime(2026, 11, 9, 8),
  volumes: const [ScriptureVolume.bom],
  questionCount: 10,
  volumeCorrect: const {ScriptureVolume.bom: 8},
  volumeTotal: const {ScriptureVolume.bom: 10},
);
