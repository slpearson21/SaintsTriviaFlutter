import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saints_trivia_flutter/app.dart';
import 'package:saints_trivia_flutter/data/questions/question_bank_provider.dart';
import 'package:saints_trivia_flutter/data/questions/questions.dart';
import 'package:saints_trivia_flutter/game/game_providers.dart';
import 'package:saints_trivia_flutter/progress/home_snapshot.dart';
import 'package:saints_trivia_flutter/report/question_report.dart';
import 'package:saints_trivia_flutter/report/report_config.dart';
import 'package:saints_trivia_flutter/report/report_sheet.dart';
import 'package:saints_trivia_flutter/report/reported_questions_provider.dart';
import 'package:saints_trivia_flutter/routing/app_router.dart';
import 'package:saints_trivia_flutter/routing/routes.dart';
import 'package:saints_trivia_flutter/services/open_link.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the flag is hidden until an answer, then Next still works', (
    tester,
  ) async {
    await _pumpGame(tester, count: 2);
    expect(find.byTooltip(reportFlagTooltip), findsNothing);
    expect(find.text('Next question'), findsNothing);

    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();

    expect(find.byTooltip(reportFlagTooltip), findsOneWidget);
    expect(find.text('Next question'), findsOneWidget);
    final flag = tester.getSize(find.byTooltip(reportFlagTooltip));
    expect(flag.width, greaterThanOrEqualTo(48));
    expect(flag.height, greaterThanOrEqualTo(48));

    await tester.tap(find.text('Next question'));
    await tester.pumpAndSettle();
    expect(find.byTooltip(reportFlagTooltip), findsNothing);
    expect(find.text('Prompt 1'), findsOneWidget);
  });

  testWidgets('the sheet, cancel, and a restored draft', (tester) async {
    await _pumpGame(tester);
    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(reportFlagTooltip));
    await tester.pumpAndSettle();

    expect(find.text(reportSheetTitle), findsOneWidget);
    expect(find.text('What’s wrong?'), findsOneWidget);
    expect(find.text('Wrong answer'), findsOneWidget);
    expect(find.text('Wrong reference'), findsOneWidget);
    expect(find.text('Typo or wording'), findsOneWidget);
    expect(find.text('Other'), findsOneWidget);
    expect(find.text('Note (optional)'), findsOneWidget);
    expect(find.text(reportExpectation), findsOneWidget);
    expect(find.text('0/280'), findsOneWidget);
    final continueButton = tester.widget<FilledButton>(
      find.byKey(const Key('report-continue')),
    );
    expect(continueButton.onPressed, isNull);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('report-sheet')), findsNothing);
    expect(find.text('Reported'), findsNothing);

    await tester.tap(find.byTooltip(reportFlagTooltip));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Typo or wording'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('report-continue'))).onPressed,
      isNotNull,
    );
    await tester.enterText(find.byKey(const Key('report-note')), 'Fix the wording');
    await tester.pump();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip(reportFlagTooltip));
    await tester.pumpAndSettle();
    expect(find.text('Fix the wording'), findsOneWidget);
    final note = tester.widget<TextField>(find.byKey(const Key('report-note')));
    expect(note.controller?.text, 'Fix the wording');
  });

  testWidgets('a successful launch marks the question reported', (tester) async {
    final opened = <({Uri uri, LaunchMode mode})>[];
    final messages = await _announcements(tester);
    await _pumpGame(
      tester,
      count: 2,
      canOpen: (_) async => true,
      open: (uri, {LaunchMode mode = LaunchMode.platformDefault}) async {
        opened.add((uri: uri, mode: mode));
        return true;
      },
    );
    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(reportFlagTooltip));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wrong reference'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('report-continue')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('report-sheet')), findsNothing);
    expect(find.text('Reported'), findsOneWidget);
    expect(find.text(reportThanksLine), findsOneWidget);
    expect(find.text('Next question'), findsOneWidget);
    expect(opened, hasLength(1));
    expect(opened.single.mode, LaunchMode.externalApplication);
    expect(opened.single.uri.toString(), isNot(contains('+')));
    expect(opened.single.uri.toString(), contains('wrong-reference'));
    final body = Uri.decodeComponent(
      opened.single.uri.query.split('&').skip(1).join('&').replaceFirst('body=', ''),
    );
    expect(body, contains('Correct answer (app): Alpha'));
    expect(body, contains("Player's answer: Alpha"));
    expect(body, contains('Source: game'));

    await tester.pump(const Duration(seconds: 2));
    expect(
      messages.where((message) => message == reportAnnouncement),
      [reportAnnouncement],
    );

    await tester.tap(find.text('Reported'));
    await tester.pumpAndSettle();
    expect(find.text('Wrong reference'), findsOneWidget);
    expect(find.byKey(const Key('report-sheet')), findsOneWidget);
  });

  testWidgets('a failed launch copies the report and shows the dialog', (
    tester,
  ) async {
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map<Object?, Object?>;
          clipboard = args['text'] as String?;
        }
        if (call.method == 'Clipboard.getData') {
          return <String, dynamic>{'text': clipboard};
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
      count: 2,
      canOpen: (_) async => false,
      open: (uri, {LaunchMode mode = LaunchMode.platformDefault}) async => true,
    );
    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(reportFlagTooltip));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Typo or wording'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('report-note')), 'Needs a look');
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('report-continue'))).onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const Key('report-continue')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('report-sheet')), findsNothing);
    expect(find.text(reportNoMailTitle), findsWidgets);
    expect(find.text('Reported'), findsOneWidget);
    expect(find.byKey(const Key('report-no-mail-dialog')), findsOneWidget);
    expect(find.text(reportNoMailTitle), findsOneWidget);
    expect(find.text(kReportEmail), findsOneWidget);
    expect(clipboard, contains('To: $kReportEmail'));
    expect(clipboard, contains('Subject: [Trivia report]'));
    expect(clipboard, contains('typo-or-wording'));
    expect(clipboard, contains('Needs a look'));
    expect(clipboard, isNot(contains('option index')));

    await tester.tap(find.byKey(const Key('report-copy-address')));
    await tester.pump();
    expect(clipboard, kReportEmail);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Reported'), findsOneWidget);
    expect(find.text('Next question'), findsOneWidget);
  });

  testWidgets('review flags sit outside the card and keep an in-game report', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final container = await _pumpGame(
        tester,
        count: 1,
        canOpen: (_) async => true,
        open: (uri, {LaunchMode mode = LaunchMode.platformDefault}) async => true,
      );
      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(reportFlagTooltip));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Wrong answer'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('report-continue')));
      await tester.pumpAndSettle();

      container.read(appRouterProvider).go(AppRoutes.review);
      await tester.pumpAndSettle();

      expect(find.text('Reported'), findsOneWidget);
      final card = tester.getSemantics(
        find.byKey(const Key('review-answer-bom-0001')),
      );
      expect(card.label, isNot(contains('Report a problem')));
      expect(card.label, isNot(contains('Reported')));
      final flag = tester.getSemantics(find.byKey(const Key('report-flag-bom-0001')));
      expect(flag.label, contains('Reported'));
      expect(flag.flagsCollection.isButton, isTrue);
    } finally {
      semantics.dispose();
    }
  });

  test('a new deal clears reported questions', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(reportedQuestionIdsProvider.notifier).markReported('bom-0001');
    container.read(reportedQuestionIdsProvider.notifier).saveDraft(
      'bom-0001',
      reason: ReportReason.other,
      note: 'hi',
    );
    final bank = QuestionBank(
      schemaVersion: 1,
      questions: [
        TriviaQuestion(
          id: 'bom-0001',
          volume: ScriptureVolume.bom,
          reference: '1 Nephi 1:1',
          prompt: 'Prompt',
          options: const ['Alpha', 'Beta', 'Gamma', 'Delta'],
          answerIndex: 0,
          explanation: 'Because.',
          reviewStatus: ReviewStatus.draft,
        ),
      ],
    );
    container.read(gameControllerProvider.notifier).start(
      bank: bank,
      volumes: const [ScriptureVolume.bom],
      requestedCount: 1,
    );
    final memory = container.read(reportedQuestionIdsProvider);
    expect(memory.reportedIds, isEmpty);
    expect(memory.drafts, isEmpty);
  });
}

QuestionBank _bank({int count = 1}) {
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

Future<List<String>> _announcements(WidgetTester tester) async {
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

Future<ProviderContainer> _pumpGame(
  WidgetTester tester, {
  int count = 1,
  CanOpenLink? canOpen,
  OpenLink? open,
}) async {
  await tester.binding.setSurfaceSize(const Size(400, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final container = ProviderContainer(
    overrides: [
      questionBankLoaderProvider.overrideWith((ref) => () async => _bank(count: count)),
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
  container.read(appRouterProvider).go(
    AppRoutes.game,
    extra: LastGameSettings(
      volumes: const [ScriptureVolume.bom],
      questionCount: count,
    ),
  );
  await tester.pump();
  await tester.pump();
  return container;
}
