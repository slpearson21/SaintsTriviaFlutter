import 'package:flutter_test/flutter_test.dart';
import 'package:saints_trivia_flutter/data/questions/scripture_volume.dart';
import 'package:saints_trivia_flutter/game/game_engine.dart';
import 'package:saints_trivia_flutter/results/results_summary.dart';

void main() {
  test('scorePercent rounds half away from zero and clamps', () {
    expect(scorePercent(0, 10), 0);
    expect(scorePercent(1, 0), 0);
    expect(scorePercent(1, -1), 0);
    expect(scorePercent(-1, 10), 0);
    expect(scorePercent(1, 2), 50);
    expect(scorePercent(1, 3), 33);
    expect(scorePercent(2, 3), 67);
    expect(scorePercent(1, 8), 13);
    expect(scorePercent(1, 200), 1);
    expect(scorePercent(11, 10), 100);
  });

  test('resultsHeadline changes at 50 and 90', () {
    expect(resultsHeadline(49), "Keep studying, you'll get there!");
    expect(resultsHeadline(50), 'Great effort!');
    expect(resultsHeadline(89), 'Great effort!');
    expect(resultsHeadline(90), 'Well done, good and faithful!');
  });

  test('a short answer list only counts the paired prefix', () {
    final questions = [
      _question('ot-0001', ScriptureVolume.ot),
      _question('nt-0001', ScriptureVolume.nt),
      _question('bom-0001', ScriptureVolume.bom),
    ];
    final session = GameSession(
      volumes: const [
        ScriptureVolume.ot,
        ScriptureVolume.nt,
        ScriptureVolume.bom,
      ],
      requestedCount: 3,
      questions: questions,
      currentIndex: 1,
      answers: const [
        GameAnswer(questionId: 'ot-0001', selectedIndex: 0, correct: true),
      ],
      score: 1,
      currentStreak: 1,
      bestStreak: 1,
    );

    final rows = breakdownByVolume(session);
    expect(rows, hasLength(1));
    expect(rows.single.volume, ScriptureVolume.ot);
    expect(rows.single.correct, 1);
    expect(rows.single.total, 1);

    final reviewed = reviewedAnswers(session);
    expect(reviewed, hasLength(1));
    expect(reviewed.single.question.id, 'ot-0001');
    expect(reviewed.single.selectedText, 'A');
  });

  test('selectedText is empty when the index is not an option', () {
    final question = _question('ot-0001', ScriptureVolume.ot);

    expect(
      ReviewedAnswer(
        question: question,
        answer: const GameAnswer(
          questionId: 'ot-0001',
          selectedIndex: -1,
          correct: false,
        ),
      ).selectedText,
      isEmpty,
    );
    expect(
      ReviewedAnswer(
        question: question,
        answer: const GameAnswer(
          questionId: 'ot-0001',
          selectedIndex: 4,
          correct: false,
        ),
      ).selectedText,
      isEmpty,
    );
    expect(
      ReviewedAnswer(
        question: question,
        answer: const GameAnswer(
          questionId: 'ot-0001',
          selectedIndex: 2,
          correct: false,
        ),
      ).selectedText,
      'C',
    );
  });
}

GameQuestion _question(String id, ScriptureVolume volume) {
  return GameQuestion(
    id: id,
    volume: volume,
    reference: 'Genesis 1:1',
    prompt: 'Prompt $id',
    options: const ['A', 'B', 'C', 'D'],
    answerIndex: 0,
    explanation: 'Because.',
  );
}
