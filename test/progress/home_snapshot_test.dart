import 'package:flutter_test/flutter_test.dart';
import 'package:saints_trivia_flutter/data/questions/scripture_volume.dart';
import 'package:saints_trivia_flutter/progress/home_snapshot.dart';

void main() {
  final now = DateTime(2026, 11, 15, 9);

  test('play again with no volumes speaks the question count', () {
    expect(
      playAgainSemanticsLabel(
        const LastGameSettings(volumes: [], questionCount: 10),
      ),
      'Play again, 10 questions',
    );
    expect(
      playAgainSemanticsLabel(
        const LastGameSettings(volumes: [], questionCount: 1),
      ),
      'Play again, 1 question',
    );
  });

  test('play again speaks full volume names in standard-works order', () {
    expect(
      playAgainSemanticsLabel(
        const LastGameSettings(
          volumes: [ScriptureVolume.dc, ScriptureVolume.bom],
          questionCount: 10,
        ),
      ),
      'Play again, Book of Mormon, Doctrine and Covenants, 10 questions',
    );
  });

  test('last game line and its spoken form', () {
    final yesterday = LastGameSummary(
      correct: 8,
      total: 10,
      playedAt: DateTime(2026, 11, 14, 20),
    );
    final today = LastGameSummary(
      correct: 8,
      total: 10,
      playedAt: DateTime(2026, 11, 15, 8),
    );
    final earlier = LastGameSummary(
      correct: 4,
      total: 8,
      playedAt: DateTime(2026, 11, 9, 8),
    );

    expect(lastGameLine(yesterday, now), 'Last game: 8 / 10 · Yesterday');
    expect(
      lastGameSemanticsLabel(yesterday, now),
      'Last game: 8 out of 10, yesterday',
    );
    expect(lastGameLine(today, now), 'Last game: 8 / 10 · Today');
    expect(lastGameSemanticsLabel(today, now), 'Last game: 8 out of 10, today');
    expect(lastGameLine(earlier, now), 'Last game: 4 / 8 · Nov 9');
    expect(
      lastGameSemanticsLabel(earlier, now),
      'Last game: 4 out of 8, Nov 9',
    );
  });
}
