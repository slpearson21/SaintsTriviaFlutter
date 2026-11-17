import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/game_engine.dart';
import 'home_providers.dart';

/// Writes one finished game to the device.
///
/// The body does not touch shared_preferences. [HomeSnapshotController]
/// owns the repository, and [finishedGameRecorderProvider] drops a second
/// call for the same [GameSession] instance.
typedef RecordFinishedGame = void Function(GameSession session);

/// Persists [session] through [homeSnapshotProvider].
final recordFinishedGameProvider = Provider<RecordFinishedGame>((ref) {
  return (GameSession session) {
    ref.read(homeSnapshotProvider.notifier).recordFinishedGame(session);
  };
});

/// Calls [recordFinishedGameProvider] once per session object.
///
/// A rebuild of Results, and a later visit to the same finished game,
/// does not record again. A new deal is a new [GameSession], so the next
/// finished game is recorded on its own.
final finishedGameRecorderProvider = Provider<RecordFinishedGame>((ref) {
  final record = ref.watch(recordFinishedGameProvider);
  GameSession? recorded;
  return (GameSession session) {
    if (identical(recorded, session)) return;
    recorded = session;
    record(session);
  };
});
