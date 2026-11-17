import 'package:flutter/foundation.dart';

import '../data/questions/scripture_volume.dart';
import '../game/game_engine.dart';
import '../results/results_summary.dart';

/// One finished game as it is stored on the device.
///
/// [percent] is the whole-number score. [questionCount] is what the player
/// asked for, so Play again can reopen setup with that length. [volumes]
/// keeps the order they picked. Per-volume counts only include volumes that
/// were actually dealt.
@immutable
final class FinishedGameRecord {
  const FinishedGameRecord({
    required this.score,
    required this.total,
    required this.percent,
    required this.bestStreak,
    required this.playedAt,
    required this.volumes,
    required this.questionCount,
    required this.volumeCorrect,
    required this.volumeTotal,
  });

  final int score;
  final int total;
  final int percent;
  final int bestStreak;
  final DateTime playedAt;
  final List<ScriptureVolume> volumes;
  final int questionCount;
  final Map<ScriptureVolume, int> volumeCorrect;
  final Map<ScriptureVolume, int> volumeTotal;

  Map<String, Object> toJson() {
    return {
      'score': score,
      'total': total,
      'percent': percent,
      'bestStreak': bestStreak,
      'playedAt': playedAt.toIso8601String(),
      'volumes': [for (final volume in volumes) volume.code],
      'questionCount': questionCount,
      'byVolume': {
        for (final volume in ScriptureVolume.values)
          if ((volumeTotal[volume] ?? 0) > 0)
            volume.code: {
              'correct': volumeCorrect[volume] ?? 0,
              'total': volumeTotal[volume] ?? 0,
            },
      },
    };
  }

  /// Null when [json] is not a finished game we can show.
  static FinishedGameRecord? tryParse(Object? json) {
    if (json is! Map) return null;
    final total = _int(json['total']);
    final score = _int(json['score']);
    if (total == null || score == null || total <= 0 || score < 0) return null;
    if (score > total) return null;
    final playedAt = json['playedAt'];
    if (playedAt is! String) return null;
    final DateTime when;
    try {
      when = DateTime.parse(playedAt);
    } on FormatException {
      return null;
    }
    final questionCount = _int(json['questionCount']);
    final count = questionCount == null || questionCount <= 0
        ? total
        : questionCount;
    final volumes = <ScriptureVolume>[];
    final rawVolumes = json['volumes'];
    if (rawVolumes is List) {
      for (final code in rawVolumes) {
        if (code is! String) continue;
        final volume = ScriptureVolume.tryParse(code);
        if (volume != null && !volumes.contains(volume)) volumes.add(volume);
      }
    }
    final correct = <ScriptureVolume, int>{};
    final dealt = <ScriptureVolume, int>{};
    final byVolume = json['byVolume'];
    if (byVolume is Map) {
      for (final volume in ScriptureVolume.values) {
        final row = byVolume[volume.code];
        if (row is! Map) continue;
        final rowTotal = _int(row['total']);
        final rowCorrect = _int(row['correct']);
        if (rowTotal == null || rowCorrect == null || rowTotal <= 0) continue;
        if (rowCorrect < 0 || rowCorrect > rowTotal) continue;
        dealt[volume] = rowTotal;
        correct[volume] = rowCorrect;
      }
    }
    var streak = _int(json['bestStreak']) ?? 0;
    if (streak < 0) streak = 0;
    if (streak > total) streak = total;
    return FinishedGameRecord(
      score: score,
      total: total,
      percent: scorePercent(score, total),
      bestStreak: streak,
      playedAt: when,
      volumes: volumes,
      questionCount: count,
      volumeCorrect: correct,
      volumeTotal: dealt,
    );
  }
}

int? _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}

/// The stored shape of a finished [session].
FinishedGameRecord finishedGameFromSession(
  GameSession session, {
  required DateTime playedAt,
}) {
  final rows = breakdownByVolume(session);
  final requested = session.requestedCount;
  final count = requested > 0 ? requested : session.questionCount;
  return FinishedGameRecord(
    score: session.score,
    total: session.questionCount,
    percent: scorePercent(session.score, session.questionCount),
    bestStreak: session.bestStreak,
    playedAt: playedAt,
    volumes: session.volumes,
    questionCount: count,
    volumeCorrect: {for (final row in rows) row.volume: row.correct},
    volumeTotal: {for (final row in rows) row.volume: row.total},
  );
}
