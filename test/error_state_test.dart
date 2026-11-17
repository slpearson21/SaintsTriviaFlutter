import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saints_trivia_flutter/app.dart';
import 'package:saints_trivia_flutter/data/questions/question_bank_provider.dart';
import 'package:saints_trivia_flutter/data/questions/questions.dart';
import 'package:saints_trivia_flutter/progress/home_snapshot.dart';
import 'package:saints_trivia_flutter/routing/app_router.dart';
import 'package:saints_trivia_flutter/routing/routes.dart';

const _contentTitle = 'Something went wrong';
const _contentBody =
    "We couldn't load the questions on this device. "
    'Please try again. If this keeps happening, reinstall the app.';
const _noQuestionsTitle = "Couldn't start this game";
const _noQuestionsBody =
    "There aren't any questions for this selection yet. "
    'Choose different scriptures and try again.';

QuestionBank _bank({int ot = 4, int pgp = 0}) {
  return QuestionBank(
    schemaVersion: 1,
    questions: [
      for (var i = 0; i < ot; i++)
        TriviaQuestion(
          id: 'ot-${(i + 1).toString().padLeft(4, '0')}',
          volume: ScriptureVolume.ot,
          reference: 'Genesis 1:${i + 1}',
          prompt: 'Old Testament prompt $i',
          options: const ['Amos', 'Nephi', 'Alma', 'Moroni'],
          answerIndex: 0,
          explanation: 'Because.',
          reviewStatus: ReviewStatus.draft,
        ),
      for (var i = 0; i < pgp; i++)
        TriviaQuestion(
          id: 'pgp-${(i + 1).toString().padLeft(4, '0')}',
          volume: ScriptureVolume.pgp,
          reference: 'Moses 1:${i + 1}',
          prompt: 'Pearl prompt $i',
          options: const ['Amos', 'Nephi', 'Alma', 'Moroni'],
          answerIndex: 0,
          explanation: 'Because.',
          reviewStatus: ReviewStatus.draft,
        ),
    ],
  );
}

const _gameSettings = LastGameSettings(
  volumes: [ScriptureVolume.ot],
  questionCount: 4,
);

const _emptySettings = LastGameSettings(
  volumes: [ScriptureVolume.pgp],
  questionCount: 5,
);

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required QuestionBankLoad load,
  Brightness? brightness,
  double textScale = 1,
  Size surface = const Size(400, 800),
}) async {
  await tester.binding.setSurfaceSize(surface);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  if (brightness != null) {
    tester.platformDispatcher.platformBrightnessTestValue = brightness;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  }
  final container = ProviderContainer(
    overrides: [questionBankLoaderProvider.overrideWith((ref) => load)],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const SaintsTriviaApp(),
    ),
  );
  await tester.pump();
  return container;
}

Future<void> _failBank(ProviderContainer container) async {
  try {
    await container.read(questionBankProvider.future);
  } on Object {
    // The failed future is the state these screens have to show.
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

void _expectHeader(WidgetTester tester, String title) {
  expect(
    tester.getSemantics(find.byKey(const Key('error-state-title'))),
    matchesSemantics(
      label: title,
      isHeader: true,
      textDirection: TextDirection.ltr,
    ),
  );
}

void _expectIconDecorative(WidgetTester tester) {
  expect(
    find.ancestor(
      of: find.byKey(const Key('error-state-icon')),
      matching: find.byType(ExcludeSemantics),
    ),
    findsOneWidget,
  );
}

Future<void> _expectGuidelines(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
}

void main() {
  testWidgets('setup shows E1 and Try again recovers', (tester) async {
    var fail = true;
    final container = await _pump(
      tester,
      load: () async {
        if (fail) throw Exception('unreadable');
        return _bank();
      },
    );
    await _failBank(container);

    container.read(appRouterProvider).go(AppRoutes.setup);
    await tester.pumpAndSettle();

    expect(
      GoRouterState.of(tester.element(find.text(_contentTitle))).uri.path,
      AppRoutes.setup,
    );
    expect(find.text(_contentTitle), findsOneWidget);
    expect(find.text(_contentBody), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.byKey(const Key('setup-start')), findsNothing);

    fail = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text(_contentTitle), findsNothing);
    expect(find.text('Select all'), findsOneWidget);
    expect(find.text('4 questions'), findsWidgets);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('setup-start')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('preparing shows E1 and Try again deals the game', (
    tester,
  ) async {
    var fail = true;
    final container = await _pump(
      tester,
      load: () async {
        if (fail) throw Exception('unreadable');
        return _bank();
      },
    );
    await _failBank(container);

    container.read(appRouterProvider).go(AppRoutes.game, extra: _gameSettings);
    await tester.pumpAndSettle();

    expect(
      GoRouterState.of(tester.element(find.text(_contentTitle))).uri.path,
      AppRoutes.game,
    );
    expect(find.text(_contentTitle), findsOneWidget);
    expect(find.text(_contentBody), findsOneWidget);
    expect(find.textContaining('Old Testament prompt'), findsNothing);
    expect(find.byType(Card), findsNothing);

    fail = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text(_contentTitle), findsNothing);
    expect(find.text('Question'), findsOneWidget);
    expect(find.textContaining('Old Testament prompt'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty deal shows E2 and Back to setup keeps the selection', (
    tester,
  ) async {
    final container = await _pump(tester, load: () async => _bank());
    await container.read(questionBankProvider.future);

    container.read(appRouterProvider).go(AppRoutes.game, extra: _emptySettings);
    await tester.pumpAndSettle();

    expect(find.text(_noQuestionsTitle), findsOneWidget);
    expect(find.text(_noQuestionsBody), findsOneWidget);
    expect(find.text('Back to setup'), findsOneWidget);
    expect(find.textContaining('Old Testament prompt'), findsNothing);
    expect(find.byType(Card), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Back to setup'));
    await tester.pumpAndSettle();

    expect(
      GoRouterState.of(tester.element(find.text('New game'))).uri.path,
      AppRoutes.setup,
    );
    expect(find.text('1 of 5 selected'), findsOneWidget);
    expect(find.text(_noQuestionsTitle), findsNothing);
    expect(
      tester
          .widget<Checkbox>(
            find.descendant(
              of: find.byKey(const Key('setup-check-pgp')),
              matching: find.byType(Checkbox),
            ),
          )
          .value,
      isTrue,
    );
    expect(
      tester
          .widget<Checkbox>(
            find.descendant(
              of: find.byKey(const Key('setup-check-ot')),
              matching: find.byType(Checkbox),
            ),
          )
          .value,
      isFalse,
    );
    expect(tester.widget<Text>(find.byKey(const Key('setup-count'))).data, '5');
  });

  testWidgets('error states hold together at text scale 2 on a small phone', (
    tester,
  ) async {
    const surface = Size(320, 640);
    final container = await _pump(
      tester,
      load: () async => throw Exception('unreadable'),
      textScale: 2,
      surface: surface,
    );
    await _failBank(container);
    container.read(appRouterProvider).go(AppRoutes.setup);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final tryAgain = tester.getRect(find.text('Try again'));
    expect(tryAgain.top, greaterThanOrEqualTo(0));
    expect(tryAgain.bottom, lessThanOrEqualTo(surface.height));

    final dealt = await _pump(
      tester,
      load: () async => _bank(),
      textScale: 2,
      surface: surface,
    );
    await dealt.read(questionBankProvider.future);
    dealt.read(appRouterProvider).go(AppRoutes.game, extra: _emptySettings);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final back = tester.getRect(find.text('Back to setup'));
    expect(back.top, greaterThanOrEqualTo(0));
    expect(back.bottom, lessThanOrEqualTo(surface.height));
  });

  testWidgets('error states meet tap and contrast guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    try {
      for (final brightness in Brightness.values) {
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        await tester.pumpWidget(const SizedBox.shrink());
        final failed = await _pump(
          tester,
          load: () async => throw Exception('unreadable'),
          brightness: brightness,
        );
        await _failBank(failed);
        failed.read(appRouterProvider).go(AppRoutes.setup);
        await tester.pumpAndSettle();
        await _expectGuidelines(tester);

        await tester.pumpWidget(const SizedBox.shrink());
        final empty = await _pump(
          tester,
          load: () async => _bank(),
          brightness: brightness,
        );
        await empty.read(questionBankProvider.future);
        empty.read(appRouterProvider).go(AppRoutes.game, extra: _emptySettings);
        await tester.pumpAndSettle();
        await _expectGuidelines(tester);
      }
    } finally {
      handle.dispose();
    }
  });

  testWidgets('each error state is announced once', (tester) async {
    final handle = tester.ensureSemantics();
    try {
      final messages = await _captureAnnouncements(tester);
      final failed = await _pump(
        tester,
        load: () async => throw Exception('unreadable'),
      );
      await _failBank(failed);
      messages.clear();
      failed.read(appRouterProvider).go(AppRoutes.setup);
      await tester.pumpAndSettle();
      await tester.pump();

      expect(messages, ['$_contentTitle. $_contentBody']);
      _expectHeader(tester, _contentTitle);
      _expectIconDecorative(tester);
      expect(
        tester.getSemantics(find.byKey(const Key('error-state-body'))),
        matchesSemantics(label: _contentBody, textDirection: TextDirection.ltr),
      );

      messages.clear();
      await tester.pumpWidget(const SizedBox.shrink());
      final empty = await _pump(tester, load: () async => _bank());
      await empty.read(questionBankProvider.future);
      messages.clear();
      empty.read(appRouterProvider).go(AppRoutes.game, extra: _emptySettings);
      await tester.pumpAndSettle();
      await tester.pump();

      expect(messages, ['$_noQuestionsTitle. $_noQuestionsBody']);
      _expectHeader(tester, _noQuestionsTitle);
      _expectIconDecorative(tester);
    } finally {
      handle.dispose();
    }
  });
}
