import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saints_trivia_flutter/app.dart';
import 'package:saints_trivia_flutter/data/questions/scripture_volume.dart';
import 'package:saints_trivia_flutter/persistence/finished_game_record.dart';
import 'package:saints_trivia_flutter/persistence/memory_progress_repository.dart';
import 'package:saints_trivia_flutter/persistence/persistence_providers.dart';
import 'package:saints_trivia_flutter/progress/home_providers.dart';
import 'package:saints_trivia_flutter/routing/app_router.dart';
import 'package:saints_trivia_flutter/routing/routes.dart';

const _guidelines = <AccessibilityGuideline>[
  androidTapTargetGuideline,
  iOSTapTargetGuideline,
  labeledTapTargetGuideline,
  textContrastGuideline,
];

final _now = DateTime(2026, 11, 15, 9);

final _games = <FinishedGameRecord>[
  FinishedGameRecord(
    score: 8,
    total: 10,
    percent: 80,
    bestStreak: 4,
    playedAt: DateTime(2026, 11, 9, 8),
    volumes: const [ScriptureVolume.bom],
    questionCount: 10,
    volumeCorrect: const {ScriptureVolume.bom: 8},
    volumeTotal: const {ScriptureVolume.bom: 10},
  ),
  FinishedGameRecord(
    score: 10,
    total: 10,
    percent: 100,
    bestStreak: 9,
    playedAt: DateTime(2026, 11, 14, 20),
    volumes: const [ScriptureVolume.nt, ScriptureVolume.ot],
    questionCount: 10,
    volumeCorrect: const {ScriptureVolume.ot: 6, ScriptureVolume.nt: 4},
    volumeTotal: const {ScriptureVolume.ot: 6, ScriptureVolume.nt: 4},
  ),
];

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  MemoryProgressRepository? repo,
  Size surface = const Size(390, 844),
  double textScale = 1,
}) async {
  await tester.binding.setSurfaceSize(surface);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final container = ProviderContainer(
    overrides: [
      if (repo != null) progressRepositoryProvider.overrideWithValue(repo),
      homeClockProvider.overrideWith(
        (ref) =>
            () => _now,
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const SaintsTriviaApp(),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('empty stats offers a first game', (tester) async {
    final container = await _pump(tester);
    container.read(appRouterProvider).go(AppRoutes.stats);
    await tester.pumpAndSettle();

    expect(find.text('No stats yet'), findsOneWidget);
    expect(
      find.textContaining('Play your first game to see your'),
      findsOneWidget,
    );
    expect(find.text('Stats are saved on this device only.'), findsOneWidget);
    expect(find.text('Games played'), findsNothing);

    await tester.tap(find.byKey(const Key('stats-start')));
    await tester.pumpAndSettle();
    expect(find.text('New game'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('populated stats show totals, the best game, and volumes', (
    tester,
  ) async {
    final container = await _pump(
      tester,
      repo: MemoryProgressRepository(games: _games),
    );
    container.read(appRouterProvider).go(AppRoutes.stats);
    await tester.pumpAndSettle();

    expect(find.text('12'), findsNothing);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('20'), findsOneWidget);
    expect(find.text('90%'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
    expect(find.text('Games played'), findsOneWidget);
    expect(find.text('Questions answered'), findsOneWidget);
    expect(find.text('Best streak'), findsOneWidget);
    expect(
      find.text('10 / 10 · Old Testament · New Testament · Yesterday'),
      findsOneWidget,
    );
    expect(find.text('Old Testament'), findsOneWidget);
    expect(find.text('6/6'), findsOneWidget);
    expect(find.text('New Testament'), findsOneWidget);
    expect(find.text('4/4'), findsOneWidget);
    expect(find.text('Book of Mormon'), findsOneWidget);
    expect(find.text('8/10'), findsOneWidget);
    expect(find.text('Doctrine and Covenants'), findsNothing);
    expect(find.text('Stats are saved on this device only.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stats meet tap and contrast guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    try {
      for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        debugDefaultTargetPlatformOverride = platform;
        for (final brightness in Brightness.values) {
          tester.platformDispatcher.platformBrightnessTestValue = brightness;
          final empty = await _pump(tester);
          empty.read(appRouterProvider).go(AppRoutes.stats);
          await tester.pumpAndSettle();
          for (final guideline in _guidelines) {
            await expectLater(tester, meetsGuideline(guideline));
          }
          await tester.pumpWidget(const SizedBox.shrink());

          final populated = await _pump(
            tester,
            repo: MemoryProgressRepository(games: _games),
          );
          populated.read(appRouterProvider).go(AppRoutes.stats);
          await tester.pumpAndSettle();
          for (final guideline in _guidelines) {
            await expectLater(tester, meetsGuideline(guideline));
          }
          await tester.pumpWidget(const SizedBox.shrink());
        }
      }
    } finally {
      handle.dispose();
    }
  });

  testWidgets('stats do not overflow at 200% text', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    for (final surface in [const Size(393, 852), const Size(320, 568)]) {
      final empty = await _pump(tester, surface: surface, textScale: 2);
      empty.read(appRouterProvider).go(AppRoutes.stats);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$surface empty');
      expect(find.text('No stats yet'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());

      final populated = await _pump(
        tester,
        surface: surface,
        textScale: 2,
        repo: MemoryProgressRepository(games: _games),
      );
      populated.read(appRouterProvider).go(AppRoutes.stats);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$surface populated');
      expect(find.text('Questions answered'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Book of Mormon'),
        200,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$surface scrolled');
      expect(find.text('Book of Mormon'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
