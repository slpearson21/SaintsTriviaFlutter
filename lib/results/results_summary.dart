import '../data/questions/scripture_volume.dart';
import '../game/game_engine.dart';
import '../progress/home_snapshot.dart';

/// A finished game Results and Review can show.
///
/// An empty deal is complete the moment it starts (`0 >= 0`) and has no
/// score to draw. Treat that the same as a missing session.
bool isFinishedSession(GameSession? session) {
  return session != null && session.isComplete && session.questionCount > 0;
}

/// Whole percent, from 0 to 100. An empty game is 0.
int scorePercent(int correct, int total) {
  if (total <= 0) return 0;
  final percent = ((correct * 100) / total).round();
  if (percent < 0) return 0;
  if (percent > 100) return 100;
  return percent;
}

/// Headline for [percent], from the v1 flow doc.
///
/// * 90 and above: "Well done, good and faithful!"
/// * 50 to 89: "Great effort!"
/// * Under 50: "Keep studying, you'll get there!"
String resultsHeadline(int percent) {
  if (percent >= 90) return 'Well done, good and faithful!';
  if (percent >= 50) return 'Great effort!';
  return "Keep studying, you'll get there!";
}

/// Sentence under the ring, and the ring's semantics label.
String answeredCorrectlySentence(int correct, int total) {
  return 'You answered $correct of $total correctly.';
}

/// True when [percent] is strictly above [previous].
///
/// A null [previous] means nothing comparable is on record yet, which is
/// the first game, so this is false. A tie is not a new best.
bool isNewPersonalBestPercent(int percent, int? previous) {
  if (previous == null) return false;
  return percent > previous;
}

/// True when [percent] is strictly above [HomeSnapshot.bestScorePercent].
///
/// A null best means the snapshot has nothing comparable yet, so this is
/// false and the personal-best chip stays hidden. A tie is not a new best.
bool isNewPersonalBest(int percent, HomeSnapshot snapshot) {
  return isNewPersonalBestPercent(percent, snapshot.bestScorePercent);
}

/// A small gold sparkle at 90% or above, or on a personal best.
///
/// The first game ever has nothing to beat, so it never sparkles, even
/// at 100%. [firstGame] is that case: no earlier percent is on record.
bool showResultsSparkle({
  required int percent,
  required bool personalBest,
  required bool firstGame,
}) {
  if (firstGame) return false;
  return percent >= 90 || personalBest;
}

/// Correct and total for one volume that was actually dealt.
final class VolumeBreakdown {
  const VolumeBreakdown({
    required this.volume,
    required this.correct,
    required this.total,
  });

  final ScriptureVolume volume;
  final int correct;
  final int total;
}

/// Volumes that were played, in standard-works order.
///
/// Questions and answers are paired by index. A hand-built session that
/// has fewer answers than questions only counts the paired prefix.
List<VolumeBreakdown> breakdownByVolume(GameSession session) {
  final correct = <ScriptureVolume, int>{};
  final total = <ScriptureVolume, int>{};
  final count = session.answers.length < session.questions.length
      ? session.answers.length
      : session.questions.length;
  for (var i = 0; i < count; i++) {
    final question = session.questions[i];
    final answer = session.answers[i];
    total[question.volume] = (total[question.volume] ?? 0) + 1;
    if (answer.correct) {
      correct[question.volume] = (correct[question.volume] ?? 0) + 1;
    }
  }
  return [
    for (final volume in ScriptureVolume.values)
      if ((total[volume] ?? 0) > 0)
        VolumeBreakdown(
          volume: volume,
          correct: correct[volume] ?? 0,
          total: total[volume] ?? 0,
        ),
  ];
}

/// One dealt question plus the choice the player made.
final class ReviewedAnswer {
  const ReviewedAnswer({required this.question, required this.answer});

  final GameQuestion question;
  final GameAnswer answer;

  bool get correct => answer.correct;

  /// The option the player tapped. Empty if the index is not an option.
  String get selectedText {
    final index = answer.selectedIndex;
    if (index < 0 || index >= question.options.length) return '';
    return question.options[index];
  }

  String get correctText => question.answer;
}

/// Answers in deal order. The review list groups these; it does not reorder
/// them except to put misses before correct answers.
List<ReviewedAnswer> reviewedAnswers(GameSession session) {
  final count = session.answers.length < session.questions.length
      ? session.answers.length
      : session.questions.length;
  return [
    for (var i = 0; i < count; i++)
      ReviewedAnswer(
        question: session.questions[i],
        answer: session.answers[i],
      ),
  ];
}
