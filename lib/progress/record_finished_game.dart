import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/game_engine.dart';

/// Writes one finished game to the device. STRIV-16 replaces the body.
///
/// The default records nothing. Do not read shared_preferences here.
/// [finishedGameRecorderProvider] is what Results calls, and it drops a
/// second call for the same [GameSession] instance.
typedef RecordFinishedGame = void Function(GameSession session);

/// STRIV-16's persistence hook. The default is a no-op.
final recordFinishedGameProvider = Provider<RecordFinishedGame>(
  (ref) => _recordNothing,
);

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

void _recordNothing(GameSession session) {}
