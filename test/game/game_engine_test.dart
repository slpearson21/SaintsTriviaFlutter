import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saints_trivia_flutter/data/questions/questions.dart';
import 'package:saints_trivia_flutter/game/game_engine.dart';
import 'package:saints_trivia_flutter/game/game_providers.dart';
import 'package:saints_trivia_flutter/report/question_report.dart';
import 'package:saints_trivia_flutter/report/reported_questions_provider.dart';

void main() {
  group('max available', () {
    test('is the smaller of 50 and the questions in the selection', () {
      expect(maxAvailableQuestions(0), 0);
      expect(maxAvailableQuestions(-3), 0);
      expect(maxAvailableQuestions(1), 1);
      expect(maxAvailableQuestions(49), 49);
      expect(maxAvailableQuestions(50), 50);
      expect(maxAvailableQuestions(51), 50);
      expect(maxAvailableQuestions(500), 50);
    });
  });

  group('clamp', () {
    test('leaves a request that fits the selection', () {
      expect(
        clampRequestedCount(requested: 10, questionsInSelectedVolumes: 80),
        10,
      );
      expect(
        clampRequestedCount(requested: 50, questionsInSelectedVolumes: 80),
        50,
      );
      expect(
        clampRequestedCount(requested: 23, questionsInSelectedVolumes: 23),
        23,
      );
    });

    test('caps a request at 50 even when more questions exist', () {
      expect(
        clampRequestedCount(requested: 80, questionsInSelectedVolumes: 100),
        50,
      );
      expect(
        clampRequestedCount(requested: 51, questionsInSelectedVolumes: 51),
        50,
      );
    });

    test('caps a request at the questions in the selection', () {
      expect(
        clampRequestedCount(requested: 50, questionsInSelectedVolumes: 23),
        23,
      );
      expect(
        clampRequestedCount(requested: 10, questionsInSelectedVolumes: 1),
        1,
      );
    });

    test('is 0 when the selection has no questions', () {
      expect(
        clampRequestedCount(requested: 10, questionsInSelectedVolumes: 0),
        0,
      );
      expect(
        clampRequestedCount(requested: 10, questionsInSelectedVolumes: -1),
        0,
      );
    });

    test('raises a non-positive request to 1 when anything is available', () {
      expect(
        clampRequestedCount(requested: 0, questionsInSelectedVolumes: 12),
        1,
      );
      expect(
        clampRequestedCount(requested: -4, questionsInSelectedVolumes: 12),
        1,
      );
    });
  });

  group('deal', () {
    test('does not repeat a question and stays inside the clamp', () {
      final bank = _bank(ot: 60, nt: 30);
      final session = startGame(
        bank: bank,
        volumes: const [ScriptureVolume.ot, ScriptureVolume.nt],
        requestedCount: 80,
        random: Random(1),
      );

      expect(session.requestedCount, 80);
      expect(session.questionCount, 50);
      expect(
        session.questions.map((question) => question.id).toSet(),
        hasLength(50),
      );
      expect(
        session.questions.every(
          (question) =>
              question.volume == ScriptureVolume.ot ||
              question.volume == ScriptureVolume.nt,
        ),
        isTrue,
      );
    });

    test('draws only from the selected volumes', () {
      final bank = _bank(ot: 8, nt: 8, bom: 8);
      final session = startGame(
        bank: bank,
        volumes: const [ScriptureVolume.nt],
        requestedCount: 40,
        random: Random(2),
      );

      expect(session.volumes, [ScriptureVolume.nt]);
      expect(session.questionCount, 8);
      expect(
        session.questions.map((question) => question.volume),
        everyElement(ScriptureVolume.nt),
      );
      expect(
        session.questions.map((question) => question.id).toSet(),
        hasLength(8),
      );
    });

    test('a seeded Random deals the same game twice', () {
      final bank = _bank(ot: 20);
      final first = startGame(
        bank: bank,
        volumes: const [ScriptureVolume.ot],
        requestedCount: 12,
        random: Random(4),
      );
      final second = startGame(
        bank: bank,
        volumes: const [ScriptureVolume.ot],
        requestedCount: 12,
        random: Random(4),
      );

      expect(_ids(first), _ids(second));
      expect(_optionOrders(first), _optionOrders(second));
    });

    test('shuffles option order and keeps the correct answer', () {
      final bank = _bank(ot: 12);
      final session = startGame(
        bank: bank,
        volumes: const [ScriptureVolume.ot],
        requestedCount: 12,
        random: Random(1),
      );

      expect(session.questionCount, 12);
      var shuffled = 0;
      for (final dealt in session.questions) {
        final source = bank.questions.singleWhere(
          (question) => question.id == dealt.id,
        );
        expect(dealt.answer, source.answer);
        expect(dealt.options.toSet(), source.options.toSet());
        expect(dealt.options[dealt.answerIndex], source.answer);
        if (!_sameOrder(dealt.options, source.options)) shuffled++;
      }
      expect(shuffled, greaterThan(0));
      expect(_ids(session), isNot(_idsInBankOrder(bank, ScriptureVolume.ot)));
    });

    test('a count past the pool deals each question once', () {
      final pool = _bank(ot: 4).questions;
      final over = dealQuestions(pool: pool, count: 10, random: Random(7));
      final exact = dealQuestions(
        pool: pool,
        count: pool.length,
        random: Random(7),
      );

      expect(over, hasLength(pool.length));
      expect(exact, hasLength(pool.length));
      expect(
        over.map((question) => question.id).toSet(),
        pool.map((question) => question.id).toSet(),
      );
      expect(
        exact.map((question) => question.id).toSet(),
        pool.map((question) => question.id).toSet(),
      );
    });

    test('a repeated volume does not deal a question twice', () {
      final bank = _bank(ot: 4, nt: 2);
      const volumes = [
        ScriptureVolume.ot,
        ScriptureVolume.ot,
        ScriptureVolume.nt,
      ];
      final once = questionsInVolumes(bank, const [
        ScriptureVolume.ot,
        ScriptureVolume.nt,
      ]);
      final twice = questionsInVolumes(bank, volumes);

      expect(
        twice.map((question) => question.id),
        once.map((question) => question.id),
      );
      expect(twice, hasLength(6));
    });

    test('an empty selection deals nothing', () {
      final session = startGame(
        bank: _bank(ot: 5),
        volumes: const [],
        requestedCount: 10,
        random: Random(1),
      );

      expect(session.questionCount, 0);
      expect(session.isComplete, isTrue);
      expect(applyAnswer(session, 0), same(session));
    });
  });

  group('scoring and streaks', () {
    test('a correct answer scores, and a wrong answer resets the streak', () {
      var session = _scripted();

      session = applyAnswer(session, 0);
      expect(session.score, 1);
      expect(session.currentStreak, 1);
      expect(session.bestStreak, 1);
      expect(session.currentIndex, 1);
      expect(session.answers.single.correct, isTrue);

      session = applyAnswer(session, 1);
      expect(session.score, 2);
      expect(session.currentStreak, 2);
      expect(session.bestStreak, 2);

      session = applyAnswer(session, 0);
      expect(session.score, 2);
      expect(session.currentStreak, 0);
      expect(session.bestStreak, 2);
      expect(session.answers[2].correct, isFalse);
      expect(session.answers[2].selectedIndex, 0);

      session = applyAnswer(session, 3);
      expect(session.score, 3);
      expect(session.currentStreak, 1);
      expect(session.bestStreak, 2);
      expect(session.isComplete, isTrue);
      expect(applyAnswer(session, 0), same(session));
    });

    test('best streak is the longest run, not the latest one', () {
      var session = GameSession(
        volumes: const [ScriptureVolume.ot],
        requestedCount: 5,
        questions: [
          _dealt('ot-0001', 0),
          _dealt('ot-0002', 1),
          _dealt('ot-0003', 2),
          _dealt('ot-0004', 3),
          _dealt('ot-0005', 1),
        ],
        currentIndex: 0,
        answers: const [],
        score: 0,
        currentStreak: 0,
        bestStreak: 0,
      );

      session = applyAnswer(session, 0);
      session = applyAnswer(session, 1);
      session = applyAnswer(session, 2);
      session = applyAnswer(session, 3);
      expect(session.currentStreak, 4);
      expect(session.bestStreak, 4);
      expect(session.score, 4);

      session = applyAnswer(session, 0);
      expect(session.currentStreak, 0);
      expect(session.bestStreak, 4);
      expect(session.score, 4);
    });

    test('a later longer run replaces best', () {
      final questions = [
        _dealt('ot-0001', 0),
        _dealt('ot-0002', 1),
        _dealt('ot-0003', 0),
        _dealt('ot-0004', 0),
        _dealt('ot-0005', 0),
      ];
      var session = GameSession(
        volumes: const [ScriptureVolume.ot],
        requestedCount: 5,
        questions: questions,
        currentIndex: 0,
        answers: const [],
        score: 0,
        currentStreak: 0,
        bestStreak: 0,
      );

      session = applyAnswer(session, 0);
      session = applyAnswer(session, 0);
      expect(session.currentStreak, 0);
      expect(session.bestStreak, 1);

      session = applyAnswer(session, 0);
      session = applyAnswer(session, 0);
      session = applyAnswer(session, 0);
      expect(session.score, 4);
      expect(session.currentStreak, 3);
      expect(session.bestStreak, 3);
      expect(session.currentIndex, 5);
    });

    test('rejects an option index the question does not have', () {
      expect(() => applyAnswer(_scripted(), 4), throwsArgumentError);
      expect(() => applyAnswer(_scripted(), -1), throwsArgumentError);
    });
  });

  group('game provider', () {
    test('keeps volumes, count, questions, index, answers, score, streaks', () {
      final bank = _bank(ot: 6);
      final container = ProviderContainer(
        overrides: [gameRandomProvider.overrideWith((ref) => Random(9))],
      );
      addTearDown(container.dispose);

      container
          .read(gameControllerProvider.notifier)
          .start(
            bank: bank,
            volumes: const [ScriptureVolume.ot],
            requestedCount: 4,
          );
      final dealt = container.read(gameControllerProvider)!;
      expect(dealt.volumes, [ScriptureVolume.ot]);
      expect(dealt.requestedCount, 4);
      expect(dealt.questions, hasLength(4));
      expect(dealt.currentIndex, 0);
      expect(dealt.answers, isEmpty);
      expect(dealt.score, 0);
      expect(dealt.currentStreak, 0);
      expect(dealt.bestStreak, 0);

      final again = startGame(
        bank: bank,
        volumes: const [ScriptureVolume.ot],
        requestedCount: 4,
        random: Random(9),
      );
      expect(_ids(dealt), _ids(again));

      container
          .read(gameControllerProvider.notifier)
          .answer(dealt.questions.first.answerIndex);
      final scored = container.read(gameControllerProvider)!;
      expect(scored.score, 1);
      expect(scored.currentStreak, 1);
      expect(scored.bestStreak, 1);
      expect(scored.currentIndex, 1);
      expect(scored.answers, hasLength(1));

      final wrong = scored.questions[1].answerIndex == 0 ? 1 : 0;
      container.read(gameControllerProvider.notifier).answer(wrong);
      final missed = container.read(gameControllerProvider)!;
      expect(missed.score, 1);
      expect(missed.currentStreak, 0);
      expect(missed.bestStreak, 1);
      expect(missed.currentIndex, 2);
    });

    test('answer does nothing before a game starts', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(gameControllerProvider.notifier).answer(0);
      expect(container.read(gameControllerProvider), isNull);
    });

    test('discard drops the game in progress', () {
      final bank = _bank(ot: 4);
      final container = ProviderContainer(
        overrides: [gameRandomProvider.overrideWith((ref) => Random(3))],
      );
      addTearDown(container.dispose);

      container
          .read(gameControllerProvider.notifier)
          .start(
            bank: bank,
            volumes: const [ScriptureVolume.ot],
            requestedCount: 3,
          );
      expect(container.read(gameControllerProvider), isNotNull);

      container.read(gameControllerProvider.notifier).discard();
      expect(container.read(gameControllerProvider), isNull);
    });

    test('start replaces a game in progress and clears reports', () {
      final bank = _bank(ot: 6);
      final container = ProviderContainer(
        overrides: [gameRandomProvider.overrideWith((ref) => Random(5))],
      );
      addTearDown(container.dispose);
      final games = container.read(gameControllerProvider.notifier);

      games.start(
        bank: bank,
        volumes: const [ScriptureVolume.ot],
        requestedCount: 4,
      );
      final first = container.read(gameControllerProvider)!;
      games.answer(first.questions.first.answerIndex);
      container
          .read(reportedQuestionIdsProvider.notifier)
          .markReported(first.questions.first.id);
      container
          .read(reportedQuestionIdsProvider.notifier)
          .saveDraft(
            first.questions.first.id,
            reason: ReportReason.other,
            note: 'check',
          );
      expect(container.read(gameControllerProvider)!.score, 1);
      expect(
        container.read(reportedQuestionIdsProvider).reportedIds,
        isNotEmpty,
      );

      games.start(
        bank: bank,
        volumes: const [ScriptureVolume.ot],
        requestedCount: 2,
      );
      final replaced = container.read(gameControllerProvider)!;
      expect(replaced.questionCount, 2);
      expect(replaced.currentIndex, 0);
      expect(replaced.score, 0);
      expect(replaced.currentStreak, 0);
      expect(replaced.bestStreak, 0);
      expect(replaced.answers, isEmpty);
      expect(replaced.requestedCount, 2);
      expect(container.read(reportedQuestionIdsProvider).reportedIds, isEmpty);
      expect(container.read(reportedQuestionIdsProvider).drafts, isEmpty);
    });
  });
}

QuestionBank _bank({int ot = 0, int nt = 0, int bom = 0}) {
  return QuestionBank(
    schemaVersion: 1,
    questions: [
      for (var i = 0; i < ot; i++) _question(ScriptureVolume.ot, i),
      for (var i = 0; i < nt; i++) _question(ScriptureVolume.nt, i),
      for (var i = 0; i < bom; i++) _question(ScriptureVolume.bom, i),
    ],
  );
}

TriviaQuestion _question(ScriptureVolume volume, int index) {
  final number = (index + 1).toString().padLeft(4, '0');
  return TriviaQuestion(
    id: '${volume.idPrefix}-$number',
    volume: volume,
    reference: 'Ref $number',
    prompt: 'Prompt ${volume.code} $number',
    options: const ['Adam', 'Eve', 'Noah', 'Moses'],
    answerIndex: index % 4,
    explanation: 'Because $number.',
    reviewStatus: ReviewStatus.draft,
  );
}

GameQuestion _dealt(String id, int answerIndex) {
  return GameQuestion(
    id: id,
    volume: ScriptureVolume.ot,
    reference: 'Ref',
    prompt: 'Prompt',
    options: const ['Adam', 'Eve', 'Noah', 'Moses'],
    answerIndex: answerIndex,
    explanation: 'Because.',
  );
}

/// Four questions whose correct indexes are 0, 1, 2, 3.
GameSession _scripted() {
  return GameSession(
    volumes: const [ScriptureVolume.ot],
    requestedCount: 4,
    questions: [
      _dealt('ot-0001', 0),
      _dealt('ot-0002', 1),
      _dealt('ot-0003', 2),
      _dealt('ot-0004', 3),
    ],
    currentIndex: 0,
    answers: const [],
    score: 0,
    currentStreak: 0,
    bestStreak: 0,
  );
}

List<String> _ids(GameSession session) {
  return [for (final question in session.questions) question.id];
}

List<List<String>> _optionOrders(GameSession session) {
  return [for (final question in session.questions) question.options];
}

List<String> _idsInBankOrder(QuestionBank bank, ScriptureVolume volume) {
  return [
    for (final question in bank.questions)
      if (question.volume == volume) question.id,
  ];
}

bool _sameOrder(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) return false;
  }
  return true;
}
