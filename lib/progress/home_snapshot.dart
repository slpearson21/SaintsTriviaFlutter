import 'package:flutter/foundation.dart';

import '../data/questions/scripture_volume.dart';

/// Volumes and question count from the last finished game.
///
/// Home prints this on Play again. STRIV-16 persists it. The list order
/// is whatever the player picked; the Play again line reorders volumes
/// to OT, NT, BOM, DC, PGP.
@immutable
final class LastGameSettings {
  const LastGameSettings({required this.volumes, required this.questionCount})
    : assert(questionCount > 0, 'A game has at least one question.');

  final List<ScriptureVolume> volumes;
  final int questionCount;

  @override
  bool operator ==(Object other) {
    return other is LastGameSettings &&
        questionCount == other.questionCount &&
        listEquals(volumes, other.volumes);
  }

  @override
  int get hashCode => Object.hash(Object.hashAll(volumes), questionCount);
}

/// Score of the last finished game.
@immutable
final class LastGameSummary {
  const LastGameSummary({
    required this.correct,
    required this.total,
    required this.playedAt,
  }) : assert(total > 0, 'A finished game has at least one question.'),
       assert(correct >= 0 && correct <= total);

  final int correct;
  final int total;
  final DateTime playedAt;

  @override
  bool operator ==(Object other) {
    return other is LastGameSummary &&
        correct == other.correct &&
        total == other.total &&
        playedAt == other.playedAt;
  }

  @override
  int get hashCode => Object.hash(correct, total, playedAt);
}

/// What Home renders. [gamesPlayed] of 0 is the first-run screen.
///
/// STRIV-16 owns on-device storage. It should publish this same value
/// from [homeSnapshotProvider], including [HomeSnapshot.firstRun] after
/// reset stats. Home does not read shared_preferences itself.
@immutable
final class HomeSnapshot {
  const HomeSnapshot({
    required this.gamesPlayed,
    required this.accuracyPercent,
    required this.bestStreak,
    this.lastGame,
    this.lastSettings,
    this.bestScorePercent,
  }) : assert(gamesPlayed >= 0),
       assert(
         accuracyPercent >= 0 && accuracyPercent <= 100,
         'Accuracy is a whole percent from 0 to 100.',
       ),
       assert(bestStreak >= 0),
       assert(
         bestScorePercent == null ||
             (bestScorePercent >= 0 && bestScorePercent <= 100),
         'Best score percent is a whole percent from 0 to 100.',
       );

  const HomeSnapshot.firstRun()
    : gamesPlayed = 0,
      accuracyPercent = 0,
      bestStreak = 0,
      lastGame = null,
      lastSettings = null,
      bestScorePercent = null;

  final int gamesPlayed;

  /// Rounded percent of answers that were correct, from 0 to 100.
  final int accuracyPercent;
  final int bestStreak;
  final LastGameSummary? lastGame;
  final LastGameSettings? lastSettings;

  /// Best finished-game percent already on record, from 0 to 100.
  ///
  /// Null when no finished game is stored. This is the best whole percent
  /// among stored games, including a game that was just recorded. Results
  /// does not compare the game on screen with itself: it uses the best
  /// from before that game, remembered when the game was recorded.
  final int? bestScorePercent;

  bool get isFirstRun => gamesPlayed == 0;
}

const _dot = ' · ';

/// Play again name for [volume].
///
/// Doctrine and Covenants is "D&C" on that compact line. Every other
/// volume uses [ScriptureVolume.label]. This is not a third volume enum.
String playAgainVolumeName(ScriptureVolume volume) {
  return volume == ScriptureVolume.dc ? 'D&C' : volume.label;
}

/// "Book of Mormon · D&C · 10 questions", in standard-works order.
String playAgainSubtitle(LastGameSettings settings) {
  final names = [
    for (final volume in ScriptureVolume.values)
      if (settings.volumes.contains(volume)) playAgainVolumeName(volume),
  ];
  final count = settings.questionCount;
  final questions = count == 1 ? '1 question' : '$count questions';
  if (names.isEmpty) {
    return questions;
  }
  return '${names.join(_dot)}$_dot$questions';
}

/// "Today", "Yesterday", or a short English date.
///
/// The gap is calendar days in the local zone, not elapsed hours. Local
/// midnights are 23 hours apart when the clocks spring forward, so
/// subtracting those [DateTime]s reports yesterday as "Today". Both
/// instants are converted with [DateTime.toLocal] first, so a UTC
/// timestamp from an 11 PM local game still uses that local day. Those
/// local year, month, and day fields are then copied onto UTC dates,
/// which are always 24 hours apart. [DateTime.toUtc] is not used.
///
/// Same calendar year is "Nov 9". A different year is "Nov 9, 2025".
/// A future day uses that short date too. v1 stays English.
String formatLastGameDate(DateTime playedAt, DateTime now) {
  final playedLocal = playedAt.toLocal();
  final nowLocal = now.toLocal();
  final playedDay = DateTime.utc(
    playedLocal.year,
    playedLocal.month,
    playedLocal.day,
  );
  final today = DateTime.utc(nowLocal.year, nowLocal.month, nowLocal.day);
  final dayGap = today.difference(playedDay).inDays;
  if (dayGap == 0) {
    return 'Today';
  }
  if (dayGap == 1) {
    return 'Yesterday';
  }
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final monthDay = '${months[playedLocal.month - 1]} ${playedLocal.day}';
  if (playedLocal.year == nowLocal.year) {
    return monthDay;
  }
  return '$monthDay, ${playedLocal.year}';
}

/// Spoken Play again label. Full volume names, no middle dots.
String playAgainSemanticsLabel(LastGameSettings settings) {
  final names = [
    for (final volume in ScriptureVolume.values)
      if (settings.volumes.contains(volume)) volume.label,
  ];
  final count = settings.questionCount;
  final questions = count == 1 ? '1 question' : '$count questions';
  if (names.isEmpty) {
    return 'Play again, $questions';
  }
  return 'Play again, ${names.join(', ')}, $questions';
}

/// Spoken last-game line. "8 / 10 · Yesterday" is read as
/// "8 out of 10, yesterday".
String lastGameSemanticsLabel(LastGameSummary game, DateTime now) {
  final date = formatLastGameDate(game.playedAt, now);
  final spokenDate = switch (date) {
    'Today' => 'today',
    'Yesterday' => 'yesterday',
    _ => date,
  }
  return 'Last game: ${game.correct} out of ${game.total}, $spokenDate';
}

/// "Last game: 8 / 10 · Yesterday".
String lastGameLine(LastGameSummary game, DateTime now) {
  final date = formatLastGameDate(game.playedAt, now);
  return 'Last game: ${game.correct} / ${game.total}$_dot$date';
}
