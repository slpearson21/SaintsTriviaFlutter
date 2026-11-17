import 'dart:math';
import 'dart:ui' show Tristate;

import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saints_trivia_flutter/app.dart';
import 'package:saints_trivia_flutter/data/questions/question_bank_provider.dart';
import 'package:saints_trivia_flutter/data/questions/questions.dart';
import 'package:saints_trivia_flutter/game/game_engine.dart';
import 'package:saints_trivia_flutter/persistence/finished_game_record.dart';
import 'package:saints_trivia_flutter/persistence/memory_progress_repository.dart';
import 'package:saints_trivia_flutter/persistence/persistence_providers.dart';
import 'package:saints_trivia_flutter/game/game_providers.dart';
import 'package:saints_trivia_flutter/progress/home_providers.dart';
import 'package:saints_trivia_flutter/progress/home_snapshot.dart';
import 'package:saints_trivia_flutter/progress/play_again.dart';
import 'package:saints_trivia_flutter/progress/record_finished_game.dart';
import 'package:saints_trivia_flutter/results/results_summary.dart';
import 'package:saints_trivia_flutter/routing/app_router.dart';
import 'package:saints_trivia_flutter/routing/routes.dart';
import 'package:saints_trivia_flutter/screens/game_screen.dart';
import 'package:saints_trivia_flutter/screens/results_screen.dart';
import 'package:saints_trivia_flutter/theme/st_theme.dart';

import 'support/fixed_home_snapshot.dart';

const _guidelines = <AccessibilityGuideline>[
  androidTapTargetGuideline,
  iOSTapTargetGuideline,
  labeledTapTargetGuideline,
  textContrastGuideline,
];

void main() {
  group('results copy', () {
    test('headlines follow the flow doc bands', () {
      expect(resultsHeadline(100), 'Well done, good and faithful!');
      expect(resultsHeadline(90), 'Well done, good and faithful!');
      expect(resultsHeadline(89), 'Great effort!');
      expect(resultsHeadline(80), 'Great effort!');
      expect(resultsHeadline(50), 'Great effort!');
      expect(resultsHeadline(49), "Keep studying, you'll get there!");
      expect(resultsHeadline(0), "Keep studying, you'll get there!");
    });

    test('personal best needs a stored percent and a higher score', () {
      const none = HomeSnapshot.firstRun();
      const lower = HomeSnapshot(
        gamesPlayed: 3,
        accuracyPercent: 70,
        bestStreak: 4,
        bestScorePercent: 70,
      );
      const tie = HomeSnapshot(
        gamesPlayed: 3,
        accuracyPercent: 80,
        bestStreak: 4,
        bestScorePercent: 80,
      );

      expect(isNewPersonalBestPercent(100, none.bestScorePercent), isFalse);
      expect(isNewPersonalBestPercent(80, lower.bestScorePercent), isTrue);
      expect(isNewPersonalBestPercent(80, tie.bestScorePercent), isFalse);
      expect(isNewPersonalBestPercent(70, lower.bestScorePercent), isFalse);
      expect(isNewPersonalBestPercent(69, lower.bestScorePercent), isFalse);
      expect(
        showResultsSparkle(percent: 100, personalBest: false, firstGame: true),
        isFalse,
      );
      expect(
        showResultsSparkle(percent: 90, personalBest: false, firstGame: false),
        isTrue,
      );
      expect(
        showResultsSparkle(percent: 80, personalBest: true, firstGame: false),
        isTrue,
      );
      expect(
        showResultsSparkle(percent: 80, personalBest: false, firstGame: false),
        isFalse,
      );
    });

    test(
      'breakdown keeps standard-works order for volumes that were dealt',
      () {
        final session = _played(const [
          _Pick('dc-0001', ScriptureVolume.dc, 'D&C prompt', 'D&C 1:1', 0, 1),
          _Pick(
            'bom-0001',
            ScriptureVolume.bom,
            'BOM prompt',
            '1 Nephi 1:1',
            0,
            0,
          ),
          _Pick(
            'bom-0002',
            ScriptureVolume.bom,
            'BOM prompt 2',
            '1 Nephi 1:2',
            0,
            0,
          ),
        ]);

        final rows = breakdownByVolume(session);
        expect(rows.map((row) => row.volume), [
          ScriptureVolume.bom,
          ScriptureVolume.dc,
        ]);
        expect(rows[0].correct, 2);
        expect(rows[0].total, 2);
        expect(rows[1].correct, 0);
        expect(rows[1].total, 1);
      },
    );

    test('an empty or unfinished session is not results', () {
      expect(isFinishedSession(null), isFalse);
      expect(isFinishedSession(_played(const [])), isFalse);
      final unfinished = _played(const [
        _Pick('bom-0001', ScriptureVolume.bom, 'Prompt', '1 Nephi 1:1', 0, 0),
      ], complete: false);
      expect(unfinished.isComplete, isFalse);
      expect(isFinishedSession(unfinished), isFalse);
    });
  });

  testWidgets('a perfect game sparkles and the missed filter is empty', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    try {
      final session = _perfect();
      await _openResults(tester, session: session);
      expect(find.text('Well done, good and faithful!'), findsOneWidget);
      expect(find.text('You answered 4 of 4 correctly.'), findsOneWidget);
      expect(
        find.bySemanticsLabel('You answered 4 of 4 correctly.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('results-sparkle')), findsNothing);
      expect(find.byKey(const Key('results-personal-best')), findsNothing);
      expect(
        find.textContaining('Best streak 4', findRichText: true),
        findsOneWidget,
      );

      await _tap(tester, const Key('results-review'));
      await tester.pumpAndSettle();
      expect(find.text('All (4)'), findsOneWidget);
      expect(find.text('Missed (0)'), findsOneWidget);
      expect(find.text('Correct (4)'), findsOneWidget);

      await tester.tap(find.byKey(const Key('review-filter-missed')));
      await tester.pumpAndSettle();
      expect(find.text("You didn't miss any"), findsOneWidget);
      expect(
        find.textContaining('A perfect game! Try a longer game'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('review-play-again')), findsOneWidget);
      final missed = tester.getSemantics(
        find.byKey(const Key('review-filter-missed')),
      );
      expect(missed.label, 'Missed (0)');
      expect(missed.flagsCollection.isButton, isTrue);
      expect(missed.flagsCollection.isSelected, Tristate.isTrue);
      final all = tester.getSemantics(
        find.byKey(const Key('review-filter-all')),
      );
      expect(all.label, 'All (4)');
      expect(all.flagsCollection.isSelected, isNot(Tristate.isTrue));
    } finally {
      handle.dispose();
    }
  });

  testWidgets('a mixed game filters to the misses and shows both answers', (
    tester,
  ) async {
    await _openResults(tester, session: _mixed());
    expect(find.text('Great effort!'), findsOneWidget);
    expect(find.text('You answered 2 of 4 correctly.'), findsOneWidget);
    expect(find.text('Book of Mormon'), findsOneWidget);
    expect(find.text('2/2'), findsOneWidget);
    expect(find.text('Doctrine and Covenants'), findsOneWidget);
    expect(find.text('0/2'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('results-review')));
    await tester.tap(find.byKey(const Key('results-review')));
    await tester.pumpAndSettle();

    expect(
      find.text('Where was the Church formally organized?'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Correct answer: Nephi', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Missed'), findsWidgets);
    expect(find.text('Correct'), findsWidgets);

    await tester.tap(find.byKey(const Key('review-filter-missed')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Your answer: Palmyra, New York', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Correct answer: Fayette, New York',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('Your answer: Oliver Cowdery', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Correct answer: Joseph Smith Sr.',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(find.text('D&C 20 heading'), findsOneWidget);
    expect(find.text('Nephi'), findsNothing);
    expect(find.text('King Noah'), findsNothing);
    // The review mock shows the reference, not the one-line explanation.
    expect(
      find.textContaining('The Church was organized in Fayette.'),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('review-filter-correct')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Correct answer: Nephi', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('Correct answer: King Noah', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('1 Nephi 3–4'), findsOneWidget);
    expect(find.textContaining('Palmyra', findRichText: true), findsNothing);
    expect(
      find.textContaining('Your answer:', findRichText: true),
      findsNothing,
    );
  });

  testWidgets('the correct filter empty state points at missed', (
    tester,
  ) async {
    final session = _played(const [
      _Pick(
        'dc-0001',
        ScriptureVolume.dc,
        'Where was the Church formally organized?',
        'D&C 20 heading',
        0,
        1,
      ),
    ]);
    await _openResults(tester, session: session);
    await _tap(tester, const Key('results-review'));
    await tester.tap(find.byKey(const Key('review-filter-correct')));
    await tester.pumpAndSettle();
    expect(find.text('No correct answers this time'), findsOneWidget);
    expect(find.text('Check Missed to see the right answers.'), findsOneWidget);
    expect(find.text('None correct this time'), findsNothing);
  });

  testWidgets('review cards name missed or correct once for the reader', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    try {
      await _openResults(tester, session: _mixed());
      await _tap(tester, const Key('results-review'));

      _expectOneReviewStop(
        tester,
        const Key('review-answer-dc-0020'),
        'Missed',
        'Where was the Church formally organized?',
      );
      _expectOneReviewStop(
        tester,
        const Key('review-answer-bom-0003'),
        'Correct',
        'Who returned to Jerusalem to obtain the brass plates from Laban?',
      );
    } finally {
      handle.dispose();
    }
  });

  testWidgets('a long reference wraps at 200% text', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    Future<void> open(Size surface) async {
      await tester.binding.setSurfaceSize(surface);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      await _openResults(
        tester,
        session: _played(const [
          _Pick(
            'pgp-0001',
            ScriptureVolume.pgp,
            'Which verses record this?',
            'Joseph Smith—History 1:70-71',
            0,
            0,
          ),
        ]),
      );
      await _tap(tester, const Key('results-review'));
      expect(find.text('Joseph Smith—History 1:70-71'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }

    await open(const Size(393, 852));
    await open(const Size(320, 568));
  });

  testWidgets('a later perfect game sparkles, and the first one does not', (
    tester,
  ) async {
    await _openResults(
      tester,
      session: _perfect(),
      snapshot: const HomeSnapshot(
        gamesPlayed: 2,
        accuracyPercent: 50,
        bestStreak: 2,
        bestScorePercent: 50,
      ),
    );
    expect(find.byKey(const Key('results-sparkle')), findsOneWidget);
    expect(find.byKey(const Key('results-personal-best')), findsOneWidget);
  });

  testWidgets('the personal best chip stays after the game is recorded', (
    tester,
  ) async {
    final repo = MemoryProgressRepository(
      games: [
        FinishedGameRecord(
          score: 8,
          total: 10,
          percent: 80,
          bestStreak: 4,
          playedAt: DateTime(2026, 11, 1),
          volumes: const [ScriptureVolume.bom],
          questionCount: 10,
          volumeCorrect: const {ScriptureVolume.bom: 8},
          volumeTotal: const {ScriptureVolume.bom: 10},
        ),
      ],
    );
    final session = _ninetyPercent();
    final container = await _pump(
      tester,
      overrides: [
        _held(session),
        progressRepositoryProvider.overrideWithValue(repo),
      ],
    );
    container.read(appRouterProvider).go(AppRoutes.results);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('results-personal-best')), findsOneWidget);
    expect(find.byKey(const Key('results-sparkle')), findsOneWidget);
    expect(repo.readGames(), hasLength(2));
    expect(container.read(recordedBestProvider).previousBestPercent, 80);
    expect(container.read(homeSnapshotProvider).bestScorePercent, 90);

    await tester.pump();
    expect(find.byKey(const Key('results-personal-best')), findsOneWidget);
    expect(find.byKey(const Key('results-sparkle')), findsOneWidget);
  });

  testWidgets('personal best chip follows the snapshot seam', (tester) async {
    final session = _mixed();
    await _openResults(
      tester,
      session: session,
      snapshot: const HomeSnapshot(
        gamesPlayed: 4,
        accuracyPercent: 60,
        bestStreak: 3,
        bestScorePercent: 40,
      ),
    );
    expect(find.byKey(const Key('results-personal-best')), findsOneWidget);
    expect(
      find.textContaining('New personal best', findRichText: true),
      findsOneWidget,
    );
    expect(find.byKey(const Key('results-sparkle')), findsOneWidget);

    await _openResults(
      tester,
      session: session,
      snapshot: const HomeSnapshot(
        gamesPlayed: 4,
        accuracyPercent: 80,
        bestStreak: 9,
        bestScorePercent: 90,
      ),
    );
    expect(find.byKey(const Key('results-personal-best')), findsNothing);
    expect(find.byKey(const Key('results-sparkle')), findsNothing);
  });

  testWidgets('the score counts up, and reduced motion shows the end', (
    tester,
  ) async {
    await _pumpScreen(tester, session: _mixed());
    await tester.pump();
    expect(_numeral(tester), '0 / 4');
    expect(find.text('You answered 2 of 4 correctly.'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    expect(_numeral(tester), '2 / 4');
    expect(find.text('50%'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _pumpScreen(tester, session: _perfect());
    await tester.pump();
    expect(_numeral(tester), '4 / 4');
    expect(find.text('100%'), findsOneWidget);
    expect(find.byKey(const Key('results-sparkle')), findsNothing);
    expect(find.text('0 / 4'), findsNothing);
  });

  testWidgets('play again deals a new session before opening the game', (
    tester,
  ) async {
    final finished = _mixed();
    final bank = QuestionBank(
      schemaVersion: 1,
      questions: [
        for (var i = 0; i < 4; i++) _bankQuestion(ScriptureVolume.bom, i + 1),
        for (var i = 0; i < 4; i++) _bankQuestion(ScriptureVolume.dc, i + 1),
      ],
    );
    final container = await _pump(
      tester,
      overrides: [
        _held(finished),
        questionBankLoaderProvider.overrideWith(
          (ref) =>
              () async => bank,
        ),
        gameRandomProvider.overrideWith((ref) => Random(4)),
      ],
    );
    await container.read(questionBankProvider.future);
    container.read(appRouterProvider).go(AppRoutes.results);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('results-play-again')));
    await tester.tap(find.byKey(const Key('results-play-again')));
    await tester.pumpAndSettle();

    expect(find.byType(GameScreen), findsOneWidget);
    final next = container.read(gameControllerProvider);
    expect(next, isNotNull);
    expect(identical(next, finished), isFalse);
    expect(next!.currentIndex, 0);
    expect(next.isComplete, isFalse);
    expect(next.volumes, finished.volumes);
    expect(next.requestedCount, finished.requestedCount);
    // One deal. Play again leaves an in-progress session, and the game
    // route keeps that match. A second start would consume the seeded
    // Random. A finished session would not match, so it is not kept.
    final dealtOnce = startGame(
      bank: bank,
      volumes: finished.volumes,
      requestedCount: finished.requestedCount,
      random: Random(4),
    );
    expect(
      next.questions.map((question) => question.id).toList(),
      dealtOnce.questions.map((question) => question.id).toList(),
    );
  });

  testWidgets('play again uses the dealt length when the stored count is 0', (
    tester,
  ) async {
    final finished = _played(const [
      _Pick('bom-0001', ScriptureVolume.bom, 'One', '1 Nephi 1:1', 0, 0),
      _Pick('bom-0002', ScriptureVolume.bom, 'Two', '1 Nephi 1:2', 0, 0),
      _Pick('bom-0003', ScriptureVolume.bom, 'Three', '1 Nephi 1:3', 0, 1),
      _Pick('bom-0004', ScriptureVolume.bom, 'Four', '1 Nephi 1:4', 0, 0),
    ], requested: 0);
    final bank = QuestionBank(
      schemaVersion: 1,
      questions: [
        for (var i = 0; i < 6; i++) _bankQuestion(ScriptureVolume.bom, i + 1),
      ],
    );
    final container = await _pump(
      tester,
      overrides: [
        _held(finished),
        questionBankLoaderProvider.overrideWith(
          (ref) =>
              () async => bank,
        ),
        gameRandomProvider.overrideWith((ref) => Random(8)),
      ],
    );
    await container.read(questionBankProvider.future);
    container.read(appRouterProvider).go(AppRoutes.results);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('results-play-again')));
    await tester.tap(find.byKey(const Key('results-play-again')));
    await tester.pumpAndSettle();

    final settings = lastSettingsFor(finished);
    expect(settings.questionCount, finished.questionCount);
    final next = container.read(gameControllerProvider)!;
    expect(next.requestedCount, settings.questionCount);
    expect(next.currentIndex, 0);
    expect(next.isComplete, isFalse);
    final dealtOnce = startGame(
      bank: bank,
      volumes: settings.volumes,
      requestedCount: settings.questionCount,
      random: Random(8),
    );
    expect(
      next.questions.map((question) => question.id).toList(),
      dealtOnce.questions.map((question) => question.id).toList(),
    );
  });

  testWidgets('a played game records once, then play again starts question 1', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final recorded = <GameSession>[];
    final bank = QuestionBank(
      schemaVersion: 1,
      questions: [
        for (var i = 0; i < 2; i++)
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
    final container = await _pump(
      tester,
      overrides: [
        questionBankLoaderProvider.overrideWith(
          (ref) =>
              () async => bank,
        ),
        gameRandomProvider.overrideWith((ref) => Random(5)),
        recordFinishedGameProvider.overrideWith((ref) => recorded.add),
      ],
      settle: false,
    );
    await container.read(questionBankProvider.future);
    container
        .read(appRouterProvider)
        .go(
          AppRoutes.game,
          extra: const LastGameSettings(
            volumes: [ScriptureVolume.bom],
            questionCount: 2,
          ),
        );
    await tester.pump();
    await tester.pump();

    expect(find.text('Question 1 of 2'), findsOneWidget);
    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next question'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();
    expect(find.text('See results'), findsOneWidget);
    await tester.tap(find.text('See results'));
    await tester.pumpAndSettle();

    expect(find.text('You answered 2 of 2 correctly.'), findsOneWidget);
    expect(find.text('Well done, good and faithful!'), findsOneWidget);
    expect(recorded, hasLength(1));
    expect(recorded.single.score, 2);
    expect(recorded.single.isComplete, isTrue);
    final finished = recorded.single;

    await tester.ensureVisible(find.byKey(const Key('results-play-again')));
    await tester.tap(find.byKey(const Key('results-play-again')));
    await tester.pumpAndSettle();

    expect(find.text('Question 1 of 2'), findsOneWidget);
    final next = container.read(gameControllerProvider);
    expect(next, isNotNull);
    expect(identical(next, finished), isFalse);
    expect(next!.currentIndex, 0);
    expect(next.isComplete, isFalse);
    expect(next.score, 0);
    expect(recorded, [same(finished)]);
  });

  testWidgets('new game opens setup with these settings, and done goes home', (
    tester,
  ) async {
    final session = _mixed();
    await _openResults(tester, session: session);

    await tester.ensureVisible(find.byKey(const Key('results-new-game')));
    await tester.tap(find.byKey(const Key('results-new-game')));
    await tester.pumpAndSettle();
    expect(find.text('Select all'), findsOneWidget);
    expect(
      GoRouterState.of(tester.element(find.text('New game'))).extra,
      lastSettingsFor(session),
    );

    await tester.pageBack();
    await tester.pumpAndSettle();
    // New game replaced the stack with setup, so back is home.
    expect(find.text('Scripture Trivia'), findsOneWidget);

    await _openResults(tester, session: session);
    await tester.ensureVisible(find.byKey(const Key('results-done')));
    await tester.tap(find.byKey(const Key('results-done')));
    await tester.pumpAndSettle();
    expect(find.text('Scripture Trivia'), findsOneWidget);
    expect(find.text('Great effort!'), findsNothing);
  });

  testWidgets('no finished session redirects results and review home', (
    tester,
  ) async {
    await _pump(tester);
    final router = _router(tester);
    router.go(AppRoutes.results);
    await tester.pumpAndSettle();
    expect(find.text('Scripture Trivia'), findsOneWidget);
    expect(find.text('Results'), findsNothing);
    expect(tester.takeException(), isNull);

    router.go(AppRoutes.review);
    await tester.pumpAndSettle();
    expect(find.text('Scripture Trivia'), findsOneWidget);
    expect(find.text('Review answers'), findsNothing);

    final held = await _pump(
      tester,
      overrides: [
        _held(
          _played(const [
            _Pick(
              'bom-0001',
              ScriptureVolume.bom,
              'Prompt',
              '1 Nephi 1:1',
              0,
              0,
            ),
          ], complete: false),
        ),
      ],
    );
    held.read(appRouterProvider).go(AppRoutes.results);
    await tester.pumpAndSettle();
    expect(find.text('Scripture Trivia'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final empty = await _pump(tester, overrides: [_held(_played(const []))]);
    empty.read(appRouterProvider).go(AppRoutes.review);
    await tester.pumpAndSettle();
    expect(find.text('Review answers'), findsNothing);
    expect(find.text('Scripture Trivia'), findsOneWidget);
  });

  testWidgets('a finished game is recorded once across rebuilds', (
    tester,
  ) async {
    final recorded = <GameSession>[];
    final session = _perfect();
    final container = await _pump(
      tester,
      overrides: [
        _held(session),
        recordFinishedGameProvider.overrideWith((ref) => recorded.add),
        homeSnapshotProvider.overrideWith(_TickingHome.new),
      ],
    );
    container.read(appRouterProvider).go(AppRoutes.results);
    await tester.pumpAndSettle();
    expect(recorded, [same(session)]);

    container.read(_ticks.notifier).bump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(recorded, [same(session)]);
  });

  testWidgets('large text stacks the actions and fits the numeral', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await _openResults(
      tester,
      session: _mixed(),
      snapshot: const HomeSnapshot(
        gamesPlayed: 2,
        accuracyPercent: 40,
        bestStreak: 2,
        bestScorePercent: 40,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(
      tester
          .widget<FittedBox>(find.byKey(const Key('results-score-numeral')))
          .fit,
      BoxFit.scaleDown,
    );

    expect(find.text('Review answers'), findsOneWidget);
    final scroll = find.byType(SingleChildScrollView);
    expect(
      find.descendant(
        of: scroll,
        matching: find.byKey(const Key('results-play-again')),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: scroll,
        matching: find.byKey(const Key('results-new-game')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: scroll,
        matching: find.byKey(const Key('results-review')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: scroll,
        matching: find.byKey(const Key('results-done')),
      ),
      findsOneWidget,
    );
    final play = tester.getRect(find.byKey(const Key('results-play-again')));
    final screen = tester.getSize(find.byType(Scaffold));
    expect(play.top, greaterThanOrEqualTo(0));
    expect(play.bottom, lessThanOrEqualTo(screen.height));
    expect(play.bottom, greaterThan(screen.height - 40));
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position;
    if (position.maxScrollExtent > 0) {
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(const Key('results-play-again'))), play);
    }

    final streak = tester.getRect(find.byKey(const Key('results-best-streak')));
    final best = tester.getRect(find.byKey(const Key('results-personal-best')));
    expect(best.top, greaterThanOrEqualTo(streak.bottom - 1));
    expect(streak.center.dx, closeTo(best.center.dx, 24));
  });

  testWidgets('results and review meet tap and contrast guidelines', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    try {
      for (final brightness in Brightness.values) {
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        await _openResults(tester, session: _mixed());
        for (final guideline in _guidelines) {
          await expectLater(tester, meetsGuideline(guideline));
        }
        await _tap(tester, const Key('results-review'));
        for (final guideline in _guidelines) {
          await expectLater(tester, meetsGuideline(guideline));
        }
      }

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await _openResults(tester, session: _perfect());
      await _tap(tester, const Key('results-review'));
      await tester.tap(find.byKey(const Key('review-filter-missed')));
      await tester.pumpAndSettle();
      for (final guideline in _guidelines) {
        await expectLater(tester, meetsGuideline(guideline));
      }
    } finally {
      handle.dispose();
    }
  });

  testWidgets('iOS centers the title and Android keeps a back arrow', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await _openResults(tester, session: _mixed());
    expect(find.text('BY SCRIPTURE'), findsOneWidget);
    expect(find.text('By scripture'), findsNothing);
    final title = tester.getRect(find.text('Results'));
    expect(title.center.dx, closeTo(800 / 2, 40));

    await _tap(tester, const Key('results-review'));
    expect(find.text('Review answers'), findsOneWidget);
    expect(find.text('Results'), findsOneWidget);
    expect(find.byTooltip('Back'), findsNothing);

    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await _openResults(tester, session: _mixed());
    expect(find.text('By scripture'), findsOneWidget);
    expect(find.text('BY SCRIPTURE'), findsNothing);
    expect(find.byType(BackButton), findsOneWidget);
  });
}

class _TickingHome extends HomeSnapshotController {
  @override
  HomeSnapshot build() {
    ref.watch(_ticks);
    return const HomeSnapshot.firstRun();
  }

  @override
  void recordFinishedGame(GameSession session) {}

  @override
  void resetStats() {}
}

class _Ticks extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final _ticks = NotifierProvider<_Ticks, int>(_Ticks.new);

class _HeldGame extends GameController {
  _HeldGame(this.session);

  final GameSession? session;

  @override
  GameSession? build() => session;
}

class _Pick {
  const _Pick(
    this.id,
    this.volume,
    this.prompt,
    this.reference,
    this.answerIndex,
    this.selected, {
    this.options = const ['Nephi', 'Lehi', 'Sam', 'Laman'],
    this.explanation = 'See the reference.',
  });

  final String id;
  final ScriptureVolume volume;
  final String prompt;
  final String reference;
  final int answerIndex;
  final int selected;
  final List<String> options;
  final String explanation;
}

Override _held(GameSession? session) {
  return gameControllerProvider.overrideWith(() => _HeldGame(session));
}

GameSession _played(
  List<_Pick> picks, {
  bool complete = true,
  int requested = 10,
}) {
  final questions = [
    for (final pick in picks)
      GameQuestion(
        id: pick.id,
        volume: pick.volume,
        reference: pick.reference,
        prompt: pick.prompt,
        options: pick.options,
        answerIndex: pick.answerIndex,
        explanation: pick.explanation,
      ),
  ];
  final answers = <GameAnswer>[];
  var score = 0;
  var streak = 0;
  var best = 0;
  final answered = complete ? picks.length : 0;
  for (var i = 0; i < answered; i++) {
    final correct = picks[i].selected == picks[i].answerIndex;
    if (correct) {
      score += 1;
      streak += 1;
      if (streak > best) best = streak;
    } else {
      streak = 0;
    }
    answers.add(
      GameAnswer(
        questionId: picks[i].id,
        selectedIndex: picks[i].selected,
        correct: correct,
      ),
    );
  }
  final volumes = <ScriptureVolume>[];
  for (final pick in picks) {
    if (!volumes.contains(pick.volume)) volumes.add(pick.volume);
  }
  return GameSession(
    volumes: volumes.isEmpty ? const [ScriptureVolume.bom] : volumes,
    requestedCount: requested,
    questions: questions,
    currentIndex: complete ? questions.length : 0,
    answers: answers,
    score: score,
    currentStreak: streak,
    bestStreak: best,
  );
}

/// Two misses from the review mock, then two correct Book of Mormon answers.
GameSession _mixed() {
  return _played([
    const _Pick(
      'dc-0020',
      ScriptureVolume.dc,
      'Where was the Church formally organized?',
      'D&C 20 heading',
      1,
      0,
      options: [
        'Palmyra, New York',
        'Fayette, New York',
        'Kirtland, Ohio',
        'Nauvoo, Illinois',
      ],
      explanation: 'The Church was organized in Fayette.',
    ),
    const _Pick(
      'dc-0004',
      ScriptureVolume.dc,
      'To whom was the revelation in section 4 given?',
      'D&C 4 heading',
      1,
      0,
      options: [
        'Oliver Cowdery',
        'Joseph Smith Sr.',
        'Hyrum Smith',
        'Joseph Smith Jr.',
      ],
    ),
    const _Pick(
      'bom-0003',
      ScriptureVolume.bom,
      'Who returned to Jerusalem to obtain the brass plates from Laban?',
      '1 Nephi 3–4',
      0,
      0,
    ),
    const _Pick(
      'bom-0011',
      ScriptureVolume.bom,
      "Which king heard Abinadi's preaching?",
      'Mosiah 11–17',
      0,
      0,
      options: ['King Noah', 'King Benjamin', 'King Mosiah', 'King Limhi'],
    ),
  ]);
}

/// Nine correct answers and one miss: 90%.
GameSession _ninetyPercent() {
  return _played([
    for (var i = 0; i < 9; i++)
      _Pick(
        'bom-${(i + 1).toString().padLeft(4, '0')}',
        ScriptureVolume.bom,
        'Prompt $i',
        '1 Nephi 1:${i + 1}',
        0,
        0,
      ),
    const _Pick(
      'bom-0010',
      ScriptureVolume.bom,
      'Prompt 9',
      '1 Nephi 1:10',
      0,
      1,
    ),
  ]);
}

GameSession _perfect() {
  return _played(const [
    _Pick('bom-0001', ScriptureVolume.bom, 'First', '1 Nephi 1:1', 0, 0),
    _Pick('bom-0002', ScriptureVolume.bom, 'Second', '1 Nephi 1:2', 0, 0),
    _Pick('dc-0001', ScriptureVolume.dc, 'Third', 'D&C 1:1', 0, 0),
    _Pick('dc-0002', ScriptureVolume.dc, 'Fourth', 'D&C 1:2', 0, 0),
  ]);
}

TriviaQuestion _bankQuestion(ScriptureVolume volume, int n) {
  return TriviaQuestion(
    id: '${volume.idPrefix}-${n.toString().padLeft(4, '0')}',
    volume: volume,
    reference: 'Ref $n',
    prompt: 'Prompt $n',
    options: const ['Nephi', 'Lehi', 'Sam', 'Laman'],
    answerIndex: 0,
    explanation: 'Because the record says so.',
    reviewStatus: ReviewStatus.draft,
  );
}

/// The card is one screen-reader stop: the status and the prompt share it.
void _expectOneReviewStop(
  WidgetTester tester,
  Key key,
  String status,
  String prompt,
) {
  final node = tester.getSemantics(find.byKey(key));
  expect(node.mergeAllDescendantsIntoThisNode, isTrue, reason: status);
  final label = node.getSemanticsData().label;
  expect(label, contains(status));
  expect(label, contains(prompt));
  final separate = <SemanticsNode>[];
  node.visitChildren((child) {
    if (!child.isMergedIntoParent) separate.add(child);
    return true;
  });
  expect(separate, isEmpty, reason: status);
}

String _numeral(WidgetTester tester) {
  final fitted = tester.widget<FittedBox>(
    find.byKey(const Key('results-score-numeral')),
  );
  final column = fitted.child! as Column;
  return (column.children.first as Text).data!;
}

Future<void> _tap(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

/// Results without the router, so the ring's first frame is not behind a
/// page transition.
Future<void> _pumpScreen(
  WidgetTester tester, {
  required GameSession session,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        _held(session),
        fixedHomeSnapshot(const HomeSnapshot.firstRun()),
      ],
      child: MaterialApp(
        theme: buildTheme(Brightness.light),
        home: const ResultsScreen(),
      ),
    ),
  );
}

GoRouter _router(WidgetTester tester) {
  return GoRouter.of(tester.element(find.byType(Scaffold).first));
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  List<Override> overrides = const [],
  bool settle = true,
}) async {
  final container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const SaintsTriviaApp(),
    ),
  );
  if (settle) await tester.pumpAndSettle();
  return container;
}

Future<ProviderContainer> _openResults(
  WidgetTester tester, {
  required GameSession session,
  HomeSnapshot snapshot = const HomeSnapshot.firstRun(),
  List<Override> extra = const [],
}) async {
  final container = await _pump(
    tester,
    overrides: [_held(session), fixedHomeSnapshot(snapshot), ...extra],
  );
  container.read(appRouterProvider).go(AppRoutes.results);
  await tester.pumpAndSettle();
  return container;
}
