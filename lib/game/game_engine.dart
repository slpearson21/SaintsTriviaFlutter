import 'dart:math';

import '../data/questions/question_bank.dart';
import '../data/questions/scripture_volume.dart';
import '../data/questions/trivia_question.dart';

/// Hard cap from the v1 rules. A game never deals more than this.
const int maxQuestionsPerGame = 50;

/// `min(50, questions in the selected volumes)`.
///
/// Zero or a negative count means nothing can be dealt.
int maxAvailableQuestions(int questionsInSelectedVolumes) {
  if (questionsInSelectedVolumes <= 0) return 0;
  if (questionsInSelectedVolumes > maxQuestionsPerGame) {
    return maxQuestionsPerGame;
  }
  return questionsInSelectedVolumes;
}

/// Pulls [requested] into `1...maxAvailable`.
///
/// When the selection has no questions, the result is 0. A request below 1
/// becomes 1 when anything is available, which matches the stepper's floor.
int clampRequestedCount({
  required int requested,
  required int questionsInSelectedVolumes,
}) {
  final maxAvailable = maxAvailableQuestions(questionsInSelectedVolumes);
  if (maxAvailable == 0) return 0;
  if (requested < 1) return 1;
  if (requested > maxAvailable) return maxAvailable;
  return requested;
}

/// One question as dealt: options are in this game's order.
///
/// [answerIndex] points at the correct choice after the shuffle. The source
/// question's order is left alone.
final class GameQuestion {
  GameQuestion({
    required this.id,
    required this.volume,
    required this.reference,
    required this.prompt,
    required List<String> options,
    required this.answerIndex,
    required this.explanation,
  }) : options = List.unmodifiable(options);

  final String id;
  final ScriptureVolume volume;
  final String reference;
  final String prompt;
  final List<String> options;
  final int answerIndex;
  final String explanation;

  String get answer => options[answerIndex];
}

/// The player's choice for one dealt question.
final class GameAnswer {
  const GameAnswer({
    required this.questionId,
    required this.selectedIndex,
    required this.correct,
  });

  final String questionId;
  final int selectedIndex;
  final bool correct;
}

/// One game: what was asked for, what was dealt, and how it's going.
///
/// [requestedCount] is the count the player asked for, before the cap.
/// [questions] is the deal after [clampRequestedCount]. [bestStreak] is the
/// longest run of correct answers in this game. A wrong answer sets
/// [currentStreak] back to 0 and leaves [bestStreak] where it was.
final class GameSession {
  GameSession({
    required List<ScriptureVolume> volumes,
    required this.requestedCount,
    required List<GameQuestion> questions,
    required this.currentIndex,
    required List<GameAnswer> answers,
    required this.score,
    required this.currentStreak,
    required this.bestStreak,
  }) : volumes = List.unmodifiable(volumes),
       questions = List.unmodifiable(questions),
       answers = List.unmodifiable(answers) {
    assert(currentIndex >= 0, 'currentIndex cannot be negative');
    assert(currentIndex <= this.questions.length);
    assert(score >= 0 && score <= this.answers.length);
    assert(currentStreak >= 0);
    assert(bestStreak >= currentStreak, 'best streak is the max so far');
  }

  final List<ScriptureVolume> volumes;
  final int requestedCount;
  final List<GameQuestion> questions;
  final int currentIndex;
  final List<GameAnswer> answers;
  final int score;
  final int currentStreak;
  final int bestStreak;

  bool get isComplete => currentIndex >= questions.length;

  /// How many questions this game will ask, after the cap.
  int get questionCount => questions.length;
}

/// Questions from [bank] whose volume is in [volumes], bank order kept.
List<TriviaQuestion> questionsInVolumes(
  QuestionBank bank,
  List<ScriptureVolume> volumes,
) {
  if (volumes.isEmpty) return const [];
  final selected = volumes.toSet();
  return [
    for (final question in bank.questions)
      if (selected.contains(question.volume)) question,
  ];
}

/// Deals [count] questions from [pool] with no repeats.
///
/// [random] picks the sample and each question's option order, so a test
/// can pass a seeded [Random] and see the same game again. The shuffle is
/// written out here so that seed does not depend on [List.shuffle], whose
/// algorithm can change between Dart versions.
List<GameQuestion> dealQuestions({
  required List<TriviaQuestion> pool,
  required int count,
  required Random random,
}) {
  if (count <= 0 || pool.isEmpty) return const [];
  final take = count < pool.length ? count : pool.length;
  final order = List<int>.generate(
    pool.length,
    (index) => index,
    growable: false,
  );
  for (var i = 0; i < take; i++) {
    final swap = i + random.nextInt(pool.length - i);
    final current = order[i];
    order[i] = order[swap];
    order[swap] = current;
  }
  return List.unmodifiable([
    for (var i = 0; i < take; i++) _withShuffledOptions(pool[order[i]], random),
  ]);
}

/// Starts a game. The deal is clamped to [maxAvailableQuestions].
GameSession startGame({
  required QuestionBank bank,
  required List<ScriptureVolume> volumes,
  required int requestedCount,
  required Random random,
}) {
  final pool = questionsInVolumes(bank, volumes);
  final count = clampRequestedCount(
    requested: requestedCount,
    questionsInSelectedVolumes: pool.length,
  );
  return GameSession(
    volumes: volumes,
    requestedCount: requestedCount,
    questions: dealQuestions(pool: pool, count: count, random: random),
    currentIndex: 0,
    answers: const [],
    score: 0,
    currentStreak: 0,
    bestStreak: 0,
  );
}

/// Records [selectedIndex] and advances.
///
/// A finished game is returned unchanged. [selectedIndex] has to be one of
/// the dealt options.
GameSession applyAnswer(GameSession session, int selectedIndex) {
  if (session.isComplete) return session;
  final question = session.questions[session.currentIndex];
  if (selectedIndex < 0 || selectedIndex >= question.options.length) {
    throw ArgumentError.value(
      selectedIndex,
      'selectedIndex',
      'must be an option index',
    );
  }
  final correct = selectedIndex == question.answerIndex;
  final currentStreak = correct ? session.currentStreak + 1 : 0;
  final bestStreak = currentStreak > session.bestStreak
      ? currentStreak
      : session.bestStreak;
  return GameSession(
    volumes: session.volumes,
    requestedCount: session.requestedCount,
    questions: session.questions,
    currentIndex: session.currentIndex + 1,
    answers: [
      ...session.answers,
      GameAnswer(
        questionId: question.id,
        selectedIndex: selectedIndex,
        correct: correct,
      ),
    ],
    score: session.score + (correct ? 1 : 0),
    currentStreak: currentStreak,
    bestStreak: bestStreak,
  );
}

GameQuestion _withShuffledOptions(TriviaQuestion question, Random random) {
  final order = List<int>.generate(
    question.options.length,
    (index) => index,
    growable: false,
  );
  for (var i = 0; i < order.length; i++) {
    final swap = i + random.nextInt(order.length - i);
    final current = order[i];
    order[i] = order[swap];
    order[swap] = current;
  }
  return GameQuestion(
    id: question.id,
    volume: question.volume,
    reference: question.reference,
    prompt: question.prompt,
    options: [for (final index in order) question.options[index]],
    answerIndex: order.indexOf(question.answerIndex),
    explanation: question.explanation,
  );
}
