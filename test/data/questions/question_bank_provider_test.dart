import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saints_trivia_flutter/app.dart';
import 'package:saints_trivia_flutter/data/questions/question_bank_provider.dart';
import 'package:saints_trivia_flutter/data/questions/questions.dart';
import 'package:saints_trivia_flutter/main.dart';
import 'package:saints_trivia_flutter/routing/app_router.dart';
import 'package:saints_trivia_flutter/routing/routes.dart';

QuestionBank _bank() {
  return QuestionBank(
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
}

void main() {
  test('the splash timeout is 5 seconds', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      container.read(questionBankLoadTimeoutProvider),
      questionBankLoadTimeout,
    );
    expect(questionBankLoadTimeout, const Duration(seconds: 5));
  });

  test('the bank future is shared by later reads', () async {
    var calls = 0;
    final container = ProviderContainer(
      overrides: [
        questionBankLoaderProvider.overrideWith((ref) {
          return () async {
            calls += 1;
            return _bank();
          };
        }),
      ],
    );
    addTearDown(container.dispose);

    final first = container.read(questionBankProvider.future);
    final second = container.read(questionBankProvider.future);
    expect(await first, await second);
    expect(calls, 1);

    var removed = false;
    await removeSplashAfterBundledQuestionBank(
      container: container,
      removeSplash: () => removed = true,
    );
    expect(calls, 1);
    expect(removed, isTrue);
  });

  testWidgets('a hang past the timeout drops the splash and shows the error', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        questionBankLoaderProvider.overrideWith((ref) {
          return () => Completer<QuestionBank>().future;
        }),
        questionBankLoadTimeoutProvider.overrideWith(
          (ref) => const Duration(milliseconds: 20),
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

    var removed = false;
    await tester.runAsync(() {
      return removeSplashAfterBundledQuestionBank(
        container: container,
        removeSplash: () => removed = true,
      );
    });
    await tester.pumpAndSettle();

    expect(container.read(questionBankProvider).hasError, isTrue);
    expect(container.read(questionBankProvider).error, isA<TimeoutException>());
    expect(removed, isTrue);
    expect(find.text(QuestionBankException.userMessage), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('home does not start the question bank load', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SaintsTriviaApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Scripture Trivia'), findsOneWidget);
    expect(container.read(questionBankProvider.exists), isFalse);
  });

  testWidgets('a failed bank load opens the content-load error', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        questionBankLoaderProvider.overrideWith((ref) {
          return () async => throw Exception('unreadable');
        }),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SaintsTriviaApp(),
      ),
    );

    var removed = false;
    await removeSplashAfterBundledQuestionBank(
      container: container,
      removeSplash: () => removed = true,
    );
    await tester.pumpAndSettle();

    expect(removed, isTrue);
    expect(find.text(QuestionBankException.userMessage), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(
      tester.getSize(find.widgetWithText(FilledButton, 'Try again')).height,
      greaterThanOrEqualTo(52),
    );
  });

  testWidgets('try again leaves the error screen once the bank loads', (
    tester,
  ) async {
    var calls = 0;
    final container = ProviderContainer(
      overrides: [
        questionBankLoaderProvider.overrideWith((ref) {
          return () async {
            calls += 1;
            if (calls == 1) throw Exception('unreadable');
            return _bank();
          };
        }),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SaintsTriviaApp(),
      ),
    );
    await removeSplashAfterBundledQuestionBank(
      container: container,
      removeSplash: () {},
    );
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Scripture Trivia'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
    expect(calls, 2);
  });

  testWidgets('a failed retry stays on the error screen', (tester) async {
    final container = ProviderContainer(
      overrides: [
        questionBankLoaderProvider.overrideWith((ref) {
          return () async => throw Exception('still unreadable');
        }),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SaintsTriviaApp(),
      ),
    );
    await removeSplashAfterBundledQuestionBank(
      container: container,
      removeSplash: () {},
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text(QuestionBankException.userMessage), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the error screen holds together at text scale 2', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final container = ProviderContainer(
      overrides: [
        questionBankLoaderProvider.overrideWith((ref) {
          return () async => throw Exception('unreadable');
        }),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SaintsTriviaApp(),
      ),
    );
    container.read(appRouterProvider).go(AppRoutes.contentError);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Try again'), findsOneWidget);
  });
}
