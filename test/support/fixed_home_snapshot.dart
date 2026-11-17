import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:saints_trivia_flutter/game/game_engine.dart';
import 'package:saints_trivia_flutter/progress/home_providers.dart';
import 'package:saints_trivia_flutter/progress/home_snapshot.dart';

/// Pins [homeSnapshotProvider] to [snapshot].
///
/// Recording and reset are no-ops, so a test that passes a snapshot is not
/// overwritten when Results asks the controller to persist the game.
Override fixedHomeSnapshot(HomeSnapshot snapshot) {
  return homeSnapshotProvider.overrideWith(() => FixedHomeSnapshot(snapshot));
}

class FixedHomeSnapshot extends HomeSnapshotController {
  FixedHomeSnapshot(this.snapshot);

  final HomeSnapshot snapshot;

  @override
  HomeSnapshot build() => snapshot;

  @override
  void recordFinishedGame(GameSession session) {}

  @override
  void resetStats() {}
}
