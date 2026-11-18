import 'dart:async';
import 'dart:math';

import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saints_trivia_flutter/app.dart';
import 'package:saints_trivia_flutter/data/questions/question_bank_provider.dart';
import 'package:saints_trivia_flutter/data/questions/questions.dart';
import 'package:saints_trivia_flutter/game/game_engine.dart';
import 'package:saints_trivia_flutter/game/game_providers.dart';
import 'package:saints_trivia_flutter/progress/home_snapshot.dart';
import 'package:saints_trivia_flutter/routing/app_router.dart';
import 'package:saints_trivia_flutter/routing/routes.dart';
import 'package:saints_trivia_flutter/scripture/scripture_link.dart';
import 'package:saints_trivia_flutter/scripture/scripture_reference_chip.dart';
import 'package:saints_trivia_flutter/services/open_link.dart';
import 'package:saints_trivia_flutter/theme/st_theme.dart';
import 'package:url_launcher/url_launcher.dart';

const _guidelines = <AccessibilityGuideline>[
  androidTapTargetGuideline,
  iOSTapTargetGuideline,
  labeledTapTargetGuideline,
  textContrastGuideline,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'the feedback sheet opens Gospel Library and keeps clear of Next',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final opened = <({Uri uri, LaunchMode mode})>[];
      try {
        await _pumpGame(
          tester,
          reference: 'Acts 3:2, 6-7',
          count: 2,
          open: (uri, {LaunchMode mode = LaunchMode.platformDefault}) async {
            opened.add((uri: uri, mode: mode));
            return true;
          },
        );
        await tester.tap(find.text('Alpha'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('reference-chip')), findsOneWidget);
        expect(find.byIcon(Icons.open_in_new), findsOneWidget);
        expect(
          tester.getSemantics(find.byKey(const Key('reference-chip'))),
          matchesSemantics(
            label: 'Open Acts 3:2, 6-7 in Gospel Library',
            isLink: true,
            isButton: false,
            hasTapAction: true,
            textDirection: TextDirection.ltr,
          ),
        );

        final chip = tester.getRect(find.byKey(const Key('reference-chip')));
        expect(chip.width, greaterThanOrEqualTo(StSpace.minTap));
        expect(chip.height, greaterThanOrEqualTo(StSpace.minTap));
        final next = tester.getRect(
          find.widgetWithText(FilledButton, 'Next question'),
        );
        expect(chip.bottom, lessThanOrEqualTo(next.top));
        for (final guideline in _guidelines) {
          await expectLater(tester, meetsGuideline(guideline));
        }

        tester.semantics.performAction(
          find.semantics.byLabel('Open Acts 3:2, 6-7 in Gospel Library'),
          SemanticsAction.tap,
        );
        await tester.pumpAndSettle();
        expect(opened, hasLength(1));
        expect(opened.single.mode, LaunchMode.externalApplication);
        expect(opened.single.uri, gospelLibraryUri('Acts 3:2, 6-7'));
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'the reference stays tappable when explanations are off, at large text',
    (tester) async {
      final opened = <Uri>[];
      await _pumpGame(
        tester,
        reference: '1 Nephi 1:1',
        count: 2,
        textScale: 2,
        surface: const Size(320, 640),
        showExplanations: false,
        open: (uri, {LaunchMode mode = LaunchMode.platformDefault}) async {
          opened.add(uri);
          return true;
        },
      );
      await tester.ensureVisible(find.text('Alpha'));
      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('explanation')), findsNothing);
      expect(find.byKey(const Key('reference-chip')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('reference-chip')));
      await tester.pumpAndSettle();
      final chip = tester.getRect(find.byKey(const Key('reference-chip')));
      final next = tester.getRect(
        find.widgetWithText(FilledButton, 'Next question'),
      );
      expect(chip.bottom, lessThanOrEqualTo(next.top));
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('reference-chip')));
      await tester.pumpAndSettle();
      expect(opened, [gospelLibraryUri('1 Nephi 1:1')]);
    },
  );

  testWidgets('a second tap while a launch is in flight opens once', (
    tester,
  ) async {
    final release = Completer<bool>();
    var calls = 0;
    await _pumpGame(
      tester,
      reference: 'Acts 3:2, 6-7',
      open: (uri, {LaunchMode mode = LaunchMode.platformDefault}) {
        calls += 1;
        expect(mode, LaunchMode.externalApplication);
        return release.future;
      },
    );
    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reference-chip')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('reference-chip')));
    await tester.pump();
    expect(calls, 1);
    release.complete(true);
    await tester.pumpAndSettle();
    expect(calls, 1);
  });

  testWidgets('a failed launch on the feedback sheet shows a SnackBar', (
    tester,
  ) async {
    await _pumpGame(
      tester,
      reference: 'Psalms 23:1',
      open: (uri, {LaunchMode mode = LaunchMode.platformDefault}) async {
        return false;
      },
    );
    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reference-chip')));
    await tester.pump();
    expect(find.text(couldNotOpenGospelLibraryMessage), findsOneWidget);
  });

  testWidgets('review opens the verse and announces it as a link', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final opened = <({Uri uri, LaunchMode mode})>[];
    try {
      await _pumpReview(
        tester,
        reference: 'D&C 1:38',
        open: (uri, {LaunchMode mode = LaunchMode.platformDefault}) async {
          opened.add((uri: uri, mode: mode));
          return true;
        },
      );

      final chipFinder = find.byType(ScriptureReferenceChip);
      expect(chipFinder, findsOneWidget);
      expect(find.byIcon(Icons.open_in_new), findsOneWidget);
      expect(
        tester.getSemantics(chipFinder),
        matchesSemantics(
          label: 'Open D&C 1:38 in Gospel Library',
          isLink: true,
          isButton: false,
          hasTapAction: true,
          textDirection: TextDirection.ltr,
        ),
      );

      final chip = tester.getRect(chipFinder);
      expect(chip.width, greaterThanOrEqualTo(StSpace.minTap));
      expect(chip.height, greaterThanOrEqualTo(StSpace.minTap));
      for (final guideline in _guidelines) {
        await expectLater(tester, meetsGuideline(guideline));
      }

      await tester.tap(find.text('D&C 1:38'));
      await tester.pumpAndSettle();
      expect(opened, hasLength(1));
      expect(opened.single.mode, LaunchMode.externalApplication);
      expect(opened.single.uri, gospelLibraryUri('D&C 1:38'));
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
    'a linked review card is one stop and the link is a separate stop',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await _pumpReview(
          tester,
          reference: 'D&C 1:38',
          open: (uri, {LaunchMode mode = LaunchMode.platformDefault}) async {
            return true;
          },
        );

        final card = tester.getSemantics(
          find.byKey(const Key('review-answer-dc-0001')),
        );
        expect(card.label, isNot(contains('D&C 1:38')));
        final separate = <SemanticsNode>[];
        card.visitChildren((child) {
          if (!child.isMergedIntoParent) separate.add(child);
          return true;
        });
        expect(separate, isEmpty, reason: card.label);

        final links = find.semantics
            .byLabel('Open D&C 1:38 in Gospel Library')
            .evaluate();
        expect(links, hasLength(1));
        expect(links.single.isMergedIntoParent, isFalse);
        expect(
          links.single.getSemanticsData().hasAction(SemanticsAction.tap),
          isTrue,
        );
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('a failed launch on the review screen shows a SnackBar', (
    tester,
  ) async {
    await _pumpReview(
      tester,
      reference: 'JS—History 1:17',
      open: (uri, {LaunchMode mode = LaunchMode.platformDefault}) async {
        return false;
      },
    );
    await tester.tap(find.text('JS—History 1:17'));
    await tester.pump();
    expect(find.text(couldNotOpenGospelLibraryMessage), findsOneWidget);
  });

  testWidgets('a reference that does not parse stays plain text', (
    tester,
  ) async {
    final opened = <Uri>[];
    await _pumpReview(
      tester,
      reference: 'D&C 20 heading',
      open: (uri, {LaunchMode mode = LaunchMode.platformDefault}) async {
        opened.add(uri);
        return true;
      },
    );
    expect(find.byIcon(Icons.open_in_new), findsNothing);
    expect(find.text('D&C 20 heading'), findsOneWidget);
    await tester.tap(find.text('D&C 20 heading'));
    await tester.pump();
    expect(opened, isEmpty);
  });
}

QuestionBank _bank(String reference, {int count = 1}) {
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
          explanation: 'Because the record says so.',
          reviewStatus: ReviewStatus.draft,
        ),
    ],
  );
}

Future<void> _pumpGame(
  WidgetTester tester, {
  required String reference,
  required OpenLink open,
  int count = 1,
  double textScale = 1,
  Size surface = const Size(400, 800),
  bool showExplanations = true,
}) async {
  await tester.binding.setSurfaceSize(surface);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  final container = ProviderContainer(
    overrides: [
      questionBankLoaderProvider.overrideWith(
        (ref) =>
            () async => _bank(reference, count: count),
      ),
      gameRandomProvider.overrideWith((ref) => Random(1)),
      if (!showExplanations)
        showExplanationsProvider.overrideWith((ref) => false),
      openLinkProvider.overrideWith((ref) => open),
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
  await tester.pump();
  await tester.pump();
}

class _HeldGame extends GameController {
  _HeldGame(this.session);

  final GameSession session;

  @override
  GameSession? build() => session;
}

Future<void> _pumpReview(
  WidgetTester tester, {
  required String reference,
  required OpenLink open,
}) async {
  await tester.binding.setSurfaceSize(const Size(400, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final question = GameQuestion(
    id: 'dc-0001',
    volume: ScriptureVolume.dc,
    reference: reference,
    prompt: 'Which verse is this?',
    options: const ['Alpha', 'Beta', 'Gamma', 'Delta'],
    answerIndex: 0,
    explanation: 'See the reference.',
  );
  final session = GameSession(
    volumes: const [ScriptureVolume.dc],
    requestedCount: 1,
    questions: [question],
    currentIndex: 1,
    answers: const [
      GameAnswer(questionId: 'dc-0001', selectedIndex: 0, correct: true),
    ],
    score: 1,
    currentStreak: 1,
    bestStreak: 1,
  );
  final container = ProviderContainer(
    overrides: [
      questionBankLoaderProvider.overrideWith(
        (ref) =>
            () async => _bank(reference),
      ),
      gameControllerProvider.overrideWith(() => _HeldGame(session)),
      openLinkProvider.overrideWith((ref) => open),
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
  container.read(appRouterProvider).go(AppRoutes.review);
  await tester.pumpAndSettle();
}
