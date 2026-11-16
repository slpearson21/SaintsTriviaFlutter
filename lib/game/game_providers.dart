import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/questions/question_bank.dart';
import '../data/questions/scripture_volume.dart';
import 'game_engine.dart';

/// Source of randomness for a deal.
///
/// Tests override this with a seeded [Random]. Production uses [Random.new],
/// which seeds itself.
final gameRandomProvider = Provider<Random>((ref) => Random());

/// The game in progress, or null when nothing has been dealt.
///
/// Holds the selected volumes, the requested count, the dealt questions,
/// the current index, the answers, the score, and both streaks.
final gameControllerProvider = NotifierProvider<GameController, GameSession?>(
  GameController.new,
);

class GameController extends Notifier<GameSession?> {
  @override
  GameSession? build() => null;

  /// Deals a new game. Replaces whatever session was in progress.
  void start({
    required QuestionBank bank,
    required List<ScriptureVolume> volumes,
    required int requestedCount,
  }) {
    state = startGame(
      bank: bank,
      volumes: volumes,
      requestedCount: requestedCount,
      random: ref.read(gameRandomProvider),
    );
  }

  /// Scores [selectedIndex] against the current question.
  ///
  /// Does nothing when no game has been started.
  void answer(int selectedIndex) {
    final current = state;
    if (current == null) return;
    state = applyAnswer(current, selectedIndex);
  }
}
