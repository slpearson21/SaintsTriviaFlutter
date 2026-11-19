import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
// The in-memory store is the test double SharedPreferences.setMockInitialValues
// installs. The app does not depend on the platform interface directly.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:saints_trivia_flutter/data/questions/scripture_volume.dart';
import 'package:saints_trivia_flutter/game/game_engine.dart';
import 'package:saints_trivia_flutter/main.dart';
import 'package:saints_trivia_flutter/persistence/app_settings.dart';
import 'package:saints_trivia_flutter/persistence/finished_game_record.dart';
import 'package:saints_trivia_flutter/persistence/memory_progress_repository.dart';
import 'package:saints_trivia_flutter/persistence/shared_preferences_progress_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final game = FinishedGameRecord(
    score: 8,
    total: 10,
    percent: 80,
    bestStreak: 4,
    playedAt: DateTime(2026, 11, 9, 8),
    volumes: const [ScriptureVolume.bom, ScriptureVolume.dc],
    questionCount: 10,
    volumeCorrect: const {ScriptureVolume.bom: 8},
    volumeTotal: const {ScriptureVolume.bom: 10},
  );

  const settings = AppSettings(
    themeMode: ThemeMode.dark,
    soundEffects: true,
    haptics: false,
    showExplanations: false,
  );

  group('shared preferences repository', () {
    test('round-trips games and settings', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPreferencesProgressRepository(prefs);

      expect(repo.readGames(), isEmpty);
      expect(repo.readSettings(), AppSettings.defaults);

      repo.writeGames([game]);
      repo.writeSettings(settings);

      final again = SharedPreferencesProgressRepository(prefs);
      expect(again.readGames(), hasLength(1));
      final stored = again.readGames().single;
      expect(stored.score, 8);
      expect(stored.total, 10);
      expect(stored.percent, 80);
      expect(stored.bestStreak, 4);
      expect(stored.playedAt, DateTime(2026, 11, 9, 8));
      expect(stored.volumes, [ScriptureVolume.bom, ScriptureVolume.dc]);
      expect(stored.questionCount, 10);
      expect(stored.volumeCorrect[ScriptureVolume.bom], 8);
      expect(stored.volumeTotal[ScriptureVolume.bom], 10);
      expect(again.readSettings(), settings);
      expect(
        prefs.getString(SharedPreferencesProgressRepository.gamesKey),
        isNotNull,
      );
      expect(
        prefs.getString(SharedPreferencesProgressRepository.settingsKey),
        isNotNull,
      );
    });

    test('clearing games leaves settings in place', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPreferencesProgressRepository(prefs);
      repo.writeGames([game]);
      repo.writeSettings(settings);

      repo.writeGames(const []);

      expect(repo.readGames(), isEmpty);
      expect(repo.readSettings(), settings);
    });

    test('a corrupt record is dropped and settings fall back', () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesProgressRepository.gamesKey:
            '[{"score": 1, "total": 0}, "nope", {"not": "a game"}]',
        SharedPreferencesProgressRepository.settingsKey: '{not json',
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPreferencesProgressRepository(prefs);

      expect(repo.readGames(), isEmpty);
      expect(repo.readSettings(), AppSettings.defaults);
    });

    test('a partial settings object keeps the other defaults', () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesProgressRepository.settingsKey:
            '{"soundEffects": true, "themeMode": "nope"}',
      });
      final prefs = await SharedPreferences.getInstance();
      final settings = SharedPreferencesProgressRepository(prefs)
          .readSettings();

      expect(settings.soundEffects, isTrue);
      expect(settings.themeMode, ThemeMode.system);
      expect(settings.haptics, isTrue);
      expect(settings.showExplanations, isTrue);
    });

    test('setMockInitialValues seeds a later read', () async {
      const encoded =
          '[{"score":10,"total":10,"percent":100,"bestStreak":10,'
          '"playedAt":"2026-11-09T08:00:00.000","volumes":["BOM"],'
          '"questionCount":10,"byVolume":{"BOM":{"correct":10,"total":10}}}]';
      SharedPreferences.setMockInitialValues({
        SharedPreferencesProgressRepository.gamesKey: encoded,
      });
      final prefs = await SharedPreferences.getInstance();
      final stored = SharedPreferencesProgressRepository(prefs).readGames();

      expect(stored, hasLength(1));
      expect(stored.single.percent, 100);
      expect(stored.single.volumeTotal[ScriptureVolume.bom], 10);
    });
  });

  test('a prefs failure boots with an empty memory store', () async {
    final printed = <String>[];
    final previous = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      printed.add(message ?? '');
    };
    addTearDown(() => debugPrint = previous);

    final failed = await progressRepositoryForLaunch(
      loadPrefs: () async => throw StateError('corrupt store'),
    );
    expect(failed, isA<MemoryProgressRepository>());
    expect(failed.readGames(), isEmpty);
    expect(failed.readSettings(), AppSettings.defaults);
    expect(printed.single, contains('corrupt store'));

    SharedPreferences.setMockInitialValues({});
    final loaded = await progressRepositoryForLaunch(
      loadPrefs: SharedPreferences.getInstance,
    );
    expect(loaded, isA<SharedPreferencesProgressRepository>());
  });

  test('an empty volume list falls back to the dealt volumes', () {
    final game = FinishedGameRecord.tryParse({
      'score': 8,
      'total': 10,
      'playedAt': '2026-11-09T08:00:00.000',
      'byVolume': {
        'NT': {'correct': 3, 'total': 4},
        'OT': {'correct': 5, 'total': 6},
      },
    });
    expect(game, isNotNull);
    expect(game!.volumes, [ScriptureVolume.ot, ScriptureVolume.nt]);
  });

  test('a record with no volumes is dropped', () {
    expect(
      FinishedGameRecord.tryParse({
        'score': 1,
        'total': 1,
        'playedAt': '2026-11-09T08:00:00.000',
      }),
      isNull,
    );
  });

  test('broken game JSON and a non-list are dropped', () async {
    SharedPreferences.setMockInitialValues({
      SharedPreferencesProgressRepository.gamesKey: '{not json',
    });
    final broken = await SharedPreferences.getInstance();
    expect(SharedPreferencesProgressRepository(broken).readGames(), isEmpty);

    for (final raw in ['{"score": 1}', '"games"', '12', 'null']) {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesProgressRepository.gamesKey: raw,
      });
      final prefs = await SharedPreferences.getInstance();
      expect(
        SharedPreferencesProgressRepository(prefs).readGames(),
        isEmpty,
        reason: raw,
      );
    }
  });

  test('a failed save is logged and does not throw', () async {
    final printed = <String>[];
    final previous = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      printed.add(message ?? '');
    };
    addTearDown(() => debugPrint = previous);
    addTearDown(() {
      SharedPreferences.resetStatic();
      SharedPreferences.setMockInitialValues({});
    });

    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = _FailingPrefsStore();
    final prefs = await SharedPreferences.getInstance();
    final repo = SharedPreferencesProgressRepository(prefs);

    repo.writeGames([game]);
    repo.writeSettings(settings);
    await pumpEventQueue();

    final log = printed.join('\n');
    expect(
      log,
      contains(
        'Could not save ${SharedPreferencesProgressRepository.gamesKey}',
      ),
    );
    expect(
      log,
      contains(
        'Could not save ${SharedPreferencesProgressRepository.settingsKey}',
      ),
    );
    expect(log, contains('disk full'));
    // SharedPreferences updates its cache before the platform write, so a
    // failed save is still what the next read in this process returns.
    expect(repo.readGames(), hasLength(1));
    expect(repo.readSettings(), settings);
  });

  test('an unreadable playedAt is dropped', () {
    for (final playedAt in ['not-a-date', '', 20261109]) {
      expect(
        FinishedGameRecord.tryParse({
          'score': 1,
          'total': 1,
          'playedAt': playedAt,
          'volumes': ['OT'],
        }),
        isNull,
        reason: '$playedAt',
      );
    }
  });

  test('a score above the total or below zero is dropped', () {
    expect(_parse(score: 11, total: 10), isNull);
    expect(_parse(score: -1, total: 10), isNull);
    expect(_parse(score: 0, total: 0), isNull);
  });

  test('best streak is clamped into 0 through total', () {
    expect(_parse(bestStreak: 20)!.bestStreak, 10);
    expect(_parse(bestStreak: -4)!.bestStreak, 0);
    expect(_parse()!.bestStreak, 0);
  });

  test('a missing or zero questionCount falls back to the total', () {
    expect(_parse()!.questionCount, 10);
    expect(_parse(questionCount: 0)!.questionCount, 10);
    expect(_parse(questionCount: 12)!.questionCount, 12);
  });

  test('repeated and unknown volume codes are skipped', () {
    final parsed = FinishedGameRecord.tryParse({
      'score': 8,
      'total': 10,
      'playedAt': '2026-11-09T08:00:00.000',
      'volumes': ['OT', 'OT', 'NOPE', 3, 'NT'],
    });

    expect(parsed, isNotNull);
    expect(parsed!.volumes, [ScriptureVolume.ot, ScriptureVolume.nt]);
  });

  test('a volume row with more correct than dealt is skipped', () {
    final parsed = FinishedGameRecord.tryParse({
      'score': 1,
      'total': 3,
      'playedAt': '2026-11-09T08:00:00.000',
      'volumes': ['OT', 'NT'],
      'byVolume': {
        'OT': {'correct': 6, 'total': 4},
        'NT': {'correct': 1, 'total': 2},
      },
    });

    expect(parsed, isNotNull);
    expect(parsed!.volumeTotal.containsKey(ScriptureVolume.ot), isFalse);
    expect(parsed.volumeCorrect.containsKey(ScriptureVolume.ot), isFalse);
    expect(parsed.volumeTotal[ScriptureVolume.nt], 2);
    expect(parsed.volumeCorrect[ScriptureVolume.nt], 1);
  });

  test('decimal numbers are truncated toward zero', () {
    final parsed = FinishedGameRecord.tryParse({
      'score': 8.9,
      'total': 10.2,
      'bestStreak': 4.8,
      'playedAt': '2026-11-09T08:00:00.000',
      'volumes': ['OT'],
      'questionCount': 10.7,
      'percent': 1,
      'byVolume': {
        'OT': {'correct': 1.9, 'total': 2.2},
      },
    });

    expect(parsed, isNotNull);
    expect(parsed!.score, 8);
    expect(parsed.total, 10);
    expect(parsed.percent, 80);
    expect(parsed.bestStreak, 4);
    expect(parsed.questionCount, 10);
    expect(parsed.volumeCorrect[ScriptureVolume.ot], 1);
    expect(parsed.volumeTotal[ScriptureVolume.ot], 2);

    final disguised = FinishedGameRecord.tryParse({
      'score': 10.9,
      'total': 10.1,
      'playedAt': '2026-11-09T08:00:00.000',
      'volumes': ['OT'],
    });
    expect(disguised, isNotNull);
    expect(disguised!.score, 10);
    expect(disguised.total, 10);
    expect(disguised.percent, 100);
  });

  test('finishedGameFromSession stores the deal and the requested count', () {
    final questions = [
      GameQuestion(
        id: 'ot-0001',
        volume: ScriptureVolume.ot,
        reference: 'Genesis 1:1',
        prompt: 'One',
        options: const ['A', 'B', 'C', 'D'],
        answerIndex: 0,
        explanation: 'Because.',
      ),
      GameQuestion(
        id: 'nt-0001',
        volume: ScriptureVolume.nt,
        reference: 'John 1:1',
        prompt: 'Two',
        options: const ['A', 'B', 'C', 'D'],
        answerIndex: 1,
        explanation: 'Because.',
      ),
    ];
    final when = DateTime.utc(2026, 11, 9, 8);
    final record = finishedGameFromSession(
      GameSession(
        volumes: const [ScriptureVolume.nt, ScriptureVolume.ot],
        requestedCount: 12,
        questions: questions,
        currentIndex: 2,
        answers: const [
          GameAnswer(questionId: 'ot-0001', selectedIndex: 0, correct: true),
          GameAnswer(questionId: 'nt-0001', selectedIndex: 0, correct: false),
        ],
        score: 1,
        currentStreak: 0,
        bestStreak: 1,
      ),
      playedAt: when,
    );

    expect(record.score, 1);
    expect(record.total, 2);
    expect(record.percent, 50);
    expect(record.bestStreak, 1);
    expect(record.playedAt, when);
    expect(record.volumes, [ScriptureVolume.nt, ScriptureVolume.ot]);
    expect(record.questionCount, 12);
    expect(record.volumeCorrect[ScriptureVolume.ot], 1);
    expect(record.volumeTotal[ScriptureVolume.ot], 1);
    expect(record.volumeCorrect[ScriptureVolume.nt], 0);
    expect(record.volumeTotal[ScriptureVolume.nt], 1);

    final fallback = finishedGameFromSession(
      GameSession(
        volumes: const [ScriptureVolume.ot],
        requestedCount: 0,
        questions: [questions.first],
        currentIndex: 1,
        answers: const [
          GameAnswer(questionId: 'ot-0001', selectedIndex: 0, correct: true),
        ],
        score: 1,
        currentStreak: 1,
        bestStreak: 1,
      ),
      playedAt: when,
    );
    expect(fallback.questionCount, 1);
  });

  test('settings that are not a map fall back to defaults', () async {
    for (final raw in ['[]', '"dark"', '1', 'null']) {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesProgressRepository.settingsKey: raw,
      });
      final prefs = await SharedPreferences.getInstance();
      expect(
        SharedPreferencesProgressRepository(prefs).readSettings(),
        AppSettings.defaults,
        reason: raw,
      );
    }
  });

  test('wrong-typed settings fields keep that field default', () async {
    SharedPreferences.setMockInitialValues({
      SharedPreferencesProgressRepository.settingsKey: '{"themeMode": 1, "soundEffects": "true", "haptics": 0, "showExplanations": null}',
    });
    final prefs = await SharedPreferences.getInstance();
    final stored = SharedPreferencesProgressRepository(prefs).readSettings();

    expect(stored.themeMode, ThemeMode.system);
    expect(stored.soundEffects, isFalse);
    expect(stored.haptics, isTrue);
    expect(stored.showExplanations, isTrue);
  });

  test('the memory repository is the fake tests can share', () {
    final repo = MemoryProgressRepository(games: [game], settings: settings);
    expect(repo.readGames().single.score, 8);
    expect(repo.readSettings().soundEffects, isTrue);
    repo.writeGames(const []);
    expect(repo.readGames(), isEmpty);
    expect(repo.readSettings(), settings);
  });
}

FinishedGameRecord? _parse({
  Object? score = 8,
  Object? total = 10,
  Object? bestStreak,
  Object? questionCount,
}) {
  return FinishedGameRecord.tryParse({
    'score': score,
    'total': total,
    'playedAt': '2026-11-09T08:00:00.000',
    'volumes': ['OT'],
    'bestStreak': ?bestStreak,
    'questionCount': ?questionCount,
  });
}

final class _FailingPrefsStore extends InMemorySharedPreferencesStore {
  _FailingPrefsStore() : super.empty();

  @override
  Future<bool> setValue(String valueType, String key, Object value) {
    return Future<bool>.error(StateError('disk full'));
  }
}
