import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saints_trivia_flutter/app.dart';
import 'package:saints_trivia_flutter/data/questions/question_bank_provider.dart';
import 'package:saints_trivia_flutter/data/questions/questions.dart';
import 'package:saints_trivia_flutter/game/game_providers.dart';
import 'package:saints_trivia_flutter/progress/home_snapshot.dart';
import 'package:saints_trivia_flutter/routing/app_router.dart';
import 'package:saints_trivia_flutter/routing/routes.dart';
import 'package:saints_trivia_flutter/screens/game_screen.dart';
import 'package:saints_trivia_flutter/theme/st_theme.dart';

QuestionBank _bank({
  int ot = 40,
  int nt = 30,
  int bom = 20,
  int dc = 15,
  int pgp = 23,
}) {
  final counts = {
    ScriptureVolume.ot: ot,
    ScriptureVolume.nt: nt,
    ScriptureVolume.bom: bom,
    ScriptureVolume.dc: dc,
    ScriptureVolume.pgp: pgp,
  };
  return QuestionBank(
    schemaVersion: 1,
    questions: [
      for (final entry in counts.entries)
        for (var i = 0; i < entry.value; i++)
          TriviaQuestion(
            id: '${entry.key.idPrefix}-${(i + 1).toString().padLeft(4, '0')}',
            volume: entry.key,
            reference: 'Ref ${i + 1}',
            prompt: 'Prompt ${entry.key.code} ${i + 1}',
            options: const ['Amos', 'Nephi', 'Alma', 'Moroni'],
            answerIndex: 0,
            explanation: 'Because.',
            reviewStatus: ReviewStatus.draft,
          ),
    ],
  );
}

Future<ProviderContainer> _openSetup(
  WidgetTester tester, {
  QuestionBank? bank,
  LastGameSettings? extra,
  double textScale = 1,
  Size surface = const Size(800, 900),
  Random? random,
  TargetPlatform? platform,
}) async {
  await tester.binding.setSurfaceSize(surface);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  final container = ProviderContainer(
    overrides: [
      if (bank != null)
        questionBankLoaderProvider.overrideWith(
          (ref) =>
              () async => bank,
        ),
      if (random != null) gameRandomProvider.overrideWith((ref) => random),
    ],
  );
  addTearDown(container.dispose);
  if (bank != null) {
    await container.read(questionBankProvider.future);
  }
  final child = platform == null
      ? const SaintsTriviaApp()
      : MaterialApp.router(
          theme: buildTheme(Brightness.light).copyWith(platform: platform),
          routerConfig: container.read(appRouterProvider),
        );
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: child),
  );
  container.read(appRouterProvider).go(AppRoutes.setup, extra: extra);
  await tester.pumpAndSettle();
  return container;
}

String _countText(WidgetTester tester) {
  return tester.widget<Text>(find.byKey(const Key('setup-count'))).data!;
}

Checkbox _checkbox(WidgetTester tester, Key key) {
  return tester.widget<Checkbox>(
    find.descendant(of: find.byKey(key), matching: find.byType(Checkbox)),
  );
}

IconButton _stepper(WidgetTester tester, String tooltip) {
  return tester.widget<IconButton>(
    find.ancestor(
      of: find.byTooltip(tooltip),
      matching: find.byType(IconButton),
    ),
  );
}

Finder _presetCheck(int preset) {
  return find.descendant(
    of: find.byKey(Key('setup-preset-$preset')),
    matching: find.byIcon(Icons.check),
  );
}

void main() {
  testWidgets('start is disabled when nothing is selected', (tester) async {
    await _openSetup(tester, bank: _bank());

    await tester.tap(find.text('Select all'));
    await tester.pumpAndSettle();

    expect(find.text('0 of 5 selected'), findsOneWidget);
    expect(find.text('Choose at least one book of scripture'), findsOneWidget);
    expect(find.text('Start game'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('setup-start')))
          .onPressed,
      isNull,
    );
    expect(_countText(tester), '10');
  });

  testWidgets('select all is tri-state', (tester) async {
    await _openSetup(tester, bank: _bank());

    expect(find.text('5 of 5 selected'), findsOneWidget);
    expect(_checkbox(tester, const Key('setup-select-all')).value, isTrue);

    await tester.tap(find.text('Old Testament'));
    await tester.pumpAndSettle();

    expect(find.text('4 of 5 selected'), findsOneWidget);
    expect(_checkbox(tester, const Key('setup-select-all')).value, isNull);
    expect(_checkbox(tester, const Key('setup-check-ot')).value, isFalse);

    await tester.tap(find.text('Select all'));
    await tester.pumpAndSettle();

    expect(find.text('5 of 5 selected'), findsOneWidget);
    expect(_checkbox(tester, const Key('setup-select-all')).value, isTrue);
    expect(_checkbox(tester, const Key('setup-check-ot')).value, isTrue);

    await tester.tap(find.text('Select all'));
    await tester.pumpAndSettle();

    expect(find.text('0 of 5 selected'), findsOneWidget);
    expect(_checkbox(tester, const Key('setup-select-all')).value, isFalse);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('setup-start')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('a smaller selection clamps the count and shows a warning', (
    tester,
  ) async {
    await _openSetup(tester, bank: _bank());

    await tester.tap(find.byKey(const Key('setup-preset-50')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select all'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pearl of Great Price'));
    await tester.pumpAndSettle();

    expect(_countText(tester), '23');
    expect(
      find.text(
        'Pearl of Great Price has 23 questions, so this game will have 23.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Only 23 questions available for this selection'),
      findsOneWidget,
    );
    expect(find.text('Start game · 23 questions'), findsOneWidget);
    expect(_stepper(tester, 'More questions').onPressed, isNull);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('setup-start')))
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.byTooltip('More questions'));
    await tester.pumpAndSettle();
    expect(_countText(tester), '23');

    await tester.tap(find.byKey(const Key('setup-preset-50')));
    await tester.pumpAndSettle();
    expect(_countText(tester), '23');

    await tester.tap(find.byKey(const Key('setup-preset-20')));
    await tester.pumpAndSettle();
    expect(_countText(tester), '20');
    expect(find.byKey(const Key('setup-clamp-banner')), findsNothing);
  });

  testWidgets('the count cannot pass 50', (tester) async {
    await _openSetup(
      tester,
      bank: _bank(ot: 80, nt: 40, bom: 10, dc: 10, pgp: 10),
    );

    await tester.tap(find.byKey(const Key('setup-preset-50')));
    await tester.pumpAndSettle();

    expect(_countText(tester), '50');
    expect(find.text('50 is the maximum'), findsOneWidget);
    expect(_stepper(tester, 'More questions').onPressed, isNull);
    expect(_presetCheck(50), findsOneWidget);

    await tester.tap(find.byTooltip('More questions'));
    await tester.pumpAndSettle();
    expect(_countText(tester), '50');
    expect(find.textContaining('51'), findsNothing);
  });

  testWidgets('presets set the question count', (tester) async {
    await _openSetup(tester, bank: _bank());

    Future<void> choose(int preset) async {
      await tester.tap(find.byKey(Key('setup-preset-$preset')));
      await tester.pumpAndSettle();
      expect(_countText(tester), '$preset');
      expect(_presetCheck(preset), findsOneWidget);
    }

    await choose(5);
    await choose(20);
    await choose(10);
    await choose(50);
    expect(_presetCheck(10), findsNothing);
  });

  testWidgets('volume rows show their question counts', (tester) async {
    await _openSetup(
      tester,
      bank: _bank(ot: 1180, nt: 1, bom: 0, dc: 12, pgp: 23),
    );

    expect(find.text('1,180 questions'), findsOneWidget);
    expect(find.text('1 question'), findsOneWidget);
    expect(find.text('0 questions'), findsOneWidget);
  });

  testWidgets('play again opens with the saved volumes', (tester) async {
    await _openSetup(
      tester,
      bank: _bank(),
      extra: const LastGameSettings(
        volumes: [ScriptureVolume.dc, ScriptureVolume.bom],
        questionCount: 10,
      ),
    );

    expect(find.text('2 of 5 selected'), findsOneWidget);
    expect(_checkbox(tester, const Key('setup-check-bom')).value, isTrue);
    expect(_checkbox(tester, const Key('setup-check-dc')).value, isTrue);
    expect(_checkbox(tester, const Key('setup-check-ot')).value, isFalse);
    expect(_countText(tester), '10');
  });

  testWidgets('start stays on screen at text scale 1.5', (tester) async {
    const surface = Size(360, 640);
    await _openSetup(tester, bank: _bank(), textScale: 1.5, surface: surface);

    expect(tester.takeException(), isNull);
    final start = find.byKey(const Key('setup-start'));
    final pinned = tester.getRect(start);
    expect(pinned.top, greaterThanOrEqualTo(0));
    expect(pinned.bottom, lessThanOrEqualTo(surface.height));
    expect(pinned.height, greaterThanOrEqualTo(52));

    final scrollable = find.byType(Scrollable);
    expect(
      tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
      greaterThan(0),
    );

    final five = tester.getRect(find.byKey(const Key('setup-preset-5')));
    final ten = tester.getRect(find.byKey(const Key('setup-preset-10')));
    final twenty = tester.getRect(find.byKey(const Key('setup-preset-20')));
    expect(ten.left, greaterThan(five.left));
    expect(twenty.top, greaterThan(five.bottom - 1));

    final count = tester.getRect(find.byKey(const Key('setup-count')));
    final label = tester.getRect(find.byKey(const Key('setup-count-label')));
    expect(label.top, greaterThanOrEqualTo(count.bottom - 1));

    expect(
      tester.getSize(find.byTooltip('More questions')).shortestSide,
      greaterThanOrEqualTo(48),
    );

    await tester.drag(scrollable, const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(tester.getRect(start), pinned);
  });

  testWidgets('start deals the game before the question screen opens', (
    tester,
  ) async {
    final random = Random(7);
    final bank = _bank();
    final container = await _openSetup(tester, bank: bank, random: random);
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

    await tester.tap(find.text('Select all'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Book of Mormon'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('setup-start')));

    final dealt = container.read(gameControllerProvider)!;
    expect(dealt.volumes, [ScriptureVolume.bom]);
    expect(dealt.requestedCount, 10);
    expect(dealt.questions, isNotEmpty);
    final dealtIds = dealt.questions.map((question) => question.id).toList();
    expect(dealtIds, isNot(finished));

    await tester.pumpAndSettle();

    expect(find.byType(GameScreen), findsOneWidget);
    expect(find.text('Question'), findsOneWidget);
    expect(
      container
          .read(gameControllerProvider)!
          .questions
          .map((question) => question.id)
          .toList(),
      dealtIds,
    );
  });

  testWidgets('a failed bank replaces setup with the content error', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        questionBankLoaderProvider.overrideWith(
          (ref) =>
              () async => throw Exception('unreadable'),
        ),
      ],
    );
    addTearDown(container.dispose);
    try {
      await container.read(questionBankProvider.future);
    } on Object {
      // The failed future is the state this screen has to refuse.
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SaintsTriviaApp(),
      ),
    );
    container.read(appRouterProvider).go(AppRoutes.setup);
    await tester.pumpAndSettle();

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.byKey(const Key('setup-start')), findsNothing);
    expect(find.text('5 of 5 selected'), findsNothing);
  });

  testWidgets('presets and the stepper announce selection and the count', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    try {
      await _openSetup(
        tester,
        bank: _bank(ot: 0, nt: 0, bom: 0, dc: 0, pgp: 23),
      );

      expect(
        tester.getSemantics(find.byKey(const Key('setup-preset-10'))),
        matchesSemantics(
          label: '10 questions',
          textDirection: TextDirection.ltr,
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          isEnabled: true,
          hasEnabledState: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.byKey(const Key('setup-preset-50'))),
        matchesSemantics(
          label: '50 questions',
          textDirection: TextDirection.ltr,
          isButton: true,
          hasSelectedState: true,
          hasEnabledState: true,
        ),
      );

      final scheme = Theme.of(
        tester.element(find.byKey(const Key('setup-preset-50'))),
      ).colorScheme;
      final disabled = scheme.onSurface.withValues(alpha: 0.38);
      final material = tester.widget<Material>(
        find.byKey(const Key('setup-preset-50')),
      );
      expect((material.shape! as RoundedRectangleBorder).side.color, disabled);
      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: find.byKey(const Key('setup-preset-50')),
                matching: find.text('50'),
              ),
            )
            .style
            ?.color,
        disabled,
      );

      expect(
        tester.getSemantics(find.byKey(const Key('setup-count'))),
        matchesSemantics(
          label: '10 questions',
          textDirection: TextDirection.ltr,
          isLiveRegion: true,
        ),
      );
      expect(
        tester.getSemantics(find.byTooltip('More questions')),
        matchesSemantics(
          label: 'More questions',
          value: '10 questions',
          textDirection: TextDirection.ltr,
          isButton: true,
          isEnabled: true,
          hasEnabledState: true,
          hasTapAction: true,
        ),
      );

      await tester.tap(find.byTooltip('More questions'));
      await tester.pumpAndSettle();

      expect(_countText(tester), '11');
      expect(
        tester.getSemantics(find.byTooltip('More questions')),
        matchesSemantics(
          label: 'More questions',
          value: '11 questions',
          textDirection: TextDirection.ltr,
          isButton: true,
          isEnabled: true,
          hasEnabledState: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.byKey(const Key('setup-count'))),
        matchesSemantics(
          label: '11 questions',
          textDirection: TextDirection.ltr,
          isLiveRegion: true,
        ),
      );
    } finally {
      handle.dispose();
    }
  });

  testWidgets('iOS uses check circles and Android uses checkboxes', (
    tester,
  ) async {
    await _openSetup(tester, bank: _bank(), platform: TargetPlatform.iOS);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.text('CHOOSE SCRIPTURES'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);

    await _openSetup(tester, bank: _bank(), platform: TargetPlatform.android);
    expect(find.byType(Checkbox), findsWidgets);
    expect(find.text('Choose scriptures'), findsOneWidget);
    expect(find.text('Home'), findsNothing);
  });
}
