import 'dart:math';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saints_trivia_flutter/app.dart';
import 'package:saints_trivia_flutter/data/questions/question_bank_provider.dart';
import 'package:saints_trivia_flutter/data/questions/questions.dart';
import 'package:saints_trivia_flutter/game/game_providers.dart';
import 'package:saints_trivia_flutter/progress/home_snapshot.dart';
import 'package:saints_trivia_flutter/routing/app_router.dart';
import 'package:saints_trivia_flutter/routing/routes.dart';
import 'package:saints_trivia_flutter/theme/st_theme.dart';

import '../pump_app.dart';

QuestionBank _bank(
  int count, {
  String reference = '1 Nephi 1:1',
  String explanation = 'Because the record says so.',
}) {
  return QuestionBank(
    schemaVersion: 1,
    questions: [
      for (var i = 0; i < count; i++)
        TriviaQuestion(
          id: 'bom-${(i + 1).toString().padLeft(4, '0')}',
          volume: ScriptureVolume.bom,
          reference: i == 0 ? reference : '1 Nephi 1:${i + 1}',
          prompt: 'Prompt $i',
          options: const ['Alpha', 'Beta', 'Gamma', 'Delta'],
          answerIndex: 0,
          explanation: explanation,
          reviewStatus: ReviewStatus.draft,
        ),
    ],
  );
}

LastGameSettings _settings(int count) {
  return LastGameSettings(
    volumes: const [ScriptureVolume.bom],
    questionCount: count,
  );
}

Future<ProviderContainer> _pumpGame(
  WidgetTester tester, {
  required QuestionBank bank,
  required LastGameSettings settings,
  Random? random,
  bool open = true,
  double textScale = 1,
  Size surface = const Size(400, 800),
  FakeAccessibilityFeatures? accessibility,
  Brightness? brightness,
  TargetPlatform? platform,
  List<Override> overrides = const [],
}) async {
  await tester.binding.setSurfaceSize(surface);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  if (accessibility != null) {
    tester.platformDispatcher.accessibilityFeaturesTestValue = accessibility;
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  if (brightness != null) {
    tester.platformDispatcher.platformBrightnessTestValue = brightness;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  }
  if (platform != null) {
    captureAppThemes();
    debugDefaultTargetPlatformOverride = platform;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
  }

  final container = ProviderContainer(
    overrides: [
      questionBankLoaderProvider.overrideWith(
        (ref) =>
            () async => bank,
      ),
      if (random != null) gameRandomProvider.overrideWith((ref) => random),
      ...overrides,
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
  if (!open) return container;

  container.read(appRouterProvider).go(AppRoutes.game, extra: settings);
  await tester.pump();
  await tester.pump();
  return container;
}

void _expectAnswerLocked(WidgetTester tester) {
  for (var i = 0; i < 4; i++) {
    expect(
      tester.widget<InkWell>(find.byKey(ValueKey('answer-$i'))).onTap,
      isNull,
      reason: 'answer $i stays tappable',
    );
  }
}

Future<List<String>> _captureAnnouncements(WidgetTester tester) async {
  final messages = <String>[];
  tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(
    SystemChannels.accessibility,
    (Object? message) async {
      if (message is Map && message['type'] == 'announce') {
        final data = message['data'];
        if (data is Map && data['message'] is String) {
          messages.add(data['message'] as String);
        }
      }
      return null;
    },
  );
  addTearDown(() {
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(
      SystemChannels.accessibility,
      null,
    );
  });
  return messages;
}

void main() {
  test('answer sounds stay off by default', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(soundEffectsEnabledProvider), isFalse);
    expect(container.read(hapticsEnabledProvider), isTrue);
    expect(container.read(showExplanationsProvider), isTrue);
    expect(
      () => playAnswerSound(enabled: false, correct: true),
      returnsNormally,
    );
    expect(
      () => playAnswerSound(enabled: true, correct: false),
      returnsNormally,
    );
  });

  testWidgets('haptics off skips the vibration, and the default plays it', (
    tester,
  ) async {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          calls.add('${call.arguments}');
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    await _pumpGame(
      tester,
      bank: _bank(1),
      settings: _settings(1),
      random: Random(1),
      overrides: [hapticsEnabledProvider.overrideWith((ref) => false)],
    );
    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();
    expect(calls, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    calls.clear();
    await _pumpGame(
      tester,
      bank: _bank(1),
      settings: _settings(1),
      random: Random(1),
    );
    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();
    expect(calls, ['HapticFeedbackType.lightImpact']);
  });

  testWidgets(
    'turning explanations off hides the sentence and keeps the reference',
    (tester) async {
      await _pumpGame(
        tester,
        bank: _bank(1),
        settings: _settings(1),
        random: Random(1),
        overrides: [showExplanationsProvider.overrideWith((ref) => false)],
      );

      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('explanation')), findsNothing);
      expect(find.byKey(const Key('reference-chip')), findsOneWidget);
      expect(find.text('1 Nephi 1:1'), findsOneWidget);
    },
  );

  testWidgets('a correct answer shows the icon, tag, and reference', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final announcements = await _captureAnnouncements(tester);
      final container = await _pumpGame(
        tester,
        bank: _bank(2),
        settings: _settings(2),
        random: Random(1),
      );

      expect(find.text('Question 1 of 2'), findsOneWidget);
      expect(find.text('Book of Mormon'), findsOneWidget);
      expect(find.byKey(const Key('reference-chip')), findsNothing);
      expect(find.text('1 Nephi 1:1'), findsNothing);

      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();

      final session = container.read(gameControllerProvider)!;
      final question = session.questions[session.currentIndex - 1];
      final button = find.byKey(ValueKey('answer-${question.answerIndex}'));
      expect(
        find.descendant(of: button, matching: find.byIcon(Icons.check)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: button, matching: find.text('Correct')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('reference-chip')), findsOneWidget);
      expect(find.text('1 Nephi 1:1'), findsOneWidget);
      expect(find.text('Because the record says so.'), findsOneWidget);
      expect(find.text('Correct!'), findsOneWidget);
      _expectAnswerLocked(tester);
      expect(announcements, ['Correct']);
      expect(
        tester
            .widgetList<Icon>(find.byIcon(Icons.check))
            .map((icon) => icon.size),
        contains(32),
      );

      final colors = Theme.of(tester.element(button)).extension<StColors>()!;
      expect(
        tester
            .widget<Text>(find.byKey(const Key('result-headline')))
            .style
            ?.color,
        colors.correct,
      );
      expect(
        tester
            .widget<Material>(
              find.byKey(ValueKey('answer-fill-${question.answerIndex}')),
            )
            .color,
        colors.correctContainer,
      );
      expect(colors.correctContainer, StColors.light.correctContainer);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('correct feedback uses the dark theme tokens', (tester) async {
    final container = await _pumpGame(
      tester,
      bank: _bank(1),
      settings: _settings(1),
      random: Random(1),
      brightness: Brightness.dark,
    );

    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();

    final session = container.read(gameControllerProvider)!;
    final index = session.questions.single.answerIndex;
    final button = find.byKey(ValueKey('answer-$index'));
    final colors = Theme.of(tester.element(button)).extension<StColors>()!;
    expect(colors.correctContainer, StColors.dark.correctContainer);
    expect(
      tester.widget<Material>(find.byKey(ValueKey('answer-fill-$index'))).color,
      StColors.dark.correctContainer,
    );
    expect(
      tester
          .widget<Icon>(
            find.descendant(of: button, matching: find.byIcon(Icons.check)),
          )
          .color,
      StColors.dark.correct,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('result-headline')))
          .style
          ?.color,
      StColors.dark.correct,
    );
  });

  testWidgets('a wrong answer marks your pick and reveals the correct one', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final announcements = await _captureAnnouncements(tester);
      final container = await _pumpGame(
        tester,
        bank: _bank(1),
        settings: _settings(1),
        random: Random(2),
      );
      final question = container.read(gameControllerProvider)!.questions.single;
      final wrongIndex = question.options.indexOf('Beta');

      await tester.tap(find.text('Beta'));
      await tester.pumpAndSettle();

      final yours = find.byKey(ValueKey('answer-$wrongIndex'));
      final correct = find.byKey(ValueKey('answer-${question.answerIndex}'));
      expect(
        find.descendant(of: yours, matching: find.text('Your answer')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: yours, matching: find.byIcon(Icons.close)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: correct, matching: find.text('Correct answer')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: correct, matching: find.text('Correct')),
        findsNothing,
      );
      expect(
        find.descendant(of: correct, matching: find.byIcon(Icons.check)),
        findsOneWidget,
      );
      _expectAnswerLocked(tester);

      final colors = Theme.of(tester.element(yours)).extension<StColors>()!;
      expect(
        tester
            .widget<Material>(find.byKey(ValueKey('answer-fill-$wrongIndex')))
            .color,
        colors.wrongContainer,
      );
      expect(find.text('Not quite'), findsOneWidget);
      expect(find.text('The answer is Alpha.'), findsOneWidget);
      final answerLine = tester.widget<Text>(find.text('The answer is Alpha.'));
      final spans = (answerLine.textSpan! as TextSpan).children!;
      final bold = spans.whereType<TextSpan>().singleWhere(
        (span) => span.text == 'Alpha',
      );
      expect(bold.style?.fontWeight, FontWeight.w700);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('result-headline')))
            .style
            ?.color,
        colors.wrong,
      );
      expect(announcements, ['Not quite. The answer is Alpha.']);
      expect(
        tester
            .widgetList<Icon>(find.byIcon(Icons.close))
            .map((icon) => icon.size),
        contains(32),
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('the first tap locks every answer button', (tester) async {
    final container = await _pumpGame(
      tester,
      bank: _bank(1),
      settings: _settings(1),
      random: Random(3),
    );

    await tester.tap(find.text('Beta'));
    await tester.tap(find.text('Alpha'));
    await tester.pump();

    final session = container.read(gameControllerProvider)!;
    expect(session.answers, hasLength(1));
    expect(session.answers.single.correct, isFalse);
    expect(session.score, 0);
    _expectAnswerLocked(tester);
  });

  testWidgets('Next advances, and the last Next opens results', (tester) async {
    await _pumpGame(
      tester,
      bank: _bank(2),
      settings: _settings(2),
      random: Random(5),
    );

    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();
    expect(find.text('Prompt 0'), findsOneWidget);
    await tester.tap(find.text('Next question'));
    await tester.pumpAndSettle();

    expect(find.text('Prompt 1'), findsOneWidget);
    expect(find.text('Prompt 0'), findsNothing);
    expect(find.text('Next question'), findsNothing);
    expect(find.text('Question 2 of 2'), findsOneWidget);

    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();
    expect(find.text('See results'), findsOneWidget);
    await tester.tap(find.text('See results'));
    await tester.pumpAndSettle();

    expect(find.text('Results'), findsOneWidget);
    expect(find.text('Question'), findsNothing);
  });

  testWidgets('a streak of 3 shows the streak chip', (tester) async {
    await _pumpGame(
      tester,
      bank: _bank(3),
      settings: _settings(3),
      random: Random(6),
    );

    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('streak-chip')), findsNothing);
      await tester.tap(find.text('Next question'));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('streak-chip')), findsOneWidget);
    expect(find.text('3 in a row'), findsOneWidget);
  });

  testWidgets('reduced motion fades the feedback instead of sliding it', (
    tester,
  ) async {
    await _pumpGame(
      tester,
      bank: _bank(1),
      settings: _settings(1),
      random: Random(7),
      accessibility: const FakeAccessibilityFeatures(disableAnimations: true),
    );

    await tester.tap(find.text('Beta'));
    await tester.pump();

    expect(find.byKey(const Key('feedback-fade')), findsOneWidget);
    expect(find.byKey(const Key('feedback-slide')), findsNothing);
    expect(find.byKey(const Key('wrong-fade')), findsOneWidget);
    expect(find.byKey(const Key('wrong-shake')), findsNothing);
    expect(find.byKey(const Key('correct-pop')), findsNothing);

    double fade() {
      return tester
          .widget<FadeTransition>(find.byKey(const Key('feedback-fade')))
          .opacity
          .value;
    }

    expect(fade(), lessThan(0.5));
    await tester.pump(const Duration(milliseconds: 75));
    final midway = fade();
    expect(midway, greaterThan(0.2));
    expect(midway, lessThan(1));
    await tester.pump(const Duration(milliseconds: 75));
    expect(fade(), closeTo(1, 0.05));
    expect(find.byKey(const Key('correct-fade')), findsOneWidget);
  });

  testWidgets('large text keeps Next on screen and shortens the counter', (
    tester,
  ) async {
    await _pumpGame(
      tester,
      bank: _bank(2, reference: 'Reference ${'word ' * 80}'),
      settings: _settings(2),
      random: Random(8),
      textScale: 2,
      surface: const Size(320, 640),
    );

    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.text('Question 1 of 2'), findsNothing);

    final first = tester.getRect(find.byKey(const ValueKey('answer-0')));
    final second = tester.getRect(find.byKey(const ValueKey('answer-1')));
    expect(second.top, greaterThanOrEqualTo(first.bottom - 1));
    expect(first.height, greaterThanOrEqualTo(48));
    expect(second.height, greaterThanOrEqualTo(48));

    await tester.ensureVisible(find.text('Alpha'));
    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final sheet = tester.getRect(find.byKey(const Key('feedback-sheet')));
    expect(sheet.height, lessThanOrEqualTo(640 * 0.6 + 1));
    final next = tester.getRect(
      find.widgetWithText(FilledButton, 'Next question'),
    );
    expect(next.top, greaterThanOrEqualTo(0));
    expect(next.bottom, lessThanOrEqualTo(640));
    final option = tester.getRect(find.text('Alpha'));
    final tag = tester.getRect(find.text('Correct'));
    expect(tag.top, greaterThanOrEqualTo(option.bottom - 1));
  });

  testWidgets('cancel keeps the game and confirm goes home', (tester) async {
    final container = await _pumpGame(
      tester,
      bank: _bank(2),
      settings: _settings(2),
      random: Random(9),
    );

    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(handled, isTrue);
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.text('Keep playing'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Question'), findsOneWidget);
    expect(container.read(gameControllerProvider), isNotNull);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quit'));
    await tester.pumpAndSettle();

    expect(find.text('Scripture Trivia'), findsOneWidget);
    expect(find.text('Question'), findsNothing);
    expect(container.read(gameControllerProvider), isNull);
  });

  testWidgets('the iOS back swipe opens the quit dialog', (tester) async {
    final container = await _pumpGame(
      tester,
      bank: _bank(1),
      settings: _settings(1),
      random: Random(10),
      platform: TargetPlatform.iOS,
    );

    final edge = tester.getRect(find.byKey(const Key('ios-back-swipe')));
    await tester.flingFrom(
      edge.centerLeft + const Offset(6, 0),
      const Offset(220, 0),
      1500,
    );
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(container.read(gameControllerProvider), isNotNull);

    await tester.tap(find.text('Keep playing'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoAlertDialog), findsNothing);
    expect(find.text('Question'), findsOneWidget);
    expect(container.read(gameControllerProvider), isNotNull);
  });

  testWidgets('a finished session with the same settings deals a new game', (
    tester,
  ) async {
    const settings = LastGameSettings(
      volumes: [ScriptureVolume.bom],
      questionCount: 4,
    );
    final bank = _bank(6);
    final container = await _pumpGame(
      tester,
      bank: bank,
      settings: settings,
      random: Random(11),
      open: false,
    );
    final notifier = container.read(gameControllerProvider.notifier);
    notifier.start(
      bank: bank,
      volumes: settings.volumes,
      requestedCount: settings.questionCount,
    );
    final finished = container.read(gameControllerProvider)!;
    for (final question in finished.questions) {
      notifier.answer(question.answerIndex);
    }
    expect(container.read(gameControllerProvider)!.isComplete, isTrue);

    container.read(appRouterProvider).go(AppRoutes.game, extra: settings);
    await tester.pump();
    await tester.pump();

    final fresh = container.read(gameControllerProvider)!;
    expect(fresh.isComplete, isFalse);
    expect(fresh.answers, isEmpty);
    expect(fresh.score, 0);
    expect(fresh.currentIndex, 0);
    expect(fresh.requestedCount, settings.questionCount);
    expect(fresh.volumes, settings.volumes);
  });

  testWidgets('an in-progress game with the same settings is kept', (
    tester,
  ) async {
    const settings = LastGameSettings(
      volumes: [ScriptureVolume.bom],
      questionCount: 4,
    );
    final bank = _bank(6);
    final container = await _pumpGame(
      tester,
      bank: bank,
      settings: settings,
      random: Random(12),
      open: false,
    );
    final notifier = container.read(gameControllerProvider.notifier);
    notifier.start(
      bank: bank,
      volumes: settings.volumes,
      requestedCount: settings.questionCount,
    );
    final before = container.read(gameControllerProvider)!;
    notifier.answer(before.questions.first.answerIndex);
    final dealt = container.read(gameControllerProvider)!;
    expect(dealt.isComplete, isFalse);

    container.read(appRouterProvider).go(AppRoutes.game, extra: settings);
    await tester.pump();
    await tester.pump();

    final kept = container.read(gameControllerProvider)!;
    expect(
      kept.questions.map((question) => question.id).toList(),
      dealt.questions.map((question) => question.id).toList(),
    );
    expect(kept.answers, hasLength(1));
    expect(kept.score, dealt.score);
    expect(kept.currentIndex, dealt.currentIndex);
  });

  testWidgets('each answer is announced once', (tester) async {
    final announcements = await _captureAnnouncements(tester);
    await _pumpGame(
      tester,
      bank: _bank(2),
      settings: _settings(2),
      random: Random(13),
    );

    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();
    expect(announcements, ['Correct']);

    await tester.tap(find.text('Next question'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beta'));
    await tester.pumpAndSettle();

    expect(announcements, ['Correct', 'Not quite. The answer is Alpha.']);
  });

  testWidgets('a long explanation wraps and Next stays on screen', (
    tester,
  ) async {
    const explanation =
        'Nephi left Jerusalem with his family, obtained the brass plates, built a ship and crossed the sea to the promised land because the Lord commanded him to go now.';
    expect(explanation.length, 160);
    await _pumpGame(
      tester,
      bank: _bank(1, explanation: explanation),
      settings: _settings(1),
      random: Random(14),
      textScale: 2,
      surface: const Size(320, 640),
    );

    await tester.ensureVisible(find.text('Alpha'));
    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();

    final explanationText = tester.widget<Text>(
      find.byKey(const Key('explanation')),
    );
    expect(explanationText.data, explanation);
    expect(explanationText.maxLines, isNull);
    expect(explanationText.overflow, isNot(TextOverflow.ellipsis));
    expect(tester.takeException(), isNull);

    final nextBefore = tester.getRect(
      find.widgetWithText(FilledButton, 'See results'),
    );
    expect(nextBefore.top, greaterThanOrEqualTo(0));
    expect(nextBefore.bottom, lessThanOrEqualTo(640));

    final sheetScroll = find.descendant(
      of: find.byKey(const Key('feedback-sheet')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text(explanation),
      120,
      scrollable: sheetScroll,
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final textRect = tester.getRect(find.text(explanation));
    final next = tester.getRect(
      find.widgetWithText(FilledButton, 'See results'),
    );
    expect(next, nextBefore);
    expect(textRect.top, lessThan(next.top));
    expect(textRect.bottom, greaterThan(0));
    final visibleBottom = textRect.bottom < next.top
        ? textRect.bottom
        : next.top;
    expect(visibleBottom, greaterThan(textRect.top));
  });

  testWidgets('the question screen meets tap and contrast guidelines', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      for (final brightness in Brightness.values) {
        await _pumpGame(
          tester,
          bank: _bank(1),
          settings: _settings(1),
          random: Random(15),
          brightness: brightness,
        );
        await _expectGuidelines(tester);

        await tester.ensureVisible(find.text('Alpha'));
        await tester.tap(find.text('Alpha'));
        await tester.pumpAndSettle();
        await _expectGuidelines(tester);

        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Quit'));
        await tester.pumpAndSettle();
      }
    } finally {
      semantics.dispose();
    }
  });
}

Future<void> _expectGuidelines(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
}
