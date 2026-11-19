import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/game_engine.dart';
import '../persistence/finished_game_record.dart';
import '../persistence/persistence_providers.dart';
import 'home_snapshot.dart';
import 'stats_summary.dart';

/// Clock Home uses for "Today", "Yesterday", and short dates.
///
/// Tests override this. Finished games are stamped with it too.
typedef HomeClock = DateTime Function();

final homeClockProvider = Provider<HomeClock>((ref) => DateTime.now);

/// What Home renders, loaded from the progress repository.
///
/// Recording a game and resetting stats both publish a new value, so Home
/// updates without reading shared_preferences itself. [HomeSnapshot.firstRun]
/// is what reset stats publishes.
final homeSnapshotProvider =
    NotifierProvider<HomeSnapshotController, HomeSnapshot>(
      HomeSnapshotController.new,
    );

class HomeSnapshotController extends Notifier<HomeSnapshot> {
  @override
  HomeSnapshot build() {
    return snapshotFromGames(ref.read(progressRepositoryProvider).readGames());
  }

  /// Appends [session] and publishes the new snapshot.
  ///
  /// [HomeSnapshot.bestScorePercent] becomes the best whole percent on
  /// record, including this game. The best from before this game is
  /// remembered on [recordedBestProvider] so Results can compare against
  /// that earlier number. The first game remembers null, which is not a
  /// personal best.
  void recordFinishedGame(GameSession session) {
    final repo = ref.read(progressRepositoryProvider);
    final games = [...repo.readGames()];
    final before = bestPercentOf(games);
    games.add(
      finishedGameFromSession(session, playedAt: ref.read(homeClockProvider)()),
    );
    repo.writeGames(games);
    ref.read(recordedBestProvider.notifier).remember(session, before);
    state = snapshotFromGames(games);
  }

  /// Drops every finished game. Settings are left where they are.
  void resetStats() {
    ref.read(progressRepositoryProvider).writeGames(const []);
    ref.read(recordedBestProvider.notifier).clear();
    state = const HomeSnapshot.firstRun();
  }
}

/// The best percent from before a game that has just been recorded.
///
/// [session] is the [GameSession] instance Results is showing.
/// [previousBestPercent] is null for the first game. A later visit to the
/// same session still sees this, so the personal-best chip does not
/// disappear after the game is included in [HomeSnapshot.bestScorePercent].
@immutable
final class RecordedBest {
  const RecordedBest({this.session, this.previousBestPercent});

  final GameSession? session;
  final int? previousBestPercent;

  static const none = RecordedBest();
}

class RecordedBestController extends Notifier<RecordedBest> {
  @override
  RecordedBest build() => RecordedBest.none;

  void remember(GameSession session, int? previousBestPercent) {
    state = RecordedBest(
      session: session,
      previousBestPercent: previousBestPercent,
    );
  }

  void clear() => state = RecordedBest.none;
}

final recordedBestProvider =
    NotifierProvider<RecordedBestController, RecordedBest>(
      RecordedBestController.new,
    );

/// Stored games. Rebuilds when the home snapshot changes, which is how a
/// record and a reset reach the stats screen.
final finishedGamesProvider = Provider<List<FinishedGameRecord>>((ref) {
  ref.watch(homeSnapshotProvider);
  return ref.watch(progressRepositoryProvider).readGames();
});

final statsSummaryProvider = Provider<StatsSummary>((ref) {
  return summarizeStats(ref.watch(finishedGamesProvider));
});
