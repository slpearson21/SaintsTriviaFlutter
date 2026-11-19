import 'package:flutter_test/flutter_test.dart';
import 'package:saints_trivia_flutter/data/questions/scripture_volume.dart';
import 'package:saints_trivia_flutter/persistence/finished_game_record.dart';
import 'package:saints_trivia_flutter/progress/stats_summary.dart';

FinishedGameRecord _game({
  required int score,
  required int total,
  required int streak,
  required DateTime playedAt,
  required Map<ScriptureVolume, int> correct,
  required Map<ScriptureVolume, int> dealt,
  List<ScriptureVolume>? volumes,
  int? questionCount,
}) {
  return FinishedGameRecord(
    score: score,
    total: total,
    percent: total == 0 ? 0 : ((score * 100) / total).round(),
    bestStreak: streak,
    playedAt: playedAt,
    volumes: volumes ?? dealt.keys.toList(),
    questionCount: questionCount ?? total,
    volumeCorrect: correct,
    volumeTotal: dealt,
  );
}

void main() {
  final now = DateTime(2026, 11, 15, 9);

  test('an empty history has no totals and no best game', () {
    final summary = summarizeStats(const []);
    expect(summary.gamesPlayed, 0);
    expect(summary.questionsAnswered, 0);
    expect(summary.accuracyPercent, 0);
    expect(summary.bestStreak, 0);
    expect(summary.bestGame, isNull);
    expect(summary.byVolume, isEmpty);
    expect(snapshotFromGames(const []).isFirstRun, isTrue);
    expect(snapshotFromGames(const []).bestScorePercent, isNull);
  });

  test('totals, accuracy, streak, and volume rows add across games', () {
    final games = [
      _game(
        score: 8,
        total: 10,
        streak: 4,
        playedAt: DateTime(2026, 11, 9, 8),
        correct: {ScriptureVolume.bom: 8},
        dealt: {ScriptureVolume.bom: 10},
        volumes: const [ScriptureVolume.bom],
      ),
      _game(
        score: 10,
        total: 10,
        streak: 9,
        playedAt: DateTime(2026, 11, 14, 20),
        correct: {ScriptureVolume.ot: 6, ScriptureVolume.nt: 4},
        dealt: {ScriptureVolume.ot: 6, ScriptureVolume.nt: 4},
        volumes: const [ScriptureVolume.nt, ScriptureVolume.ot],
        questionCount: 12,
      ),
    ];

    final summary = summarizeStats(games);
    expect(summary.gamesPlayed, 2);
    expect(summary.questionsAnswered, 20);
    expect(summary.correctAnswers, 18);
    expect(summary.accuracyPercent, 90);
    expect(summary.bestStreak, 9);
    expect(summary.byVolume.map((row) => row.volume), [
      ScriptureVolume.ot,
      ScriptureVolume.nt,
      ScriptureVolume.bom,
    ]);
    expect(summary.byVolume[0].correct, 6);
    expect(summary.byVolume[0].total, 6);
    expect(summary.byVolume[2].correct, 8);
    expect(summary.byVolume[2].total, 10);

    final snapshot = snapshotFromGames(games);
    expect(snapshot.gamesPlayed, 2);
    expect(snapshot.accuracyPercent, 90);
    expect(snapshot.bestStreak, 9);
    expect(snapshot.bestScorePercent, 100);
    expect(snapshot.lastGame?.correct, 10);
    expect(snapshot.lastGame?.total, 10);
    expect(snapshot.lastSettings?.questionCount, 12);
    expect(snapshot.lastSettings?.volumes, [
      ScriptureVolume.nt,
      ScriptureVolume.ot,
    ]);
  });

  test('best game prefers percent, then length, then the later day', () {
    final shortPerfect = _game(
      score: 1,
      total: 1,
      streak: 1,
      playedAt: DateTime(2026, 11),
      correct: {ScriptureVolume.ot: 1},
      dealt: {ScriptureVolume.ot: 1},
    );
    final longPerfect = _game(
      score: 10,
      total: 10,
      streak: 10,
      playedAt: DateTime(2026, 11, 9, 8),
      correct: {ScriptureVolume.bom: 10},
      dealt: {ScriptureVolume.bom: 10},
    );
    final laterPerfect = _game(
      score: 10,
      total: 10,
      streak: 3,
      playedAt: DateTime(2026, 11, 14, 20),
      correct: {ScriptureVolume.dc: 10},
      dealt: {ScriptureVolume.dc: 10},
    );
    final weaker = _game(
      score: 9,
      total: 10,
      streak: 5,
      playedAt: DateTime(2026, 11, 15),
      correct: {ScriptureVolume.nt: 9},
      dealt: {ScriptureVolume.nt: 10},
    );

    expect(
      bestGameOf([shortPerfect, weaker, longPerfect])?.playedAt,
      longPerfect.playedAt,
    );
    expect(
      bestGameOf([longPerfect, laterPerfect])?.playedAt,
      laterPerfect.playedAt,
    );
    expect(bestGameLine(longPerfect, now), '10 / 10 · Book of Mormon · Nov 9');
    expect(
      bestGameLine(laterPerfect, now),
      '10 / 10 · Doctrine and Covenants · Yesterday',
    );
    expect(
      bestGameSemanticsLabel(longPerfect, now),
      'Best game, 10 out of 10, Book of Mormon, Nov 9',
    );
    expect(
      bestGameSemanticsLabel(laterPerfect, now),
      'Best game, 10 out of 10, Doctrine and Covenants, yesterday',
    );
  });

  test('best percent is the highest stored percent', () {
    final low = _game(
      score: 1,
      total: 10,
      streak: 1,
      playedAt: DateTime(2026, 11, 2),
      correct: {ScriptureVolume.ot: 1},
      dealt: {ScriptureVolume.ot: 10},
    );
    final high = _game(
      score: 1,
      total: 1,
      streak: 1,
      playedAt: DateTime(2026, 11, 3),
      correct: {ScriptureVolume.nt: 1},
      dealt: {ScriptureVolume.nt: 1},
    );

    expect(bestPercentOf(const []), isNull);
    expect(bestPercentOf([low, high]), 100);
    expect(bestPercentOf([high, low]), 100);
  });

  test('a tied playedAt keeps the later stored game', () {
    final stamp = DateTime(2026, 11, 9, 8);
    final first = _game(
      score: 1,
      total: 2,
      streak: 1,
      playedAt: stamp,
      correct: {ScriptureVolume.ot: 1},
      dealt: {ScriptureVolume.ot: 2},
    );
    final second = _game(
      score: 2,
      total: 2,
      streak: 2,
      playedAt: stamp,
      correct: {ScriptureVolume.nt: 2},
      dealt: {ScriptureVolume.nt: 2},
    );

    expect(identical(mostRecentGame([first, second]), second), isTrue);
    expect(identical(mostRecentGame([second, first]), first), isTrue);
  });

  test('volume names fall back to the picked volumes', () {
    final game = _game(
      score: 1,
      total: 1,
      streak: 1,
      playedAt: DateTime(2026, 11, 9),
      correct: const {},
      dealt: const {},
      volumes: const [ScriptureVolume.nt],
    );

    expect(bestGameLine(game, now), '1 / 1 · New Testament · Nov 9');
    expect(
      bestGameSemanticsLabel(game, now),
      'Best game, 1 out of 1, New Testament, Nov 9',
    );
  });
}
