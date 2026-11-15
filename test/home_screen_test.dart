import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saints_trivia_flutter/data/questions/scripture_volume.dart';
import 'package:saints_trivia_flutter/progress/home_providers.dart';
import 'package:saints_trivia_flutter/progress/home_snapshot.dart';
import 'package:saints_trivia_flutter/routing/app_router.dart';
import 'package:saints_trivia_flutter/theme/st_theme.dart';

import 'pump_app.dart';

final _now = DateTime(2026, 11, 15, 9);

const _settings = LastGameSettings(
  volumes: [ScriptureVolume.dc, ScriptureVolume.bom],
  questionCount: 10,
);

final _yesterday = HomeSnapshot(
  gamesPlayed: 12,
  accuracyPercent: 84,
  bestStreak: 9,
  lastGame: LastGameSummary(
    correct: 8,
    total: 10,
    playedAt: DateTime(2026, 11, 14, 20),
  ),
  lastSettings: _settings,
);

final _nov9 = HomeSnapshot(
  gamesPlayed: 3,
  accuracyPercent: 50,
  bestStreak: 2,
  lastGame: LastGameSummary(
    correct: 4,
    total: 8,
    playedAt: DateTime(2026, 11, 9, 8),
  ),
  lastSettings: const LastGameSettings(
    volumes: [ScriptureVolume.nt],
    questionCount: 1,
  ),
);

List<Override> _returning([HomeSnapshot? snapshot]) {
  return [
    homeSnapshotProvider.overrideWith((ref) => snapshot ?? _yesterday),
    homeClockProvider.overrideWith(
      (ref) =>
          () => _now,
    ),
  ];
}

void main() {
  group('last-game date', () {
    final now = DateTime(2026, 11, 15, 15);

    test('today stays today across the clock', () {
      expect(formatLastGameDate(DateTime(2026, 11, 15, 0, 30), now), 'Today');
      expect(formatLastGameDate(DateTime(2026, 11, 15, 23), now), 'Today');
    });

    test('the previous calendar day is yesterday', () {
      expect(
        formatLastGameDate(DateTime(2026, 11, 14, 23, 30), now),
        'Yesterday',
      );
      expect(formatLastGameDate(DateTime(2026, 11, 1), now), 'Nov 1');
      expect(
        formatLastGameDate(
          DateTime(2026, 10, 31, 22),
          DateTime(2026, 11, 1, 1),
        ),
        'Yesterday',
      );
    });

    test('other days use a short English date', () {
      expect(formatLastGameDate(DateTime(2026, 11, 9), now), 'Nov 9');
      expect(formatLastGameDate(DateTime(2025, 11, 9), now), 'Nov 9, 2025');
      expect(formatLastGameDate(DateTime(2026, 11, 16), now), 'Nov 16');
    });
  });

  group('play again subtitle', () {
    test('orders volumes and abbreviates Doctrine and Covenants', () {
      expect(
        playAgainSubtitle(_settings),
        'Book of Mormon · D&C · 10 questions',
      );
    });

    test('uses the singular and keeps every other volume name', () {
      expect(
        playAgainSubtitle(
          const LastGameSettings(
            volumes: [ScriptureVolume.pgp, ScriptureVolume.ot],
            questionCount: 1,
          ),
        ),
        'Old Testament · Pearl of Great Price · 1 question',
      );
      expect(
        playAgainSubtitle(
          const LastGameSettings(
            volumes: ScriptureVolume.values,
            questionCount: 50,
          ),
        ),
        'Old Testament · New Testament · Book of Mormon · D&C · '
        'Pearl of Great Price · 50 questions',
      );
    });
  });

  testWidgets('first run is the default and hides returning rows', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('Home'), findsNothing);
    expect(find.text('WELCOME'), findsOneWidget);
    expect(find.text('Test your scripture knowledge'), findsOneWidget);
    expect(
      find.text(
        'All five volumes of scripture. Free, offline, no account needed.',
      ),
      findsOneWidget,
    );
    expect(find.text('How it works'), findsOneWidget);
    expect(find.text('HOW IT WORKS'), findsNothing);
    expect(find.text('Choose your scriptures'), findsOneWidget);
    expect(find.text('Pick one volume, a few, or all five.'), findsOneWidget);
    expect(find.text('Answer and learn'), findsOneWidget);
    expect(find.text('Track your progress'), findsOneWidget);
    expect(find.text('No games yet'), findsOneWidget);
    expect(
      find.text('Your stats will appear here after your first game.'),
      findsOneWidget,
    );
    expect(find.text('Play again'), findsNothing);
    expect(find.text('See all'), findsNothing);
    expect(find.text('Welcome back!'), findsNothing);
    expect(find.text('Your progress'), findsNothing);

    expect(
      tester.getSize(find.byKey(const Key('home-start-game'))).height,
      greaterThanOrEqualTo(52),
    );
    final hero = tester.widget<DecoratedBox>(
      find.byKey(const Key('home-hero')),
    );
    expect((hero.decoration as BoxDecoration).color, lightScheme.primary);
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('home-start-game')),
    );
    expect(
      button.style?.backgroundColor?.resolve(const <WidgetState>{}),
      lightScheme.primaryContainer,
    );
    expect(
      button.style?.foregroundColor?.resolve(const <WidgetState>{}),
      lightScheme.onPrimaryContainer,
    );
    final empty = tester.widget<DecoratedBox>(
      find.byKey(const Key('home-empty-stats')),
    );
    final emptyDecoration = empty.decoration as BoxDecoration;
    expect(emptyDecoration.color, lightScheme.surfaceContainerLow);
    expect(emptyDecoration.border, isNull);

    final statsIcon = tester.widget<Icon>(
      find.descendant(of: find.byTooltip('Stats'), matching: find.byType(Icon)),
    );
    expect(statsIcon.color, lightScheme.onSurfaceVariant);
    expect(statsIcon.applyTextScaling, isFalse);
    expect(
      tester.getSize(find.byTooltip('Stats')).shortestSide,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('returning home shows last settings and the snapshot', (
    tester,
  ) async {
    await pumpApp(tester, overrides: _returning());

    expect(find.text('READY WHEN YOU ARE'), findsOneWidget);
    expect(find.text('Welcome back!'), findsOneWidget);
    expect(
      find.text('Up to 50 questions from the scriptures you choose.'),
      findsOneWidget,
    );
    expect(find.text('Play again'), findsOneWidget);
    expect(find.text('Book of Mormon · D&C · 10 questions'), findsOneWidget);
    expect(find.text('Your progress'), findsOneWidget);
    expect(find.text('See all'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('84%'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
    expect(find.text('Games'), findsOneWidget);
    expect(find.text('Accuracy'), findsOneWidget);
    expect(find.text('Best streak'), findsOneWidget);
    expect(find.text('Last game: 8 / 10 · Yesterday'), findsOneWidget);
    expect(find.text('WELCOME'), findsNothing);
    expect(find.text('How it works'), findsNothing);
    expect(find.text('No games yet'), findsNothing);
    expect(find.text('Choose your scriptures'), findsNothing);

    final games = tester.getRect(find.text('Games'));
    final accuracy = tester.getRect(find.text('Accuracy'));
    expect(accuracy.left, greaterThanOrEqualTo(games.right - 1));
    expect(accuracy.center.dy, closeTo(games.center.dy, 4));
    expect(
      tester.getSize(find.widgetWithText(TextButton, 'See all')).height,
      greaterThanOrEqualTo(52),
    );
  });

  testWidgets('last-game date follows the snapshot, not a fixed word', (
    tester,
  ) async {
    await pumpApp(tester, overrides: _returning(_nov9));

    expect(find.text('3'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('New Testament · 1 question'), findsOneWidget);
    expect(find.text('Last game: 4 / 8 · Nov 9'), findsOneWidget);
    expect(find.textContaining('Yesterday'), findsNothing);
  });

  testWidgets('dark hero uses the container fill and a light pill', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await pumpApp(tester);

    final hero = tester.widget<DecoratedBox>(
      find.byKey(const Key('home-hero')),
    );
    expect(
      (hero.decoration as BoxDecoration).color,
      darkScheme.primaryContainer,
    );
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('home-start-game')),
    );
    expect(
      button.style?.backgroundColor?.resolve(const <WidgetState>{}),
      darkScheme.onPrimaryContainer,
    );
    expect(
      button.style?.foregroundColor?.resolve(const <WidgetState>{}),
      darkScheme.onPrimary,
    );
  });

  testWidgets('start, stats, and settings open the existing routes', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Start a game'));
    await tester.pumpAndSettle();
    expect(
      find.text('Volume picker and question count will go here.'),
      findsOneWidget,
    );
    expect(
      GoRouterState.of(tester.element(find.text('Game setup'))).extra,
      isNull,
    );

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Stats'));
    await tester.pumpAndSettle();
    expect(
      find.text('On-device stats will go here. No games yet.'),
      findsOneWidget,
    );

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Appearance follows the system'),
      findsOneWidget,
    );
  });

  testWidgets('see all opens stats and play again carries last settings', (
    tester,
  ) async {
    await pumpApp(tester, overrides: _returning());

    await tester.tap(find.text('See all'));
    await tester.pumpAndSettle();
    expect(
      find.text('On-device stats will go here. No games yet.'),
      findsOneWidget,
    );
    expect(find.text('Play again'), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Play again'));
    await tester.pumpAndSettle();
    expect(
      find.text('Volume picker and question count will go here.'),
      findsOneWidget,
    );
    expect(
      GoRouterState.of(tester.element(find.text('Game setup'))).extra,
      _settings,
    );
  });

  testWidgets('iOS home uses the large title and uppercase section labels', (
    tester,
  ) async {
    final container = await _pumpHome(
      tester,
      platform: TargetPlatform.iOS,
      brightness: Brightness.light,
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    });

    expect(find.text('HOW IT WORKS'), findsOneWidget);
    expect(find.text('How it works'), findsNothing);
    expect(find.text('Scripture Trivia'), findsOneWidget);
    final title = tester.widget<Text>(find.text('Scripture Trivia'));
    expect(title.style?.fontFamily, 'SourceSerif4');
    expect(title.style?.fontSize, 28);

    final statsIcon = tester.widget<Icon>(
      find.descendant(of: find.byTooltip('Stats'), matching: find.byType(Icon)),
    );
    expect(statsIcon.color, lightScheme.primary);
    expect(
      tester.getSize(find.byTooltip('Stats')).shortestSide,
      greaterThanOrEqualTo(44),
    );

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('home does not overflow at 200% text', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      for (final brightness in Brightness.values) {
        for (final firstRun in [true, false]) {
          final reason = '$platform $brightness firstRun=$firstRun';
          final container = await _pumpHome(
            tester,
            platform: platform,
            brightness: brightness,
            textScale: 2,
            surface: const Size(360, 640),
            snapshot: firstRun ? const HomeSnapshot.firstRun() : _yesterday,
          );
          expect(tester.takeException(), isNull, reason: reason);
          expect(
            tester.getSize(find.byKey(const Key('home-start-game'))).height,
            greaterThanOrEqualTo(52),
            reason: reason,
          );
          _expectTitleFits(
            tester,
            reason,
            wraps: platform == TargetPlatform.iOS,
          );

          final settingsIcon = find.descendant(
            of: find.byTooltip('Settings'),
            matching: find.byType(Icon),
          );
          final icon = tester.widget<Icon>(settingsIcon);
          expect(icon.applyTextScaling, isFalse, reason: reason);
          expect(icon.size, 24, reason: reason);
          expect(tester.getSize(settingsIcon).height, 24, reason: reason);

          final scrollable = find.byType(Scrollable);
          expect(scrollable, findsOneWidget, reason: reason);
          expect(
            tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
            greaterThan(0),
            reason: reason,
          );

          if (firstRun) {
            await tester.scrollUntilVisible(
              find.text('No games yet'),
              400,
              scrollable: scrollable,
            );
            expect(find.text('No games yet'), findsOneWidget, reason: reason);
          } else {
            _expectStacked(tester, reason);
            expect(
              tester.getSize(find.widgetWithText(TextButton, 'See all')).height,
              greaterThanOrEqualTo(52),
              reason: reason,
            );
            await tester.scrollUntilVisible(
              find.text('Last game: 8 / 10 · Yesterday'),
              400,
              scrollable: scrollable,
            );
            expect(find.text('Best streak'), findsOneWidget, reason: reason);
          }
          expect(tester.takeException(), isNull, reason: reason);

          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
        }
      }
    }
  });
}

void _expectStacked(WidgetTester tester, String reason) {
  final games = tester.getRect(find.text('Games'));
  final accuracy = tester.getRect(find.text('Accuracy'));
  final streak = tester.getRect(find.text('Best streak'));
  expect(accuracy.top, greaterThanOrEqualTo(games.bottom - 1), reason: reason);
  expect(streak.top, greaterThanOrEqualTo(accuracy.bottom - 1), reason: reason);
}

void _expectTitleFits(
  WidgetTester tester,
  String reason, {
  required bool wraps,
}) {
  const title = 'Scripture Trivia';
  final paragraph = tester.renderObject<RenderParagraph>(find.text(title));
  expect(paragraph.didExceedMaxLines, isFalse, reason: reason);
  final space = title.indexOf(' ');
  final first = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: space),
  );
  final second = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: space + 1, extentOffset: title.length),
  );
  expect(first, isNotEmpty, reason: reason);
  expect(second, isNotEmpty, reason: reason);
  if (wraps) {
    expect(first.first.top, lessThan(second.first.top), reason: reason);
  }
}

Future<ProviderContainer> _pumpHome(
  WidgetTester tester, {
  required TargetPlatform platform,
  required Brightness brightness,
  HomeSnapshot snapshot = const HomeSnapshot.firstRun(),
  double textScale = 1,
  Size surface = const Size(800, 600),
}) async {
  await tester.binding.setSurfaceSize(surface);
  final container = ProviderContainer(
    overrides: [
      homeSnapshotProvider.overrideWith((ref) => snapshot),
      homeClockProvider.overrideWith(
        (ref) =>
            () => _now,
      ),
    ],
  );
  final theme = buildTheme(brightness).copyWith(platform: platform);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: theme,
        themeMode: ThemeMode.light,
        routerConfig: container.read(appRouterProvider),
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          );
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}
