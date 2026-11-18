import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/questions/question_bank.dart';
import '../data/questions/scripture_volume.dart';
import '../persistence/persistence_providers.dart';
import '../report/reported_questions_provider.dart';
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
    ref.read(reportedQuestionIdsProvider.notifier).clear();
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

  /// Drops the game in progress. Quit uses this so Home does not resume it.
  void discard() {
    state = null;
  }
}

/// Whether answer sounds play.
///
/// Off by default. Settings writes this, and gameplay stays quiet while
/// it is false.
final soundEffectsEnabledProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).soundEffects;
});

/// Whether a correct or wrong answer vibrates.
///
/// On by default. Gameplay reads this before the platform haptic.
final hapticsEnabledProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).haptics;
});

/// Whether the answer sheet shows the one-line explanation.
///
/// On by default. The scripture reference still shows when this is off.
final showExplanationsProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).showExplanations;
});

/// Plays the correct or wrong sound when [enabled] is true.
///
/// No player is wired yet, so this returns without playing. [correct] chooses
/// the clip once STRIV-16 turns [soundEffectsEnabledProvider] on.
void playAnswerSound({required bool enabled, required bool correct}) {
  if (!enabled) return;
  // The cue is selected and then dropped. Playback waits for settings.
  if (correct) return;
  return;
}
