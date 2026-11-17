import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:saints_trivia_flutter/data/questions/scripture_volume.dart';
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
      final encoded =
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

  test('the memory repository is the fake tests can share', () {
    final repo = MemoryProgressRepository(games: [game], settings: settings);
    expect(repo.readGames().single.score, 8);
    expect(repo.readSettings().soundEffects, isTrue);
    repo.writeGames(const []);
    expect(repo.readGames(), isEmpty);
    expect(repo.readSettings(), settings);
  });
}
