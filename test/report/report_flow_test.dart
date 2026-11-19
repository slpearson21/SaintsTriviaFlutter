import 'dart:math';

import 'dart:async';
import 'dart:ui' show CheckedState;

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
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
    final semantics = tester.ensureSemantics();
    expect(
      tester
          .getSemantics(find.byTooltip(reportFlagTooltip))
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isTrue,
    );
    semantics.dispose();
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
    final semantics = tester.ensureSemantics();
    expect(
      tester.getSemantics(find.byKey(const Key('report-continue'))),
      matchesSemantics(
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
        hint: reportChooseReasonHint,
        label: reportContinueLabel,
        hasTapAction: false,
        textDirection: TextDirection.ltr,
      ),
    );
    semantics.dispose();
    final continueButton = tester.widget<FilledButton>(
      find.byKey(const Key('report-continue')),
    );
    expect(continueButton.onPressed, isNull);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('report-sheet')), findsNothing);
    expect(find.text('Reported'), findsNothing);
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byTooltip(reportFlagTooltip),
              matching: find.byType(IconButton),
            ),
          )
          .focusNode
          ?.hasFocus,
      isTrue,
    );

    await tester.tap(find.byTooltip(reportFlagTooltip));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Typo or wording'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('report-continue')))
          .onPressed,
      isNotNull,
    );
    await tester.enterText(
      find.byKey(const Key('report-note')),
      'Fix the wording',
    );
    await tester.pump();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip(reportFlagTooltip));
    await tester.pumpAndSettle();
    expect(find.text('Fix the wording'), findsOneWidget);
    final note = tester.widget<TextField>(find.byKey(const Key('report-note')));
    expect(note.controller?.text, 'Fix the wording');
  });

  testWidgets('a successful launch marks the question reported', (
    tester,
  ) async {
    final opened = <({Uri uri, LaunchMode mode})>[];
    final messages = await _announcements(tester);
    // Local, so the sheet's toUtc() is what prints the Z timestamp.
    final reportedAt = DateTime.utc(2026, 11, 18, 15, 46).toLocal();
    expect(reportedAt.isUtc, isFalse);
    await _pumpGame(
      tester,
      count: 2,
      reportedAt: reportedAt,
      canOpen: (_) async => true,
      open: (uri, {LaunchMode mode = LaunchMode.platformDefault}) async {
        opened.add((uri: uri, mode: mode));
        return true;
      },
    );
    await tester.tap(find.text('Beta'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(reportFlagTooltip));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wrong reference'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('report-continue')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('report-sheet')), findsNothing);
    expect(find.text('Reported'), findsOneWidget);
    await tester.pump();
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Reported'))
          .focusNode
          ?.hasFocus,
      isTrue,
    );
    expect(find.text(reportThanksLine), findsOneWidget);
    expect(find.text('Next question'), findsOneWidget);
    expect(opened, hasLength(1));
    expect(opened.single.mode, LaunchMode.externalApplication);
    expect(opened.single.uri.toString(), isNot(contains('+')));
    expect(opened.single.uri.toString(), contains('wrong-reference'));
    final body = Uri.decodeComponent(
      opened.single.uri.query
          .split('&')
          .skip(1)
          .join('&')
          .replaceFirst('body=', ''),
    );
    expect(body, contains('Correct answer (app): Alpha'));
    expect(body, contains("Player's answer: Beta"));
    expect(body.split('\r\n'), contains('Reported at: 2026-11-18T15:46:00Z'));
    expect(body, isNot(contains("Player's answer: Alpha")));
    expect(body, contains('Source: game'));

    await tester.pump(const Duration(seconds: 2));
    expect(messages.where((message) => message == reportAnnouncement), [
      reportAnnouncement,
    ]);

    await tester.tap(find.text('Reported'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('report-sheet')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('report-continue')))
          .onPressed,
      isNotNull,
    );
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
    await tester.enterText(
      find.byKey(const Key('report-note')),
      'Needs a look',
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('report-continue')))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const Key('report-continue')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('report-sheet')), findsNothing);
    expect(find.text(reportNoMailTitle), findsOneWidget);
    expect(find.text('Reported'), findsOneWidget);
    expect(find.byKey(const Key('report-no-mail-dialog')), findsOneWidget);
    final reportedNode = tester
        .widget<TextButton>(find.widgetWithText(TextButton, 'Reported'))
        .focusNode;
    expect(reportedNode?.hasFocus, isFalse);
    final primary = FocusManager.instance.primaryFocus;
    expect(primary, isNot(reportedNode));
    final dialogScope = FocusScope.of(
      tester.element(find.byKey(const Key('report-no-mail-dialog'))),
    );
    expect(
      primary == dialogScope || primary!.ancestors.contains(dialogScope),
      isTrue,
    );
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
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Reported'))
          .focusNode
          ?.hasFocus,
      isTrue,
    );
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
        open: (uri, {LaunchMode mode = LaunchMode.platformDefault}) async =>
            true,
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
      final flag = tester.getSemantics(
        find.byKey(const Key('report-flag-bom-0001')),
      );
      expect(flag.label, contains('Reported'));
      expect(flag.flagsCollection.isButton, isTrue);
      expect(flag.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('a semantics tap on Reported reopens the draft', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await _pumpGame(
        tester,
        canOpen: (_) async => true,
        open: (uri, {LaunchMode mode = LaunchMode.platformDefault}) async =>
            true,
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
      final reported = tester.getSemantics(find.text('Reported'));
      expect(
        reported.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );
      expect(
        reported,
        matchesSemantics(
          isButton: true,
          hasTapAction: true,
          label: 'Reported',
          hint: reportReportedHint,
          textDirection: TextDirection.ltr,
        ),
      );
      tester.semantics.tap(find.semantics.byLabel('Reported'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('report-sheet')), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('report-continue')))
            .onPressed,
        isNotNull,
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('iOS reason rows are an exclusive group with a tap action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await _pumpGame(tester);
      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(reportFlagTooltip));
      await tester.pumpAndSettle();
      for (final reason in ReportReason.values) {
        final node = tester.getSemantics(
          find.byKey(Key('report-reason-${reason.name}')),
        );
        expect(
          node.flagsCollection.isInMutuallyExclusiveGroup,
          isTrue,
          reason: reason.name,
        );
        expect(
          node.getSemanticsData().hasAction(SemanticsAction.tap),
          isTrue,
          reason: reason.name,
        );
        expect(
          node.flagsCollection.isChecked,
          isNot(CheckedState.isTrue),
          reason: reason.name,
        );
      }
      tester.semantics.tap(find.semantics.byLabel('Typo or wording'));
      await tester.pumpAndSettle();
      expect(
        tester
            .getSemantics(find.byKey(const Key('report-reason-typoOrWording')))
            .flagsCollection
            .isChecked,
        CheckedState.isTrue,
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('reduce motion removes the flag animation', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _pumpGame(tester);
    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();
    final switcher = tester.widget<AnimatedSwitcher>(
      find.descendant(
        of: find.byKey(const Key('report-flag-bom-0001')),
        matching: find.byType(AnimatedSwitcher),
      ),
    );
    expect(switcher.duration, Duration.zero);

    await tester.tap(find.byTooltip(reportFlagTooltip));
    await tester.pump();
    expect(find.text(reportSheetTitle), findsOneWidget);
  });

  testWidgets('the report sheet fits at large text', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pumpGame(tester);
    await tester.binding.setSurfaceSize(const Size(320, 640));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip(reportFlagTooltip));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(reportFlagTooltip));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text(reportSheetTitle), findsOneWidget);
    await tester.showKeyboard(find.byKey(const Key('report-note')));
    const keyboard = 280.0;
    tester.view.viewInsets = FakeViewPadding(
      bottom: keyboard * tester.view.devicePixelRatio,
    );
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // setSurfaceSize sizes the render view. tester.view.physicalSize stays
    // on the default 800×600 viewport, so it is not the surface under test.
    final surfaceHeight = tester.binding.renderViews.single.size.height;
    final keyboardTop = surfaceHeight - keyboard;
    expect(
      tester.getRect(find.byKey(const Key('report-continue'))).bottom,
      lessThanOrEqualTo(keyboardTop),
    );
    expect(
      tester.getRect(find.text('Cancel')).bottom,
      lessThanOrEqualTo(keyboardTop),
    );
  });

  testWidgets('a report from review records Source: review', (tester) async {
    final opened = <Uri>[];
    final container = await _pumpGame(
      tester,
      count: 1,
      canOpen: (_) async => true,
      open: (uri, {LaunchMode mode = LaunchMode.platformDefault}) async {
        opened.add(uri);
        return true;
      },
    );
    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();
    container.read(appRouterProvider).go(AppRoutes.review);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(reportFlagTooltip));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wrong reference'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('report-continue')));
    await tester.pumpAndSettle();
    expect(opened, hasLength(1));
    expect(opened.single.toString(), contains('Source%3A%20review'));
  });

  testWidgets(
    'a pause that resumes before the mail app returns still announces',
    (tester) async {
      final messages = await _announcements(tester);
      await _pumpGame(
        tester,
        canOpen: (_) async => true,
        open: (uri, {LaunchMode mode = LaunchMode.platformDefault}) async {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.hidden,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          return true;
        },
      );
      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(reportFlagTooltip));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Wrong answer'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('report-continue')));
      await tester.pumpAndSettle();
      expect(messages, isNot(contains(reportAnnouncement)));
      await tester.pump(const Duration(seconds: 2));
      expect(messages.where((message) => message == reportAnnouncement), [
        reportAnnouncement,
      ]);
    },
  );

  testWidgets('a pause then resume announces once', (tester) async {
    final messages = await _announcements(tester);
    await _pumpGame(
      tester,
      canOpen: (_) async => true,
      open: (uri, {LaunchMode mode = LaunchMode.platformDefault}) async {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        return true;
      },
    );
    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(reportFlagTooltip));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wrong answer'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('report-continue')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    expect(messages, isNot(contains(reportAnnouncement)));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(messages.where((message) => message == reportAnnouncement), [
      reportAnnouncement,
    ]);
    await tester.pump(const Duration(seconds: 2));
    expect(messages.where((message) => message == reportAnnouncement), [
      reportAnnouncement,
    ]);
  });

  testWidgets('a thrown launch and a refused launch show the dialog', (
    tester,
  ) async {
    _mockClipboard(tester);
    await _pumpGame(
      tester,
      canOpen: (_) async => true,
      open: (uri, {LaunchMode mode = LaunchMode.platformDefault}) async {
        throw StateError('launch failed');
      },
    );
    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(reportFlagTooltip));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Other'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('report-continue')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(CupertinoAlertDialog), findsNothing);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    await _pumpGame(
      tester,
      canOpen: (_) async => true,
      open: (uri, {LaunchMode mode = LaunchMode.platformDefault}) async =>
          false,
    );
    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(reportFlagTooltip));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Other'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('report-continue')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('the iOS no-mail dialog is a Cupertino alert', (tester) async {
    _mockClipboard(tester);
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await _pumpGame(
      tester,
      canOpen: (_) async => false,
      open: (uri, {LaunchMode mode = LaunchMode.platformDefault}) async =>
          false,
    );
    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(reportFlagTooltip));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoAlertDialog), findsNothing);
    await tester.tap(find.text('Wrong answer'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('report-continue')));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text(kReportEmail), findsOneWidget);
  });

  testWidgets('scrim, back, and a swipe dismiss the sheet without reporting', (
    tester,
  ) async {
    Future<void> openSheet() async {
      await tester.tap(find.byTooltip(reportFlagTooltip));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('report-sheet')), findsOneWidget);
    }

    await _pumpGame(tester);
    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();

    await openSheet();
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('report-sheet')), findsNothing);
    expect(find.text('Reported'), findsNothing);

    await openSheet();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('report-sheet')), findsNothing);

    await openSheet();
    final top = tester.getTopLeft(find.byKey(const Key('report-sheet')));
    await tester.dragFrom(top + const Offset(80, -16), const Offset(0, 500));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('report-sheet')), findsNothing);
    expect(find.text('Reported'), findsNothing);
  });

  testWidgets('a swipe during the launch still records the report', (
    tester,
  ) async {
    final release = Completer<bool>();
    await _pumpGame(
      tester,
      canOpen: (_) async => true,
      open: (uri, {LaunchMode mode = LaunchMode.platformDefault}) {
        return release.future;
      },
    );
    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(reportFlagTooltip));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Typo or wording'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('report-continue')));
    await tester.pump();
    await tester.drag(
      find.byKey(const Key('report-sheet')),
      const Offset(0, 600),
    );
    await tester.pumpAndSettle();
    expect(find.text('Reported'), findsNothing);
    release.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('Reported'), findsOneWidget);
    expect(find.text(reportThanksLine), findsOneWidget);
  });

  testWidgets('report surfaces meet tap and contrast guidelines', (
    tester,
  ) async {
    const guidelines = <AccessibilityGuideline>[
      androidTapTargetGuideline,
      iOSTapTargetGuideline,
      labeledTapTargetGuideline,
      textContrastGuideline,
    ];
    _mockClipboard(tester);
    final semantics = tester.ensureSemantics();
    try {
      final container = await _pumpGame(
        tester,
        count: 1,
        canOpen: (_) async => false,
        open: (uri, {LaunchMode mode = LaunchMode.platformDefault}) async =>
            false,
      );
      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();
      for (final guideline in guidelines) {
        await expectLater(tester, meetsGuideline(guideline));
      }
      await tester.tap(find.byTooltip(reportFlagTooltip));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Other'));
      await tester.pumpAndSettle();
      for (final guideline in guidelines) {
        await expectLater(tester, meetsGuideline(guideline));
      }
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(reportFlagTooltip));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Other'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('report-continue')));
      await tester.pumpAndSettle();
      for (final guideline in guidelines) {
        await expectLater(tester, meetsGuideline(guideline));
      }
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      container.read(appRouterProvider).go(AppRoutes.review);
      await tester.pumpAndSettle();
      for (final guideline in guidelines) {
        await expectLater(tester, meetsGuideline(guideline));
      }
    } finally {
      semantics.dispose();
    }
  });

  test('a new deal clears reported questions', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(reportedQuestionIdsProvider.notifier)
        .markReported('bom-0001');
    container
        .read(reportedQuestionIdsProvider.notifier)
        .saveDraft('bom-0001', reason: ReportReason.other, note: 'hi');
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
    container
        .read(gameControllerProvider.notifier)
        .start(
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

void _mockClipboard(WidgetTester tester) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (MethodCall call) async => null,
  );
  addTearDown(() {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });
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
  DateTime? reportedAt,
  CanOpenLink? canOpen,
  OpenLink? open,
}) async {
  await tester.binding.setSurfaceSize(const Size(400, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final container = ProviderContainer(
    overrides: [
      questionBankLoaderProvider.overrideWith(
        (ref) =>
            () async => _bank(count: count),
      ),
      gameRandomProvider.overrideWith((ref) => Random(1)),
      if (reportedAt != null)
        reportClockProvider.overrideWith(
          (ref) =>
              () => reportedAt,
        ),
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
        extra: LastGameSettings(
          volumes: const [ScriptureVolume.bom],
          questionCount: count,
        ),
      );
  // Two frames leave a Cupertino page slide moving, past the hit-test root.
  await tester.pumpAndSettle();
  return container;
}
