import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saints_trivia_flutter/data/questions/scripture_volume.dart';
import 'package:saints_trivia_flutter/game/game_engine.dart';
import 'package:saints_trivia_flutter/persistence/persistence_providers.dart';
import 'package:saints_trivia_flutter/progress/home_providers.dart';
import 'package:saints_trivia_flutter/progress/home_snapshot.dart';
import 'package:saints_trivia_flutter/results/results_summary.dart';

GameSession _session({required int score, required int total}) {
  final questions = [
    for (var i = 0; i < total; i++)
      GameQuestion(
        id: 'bom-${(i + 1).toString().padLeft(4, '0')}',
        volume: ScriptureVolume.bom,
        reference: '1 Nephi 1:${i + 1}',
        prompt: 'Prompt $i',
        options: const ['A', 'B', 'C', 'D'],
        answerIndex: 0,
        explanation: 'Because.',
      ),
  ];
  return GameSession(
    volumes: const [ScriptureVolume.bom],
    requestedCount: total,
    questions: questions,
    currentIndex: total,
    answers: [
      for (var i = 0; i < total; i++)
        GameAnswer(
          questionId: questions[i].id,
          selectedIndex: i < score ? 0 : 1,
          correct: i < score,
        ),
    ],
    score: score,
    currentStreak: score == total ? total : 0,
    bestStreak: score,
  );
}

void main() {
  test('first game, tie, strictly better, and worse', () {
    const none = HomeSnapshot.firstRun();
    const previous = HomeSnapshot(
      gamesPlayed: 2,
      accuracyPercent: 70,
      bestStreak: 4,
      bestScorePercent: 80,
    );

    expect(isNewPersonalBestPercent(100, none.bestScorePercent), isFalse);
    expect(isNewPersonalBestPercent(50, none.bestScorePercent), isFalse);
    expect(isNewPersonalBestPercent(100, null), isFalse);

    expect(isNewPersonalBestPercent(80, previous.bestScorePercent), isFalse);
    expect(isNewPersonalBestPercent(80, 80), isFalse);

    expect(isNewPersonalBestPercent(81, previous.bestScorePercent), isTrue);
    expect(isNewPersonalBestPercent(81, 80), isTrue);

    expect(isNewPersonalBestPercent(79, previous.bestScorePercent), isFalse);
    expect(isNewPersonalBestPercent(0, 80), isFalse);

    expect(
      showResultsSparkle(percent: 100, personalBest: false, firstGame: true),
      isFalse,
    );
    expect(
      showResultsSparkle(percent: 50, personalBest: false, firstGame: false),
      isFalse,
    );
    expect(
      showResultsSparkle(percent: 90, personalBest: false, firstGame: false),
      isTrue,
    );
    expect(
      showResultsSparkle(percent: 80, personalBest: true, firstGame: false),
      isTrue,
    );
  });

  test('recording compares each game with the best from before it', () {
    var now = DateTime(2026, 11, 9, 8);
    final container = ProviderContainer(
      overrides: [
        homeClockProvider.overrideWith(
          (ref) =>
              () => now,
        ),
      ],
    );
    addTearDown(container.dispose);

    void record(int score, int total) {
      container
          .read(homeSnapshotProvider.notifier)
          .recordFinishedGame(_session(score: score, total: total));
    }

    record(8, 10);
    expect(container.read(recordedBestProvider).previousBestPercent, isNull);
    expect(container.read(homeSnapshotProvider).bestScorePercent, 80);
    expect(container.read(homeSnapshotProvider).gamesPlayed, 1);
    expect(
      isNewPersonalBestPercent(
        80,
        container.read(recordedBestProvider).previousBestPercent,
      ),
      isFalse,
    );

    now = DateTime(2026, 11, 10, 8);
    record(4, 5);
    expect(container.read(recordedBestProvider).previousBestPercent, 80);
    expect(
      isNewPersonalBestPercent(
        80,
        container.read(recordedBestProvider).previousBestPercent,
      ),
      isFalse,
    );
    expect(container.read(homeSnapshotProvider).bestScorePercent, 80);

    now = DateTime(2026, 11, 11, 8);
    record(9, 10);
    expect(container.read(recordedBestProvider).previousBestPercent, 80);
    expect(
      isNewPersonalBestPercent(
        90,
        container.read(recordedBestProvider).previousBestPercent,
      ),
      isTrue,
    );
    expect(container.read(homeSnapshotProvider).bestScorePercent, 90);

    now = DateTime(2026, 11, 12, 8);
    record(5, 10);
    expect(container.read(recordedBestProvider).previousBestPercent, 90);
    expect(
      isNewPersonalBestPercent(
        50,
        container.read(recordedBestProvider).previousBestPercent,
      ),
      isFalse,
    );

    container.read(settingsProvider.notifier).setSoundEffects(true);
    container.read(homeSnapshotProvider.notifier).resetStats();
    expect(container.read(homeSnapshotProvider).isFirstRun, isTrue);
    expect(container.read(homeSnapshotProvider).bestScorePercent, isNull);
    expect(container.read(progressRepositoryProvider).readGames(), isEmpty);
    expect(container.read(settingsProvider).soundEffects, isTrue);
    expect(container.read(recordedBestProvider).session, isNull);
  });
}
