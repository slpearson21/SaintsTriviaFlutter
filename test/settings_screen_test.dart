import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:saints_trivia_flutter/app.dart';
import 'package:saints_trivia_flutter/data/questions/scripture_volume.dart';
import 'package:saints_trivia_flutter/persistence/app_settings.dart';
import 'package:saints_trivia_flutter/persistence/finished_game_record.dart';
import 'package:saints_trivia_flutter/persistence/memory_progress_repository.dart';
import 'package:saints_trivia_flutter/persistence/progress_repository.dart';
import 'package:saints_trivia_flutter/persistence/persistence_providers.dart';
import 'package:saints_trivia_flutter/persistence/shared_preferences_progress_repository.dart';
import 'package:saints_trivia_flutter/routing/app_router.dart';
import 'package:saints_trivia_flutter/routing/routes.dart';
import 'package:saints_trivia_flutter/screens/settings_screen.dart';
import 'package:saints_trivia_flutter/services/open_link.dart';

const _guidelines = <AccessibilityGuideline>[
  androidTapTargetGuideline,
  iOSTapTargetGuideline,
  labeledTapTargetGuideline,
  textContrastGuideline,
];

final _game = FinishedGameRecord(
  score: 8,
  total: 10,
  percent: 80,
  bestStreak: 5,
  playedAt: DateTime(2026, 11, 9, 8),
  volumes: const [ScriptureVolume.bom],
  questionCount: 10,
  volumeCorrect: const {ScriptureVolume.bom: 8},
  volumeTotal: const {ScriptureVolume.bom: 10},
);

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  ProgressRepository? repo,
  OpenLink? openLink,
  Size surface = const Size(390, 844),
  double textScale = 1,
  bool openSettings = true,
}) async {
  await tester.binding.setSurfaceSize(surface);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final container = ProviderContainer(
    overrides: [
      if (repo != null) progressRepositoryProvider.overrideWithValue(repo),
      if (openLink != null) openLinkProvider.overrideWith((ref) => openLink),
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
  if (openSettings) {
    container.read(appRouterProvider).go(AppRoutes.settings);
    await tester.pumpAndSettle();
  }
  return container;
}

Switch _switch(WidgetTester tester, Key key) {
  return tester.widget<Switch>(
    find.descendant(of: find.byKey(key), matching: find.byType(Switch)),
  );
}

Future<void> _tapSwitch(WidgetTester tester, Key key) async {
  await tester.ensureVisible(
    find.descendant(of: find.byKey(key), matching: find.byType(Switch)),
  );
  await tester.tap(
    find.descendant(of: find.byKey(key), matching: find.byType(Switch)),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('toggles and theme survive a new pump of the same prefs', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = SharedPreferencesProgressRepository(prefs);

    final first = await _pump(tester, repo: repo);
    expect(_switch(tester, const Key('settings-sound')).value, isFalse);
    expect(_switch(tester, const Key('settings-haptics')).value, isTrue);
    expect(_switch(tester, const Key('settings-explanations')).value, isTrue);
    expect(
      Theme.of(tester.element(find.text('Settings'))).brightness,
      Brightness.light,
    );

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    await _tapSwitch(tester, const Key('settings-sound'));
    await _tapSwitch(tester, const Key('settings-haptics'));
    await _tapSwitch(tester, const Key('settings-explanations'));

    expect(_switch(tester, const Key('settings-sound')).value, isTrue);
    expect(_switch(tester, const Key('settings-haptics')).value, isFalse);
    expect(_switch(tester, const Key('settings-explanations')).value, isFalse);
    expect(
      Theme.of(tester.element(find.text('Settings'))).brightness,
      Brightness.dark,
    );
    expect(first.read(settingsProvider).themeMode, ThemeMode.dark);

    await tester.pumpWidget(const SizedBox.shrink());

    await _pump(tester, repo: SharedPreferencesProgressRepository(prefs));
    expect(_switch(tester, const Key('settings-sound')).value, isTrue);
    expect(_switch(tester, const Key('settings-haptics')).value, isFalse);
    expect(_switch(tester, const Key('settings-explanations')).value, isFalse);
    expect(
      Theme.of(tester.element(find.text('Settings'))).brightness,
      Brightness.dark,
    );
  });

  testWidgets('theme mode switches light, dark, and system', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await _pump(tester);
    expect(
      Theme.of(tester.element(find.text('Settings'))).brightness,
      Brightness.light,
    );

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('Settings'))).brightness,
      Brightness.dark,
    );

    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('Settings'))).brightness,
      Brightness.light,
    );

    await tester.tap(find.text('System'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('Settings'))).brightness,
      Brightness.light,
    );

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('Settings'))).brightness,
      Brightness.dark,
    );
  });

  testWidgets('reset clears stats and leaves settings', (tester) async {
    final repo = MemoryProgressRepository(
      games: [_game],
      settings: const AppSettings(soundEffects: true),
    );
    final container = await _pump(tester, repo: repo, openSettings: false);
    expect(find.text('Welcome back!'), findsOneWidget);

    container.read(appRouterProvider).go(AppRoutes.settings);
    await tester.pumpAndSettle();
    expect(_switch(tester, const Key('settings-sound')).value, isTrue);

    await tester.ensureVisible(find.byKey(const Key('settings-reset')));
    await tester.tap(find.byKey(const Key('settings-reset')));
    await tester.pumpAndSettle();
    expect(find.text('Reset all stats?'), findsOneWidget);
    expect(find.textContaining("This can't be undone."), findsOneWidget);
    await tester.tap(find.byKey(const Key('reset-cancel')));
    await tester.pumpAndSettle();
    expect(repo.readGames(), hasLength(1));
    expect(repo.readSettings().soundEffects, isTrue);

    await tester.tap(find.byKey(const Key('settings-reset')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reset-confirm')));
    await tester.pumpAndSettle();
    expect(repo.readGames(), isEmpty);
    expect(repo.readSettings().soundEffects, isTrue);
    expect(_switch(tester, const Key('settings-sound')).value, isTrue);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('No games yet'), findsOneWidget);
    expect(find.text('Welcome back!'), findsNothing);
    expect(find.text('WELCOME'), findsWidgets);
  });

  testWidgets('iOS reset dialog is destructive and Android uses an alert', (
    tester,
  ) async {
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await _pump(tester);
    await tester.ensureVisible(find.byKey(const Key('settings-reset')));
    await tester.tap(find.byKey(const Key('settings-reset')));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    expect(find.text('Reset'), findsOneWidget);
    await tester.tap(find.byKey(const Key('reset-cancel')));
    await tester.pumpAndSettle();

    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.tap(find.byKey(const Key('settings-reset')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(CupertinoAlertDialog), findsNothing);
    await tester.tap(find.byKey(const Key('reset-cancel')));
    await tester.pumpAndSettle();
  });

  testWidgets('a failed feedback launch says no mail app was found', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return FilledButton(
                onPressed: () => unawaited(
                  sendAppFeedback(context, (
                    uri, {
                    LaunchMode mode = LaunchMode.platformDefault,
                  }) async {
                    return false;
                  }),
                ),
                child: const Text('Send'),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Send'));
    await tester.pump();
    expect(find.text('No mail app was found.'), findsOneWidget);
  });

  testWidgets('settings feedback uses the platform default launch mode', (
    tester,
  ) async {
    LaunchMode? seen;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return FilledButton(
                onPressed: () => unawaited(
                  sendAppFeedback(context, (
                    uri, {
                    LaunchMode mode = LaunchMode.platformDefault,
                  }) async {
                    seen = mode;
                    return true;
                  }),
                ),
                child: const Text('Send'),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Send'));
    await tester.pump();
    expect(seen, LaunchMode.platformDefault);
  });

  testWidgets('feedback is hidden and about shows the disclaimer', (
    tester,
  ) async {
    final opened = <({Uri uri, LaunchMode mode})>[];
    await _pump(
      tester,
      openLink: (uri, {LaunchMode mode = LaunchMode.platformDefault}) async {
        opened.add((uri: uri, mode: mode));
        return true;
      },
    );

    expect(kShowSendFeedback, isFalse);
    expect(find.byKey(const Key('settings-feedback')), findsNothing);
    expect(find.text('Send feedback'), findsNothing);
    expect(find.text('Sound & haptics'), findsOneWidget);
    expect(opened, isEmpty);
    expect(feedbackRecipient, isEmpty);
    expect(feedbackUri.query, 'subject=Scripture%20Trivia%20feedback');

    await tester.scrollUntilVisible(
      find.textContaining('unofficial app'),
      200,
      scrollable: find.byType(Scrollable),
    );
    expect(find.textContaining(scriptureTriviaDisclaimer), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('settings-about')));
    await tester.tap(find.byKey(const Key('settings-about')));
    await tester.pumpAndSettle();
    expect(find.text('About Scripture Trivia'), findsWidgets);
    expect(find.textContaining('not an official product'), findsWidgets);
    expect(find.text(scriptureTriviaVersionLabel), findsWidgets);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('OK'), findsNothing);
  });

  testWidgets('settings meet tap and contrast guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    try {
      for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        debugDefaultTargetPlatformOverride = platform;
        for (final brightness in Brightness.values) {
          tester.platformDispatcher.platformBrightnessTestValue = brightness;
          await _pump(tester);
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

  testWidgets('settings do not overflow at 200% text', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    for (final surface in [const Size(393, 852), const Size(320, 568)]) {
      await _pump(tester, surface: surface, textScale: 2);
      expect(tester.takeException(), isNull, reason: '$surface');
      expect(find.byType(SegmentedButton<ThemeMode>), findsNothing);
      expect(find.text('System'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Reset stats'),
        200,
        scrollable: find.byType(Scrollable),
      );
      expect(tester.takeException(), isNull, reason: '$surface reset');
      await tester.scrollUntilVisible(
        find.textContaining('unofficial app'),
        200,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$surface scrolled');
      expect(find.textContaining(scriptureTriviaDisclaimer), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
