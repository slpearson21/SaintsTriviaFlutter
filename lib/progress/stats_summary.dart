import '../data/questions/scripture_volume.dart';
import '../persistence/finished_game_record.dart';
import '../results/results_summary.dart';
import 'home_snapshot.dart';

/// Correct and total for one volume across every stored game.
final class VolumeAccuracy {
  const VolumeAccuracy({
    required this.volume,
    required this.correct,
    required this.total,
  });

  final ScriptureVolume volume;
  final int correct;
  final int total;
}

/// Totals the stats screen and the home snapshot both read.
final class StatsSummary {
  const StatsSummary({
    required this.gamesPlayed,
    required this.questionsAnswered,
    required this.correctAnswers,
    required this.accuracyPercent,
    required this.bestStreak,
    required this.bestGame,
    required this.byVolume,
  });

  final int gamesPlayed;
  final int questionsAnswered;
  final int correctAnswers;

  /// Whole percent of [correctAnswers] over [questionsAnswered].
  final int accuracyPercent;

  /// Longest streak inside a single game. Streaks do not cross games.
  final int bestStreak;

  /// Highest whole percent. Ties prefer more questions, then the later game.
  final FinishedGameRecord? bestGame;
  final List<VolumeAccuracy> byVolume;

  static const empty = StatsSummary(
    gamesPlayed: 0,
    questionsAnswered: 0,
    correctAnswers: 0,
    accuracyPercent: 0,
    bestStreak: 0,
    bestGame: null,
    byVolume: [],
  );
}

/// Aggregates [games] in stored order. An empty list is [StatsSummary.empty].
StatsSummary summarizeStats(List<FinishedGameRecord> games) {
  if (games.isEmpty) return StatsSummary.empty;
  var questions = 0;
  var correct = 0;
  var streak = 0;
  for (final game in games) {
    questions += game.total;
    correct += game.score;
    if (game.bestStreak > streak) streak = game.bestStreak;
  }
  return StatsSummary(
    gamesPlayed: games.length,
    questionsAnswered: questions,
    correctAnswers: correct,
    accuracyPercent: scorePercent(correct, questions),
    bestStreak: streak,
    bestGame: _bestGame(games),
    byVolume: _byVolume(games),
  );
}

/// Highest percent, then the longer game, then the more recent one.
FinishedGameRecord? bestGameOf(List<FinishedGameRecord> games) {
  if (games.isEmpty) return null;
  return _bestGame(games);
}

/// Best whole percent on record, or null when nothing is stored.
int? bestPercentOf(List<FinishedGameRecord> games) {
  if (games.isEmpty) return null;
  var best = games.first.percent;
  for (final game in games.skip(1)) {
    if (game.percent > best) best = game.percent;
  }
  return best;
}

/// The game with the latest [FinishedGameRecord.playedAt].
///
/// A tie keeps the later entry, which is the one just recorded.
FinishedGameRecord mostRecentGame(List<FinishedGameRecord> games) {
  var latest = games.first;
  for (final game in games.skip(1)) {
    if (!game.playedAt.isBefore(latest.playedAt)) latest = game;
  }
  return latest;
}

/// Home's snapshot from stored games.
///
/// [HomeSnapshot.bestScorePercent] is the best whole percent on record,
/// including every stored game. Null only when [games] is empty. Results
/// does not use this to decide a personal best for the game on screen; that
/// comparison uses the best from before that game was recorded.
HomeSnapshot snapshotFromGames(List<FinishedGameRecord> games) {
  if (games.isEmpty) return const HomeSnapshot.firstRun();
  final summary = summarizeStats(games);
  final last = mostRecentGame(games);
  return HomeSnapshot(
    gamesPlayed: summary.gamesPlayed,
    accuracyPercent: summary.accuracyPercent,
    bestStreak: summary.bestStreak,
    lastGame: LastGameSummary(
      correct: last.score,
      total: last.total,
      playedAt: last.playedAt,
    ),
    lastSettings: LastGameSettings(
      volumes: last.volumes,
      questionCount: last.questionCount,
    ),
    bestScorePercent: summary.bestGame!.percent,
  );
}

const _dot = ' · ';

/// "10 / 10 · Book of Mormon · Nov 9".
///
/// Volumes that were dealt, in standard-works order. The date uses
/// [formatLastGameDate].
String bestGameLine(FinishedGameRecord game, DateTime now) {
  final names = _playedNames(game);
  final score = '${game.score} / ${game.total}';
  final date = formatLastGameDate(game.playedAt, now);
  if (names.isEmpty) return '$score$_dot$date';
  return '$score$_dot${names.join(_dot)}$_dot$date';
}

/// Spoken best-game line. Full volume names, no middle dots.
String bestGameSemanticsLabel(FinishedGameRecord game, DateTime now) {
  final names = _playedNames(game);
  final date = formatLastGameDate(game.playedAt, now);
  final spokenDate = switch (date) {
    'Today' => 'today',
    'Yesterday' => 'yesterday',
    _ => date,
  };
  final score = '${game.score} out of ${game.total}';
  if (names.isEmpty) return 'Best game, $score, $spokenDate';
  return 'Best game, $score, ${names.join(', ')}, $spokenDate';
}

List<String> _playedNames(FinishedGameRecord game) {
  final dealt = [
    for (final volume in ScriptureVolume.values)
      if ((game.volumeTotal[volume] ?? 0) > 0) volume.label,
  ];
  if (dealt.isNotEmpty) return dealt;
  return [for (final volume in game.volumes) volume.label];
}

FinishedGameRecord _bestGame(List<FinishedGameRecord> games) {
  var best = games.first;
  for (final game in games.skip(1)) {
    final percent = game.percent.compareTo(best.percent);
    if (percent > 0) {
      best = game;
      continue;
    }
    if (percent < 0) continue;
    final length = game.total.compareTo(best.total);
    if (length > 0) {
      best = game;
      continue;
    }
    if (length < 0) continue;
    if (!game.playedAt.isBefore(best.playedAt)) best = game;
  }
  return best;
}

List<VolumeAccuracy> _byVolume(List<FinishedGameRecord> games) {
  final correct = <ScriptureVolume, int>{};
  final total = <ScriptureVolume, int>{};
  for (final game in games) {
    for (final volume in ScriptureVolume.values) {
      final add = game.volumeTotal[volume] ?? 0;
      if (add <= 0) continue;
      total[volume] = (total[volume] ?? 0) + add;
      correct[volume] =
          (correct[volume] ?? 0) + (game.volumeCorrect[volume] ?? 0);
    }
  }
  return [
    for (final volume in ScriptureVolume.values)
      if ((total[volume] ?? 0) > 0)
        VolumeAccuracy(
          volume: volume,
          correct: correct[volume] ?? 0,
          total: total[volume] ?? 0,
        ),
  ];
}
