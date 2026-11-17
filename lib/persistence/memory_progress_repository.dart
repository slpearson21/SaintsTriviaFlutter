import 'app_settings.dart';
import 'finished_game_record.dart';
import 'progress_repository.dart';

/// In-memory stand-in. Each provider container gets its own.
///
/// Production replaces this in `main` with the shared_preferences repository.
/// Widget tests that do not care about a restart keep this default.
final class MemoryProgressRepository implements ProgressRepository {
  MemoryProgressRepository({
    List<FinishedGameRecord>? games,
    AppSettings? settings,
  }) : _games = games == null ? <FinishedGameRecord>[] : [...games],
       _settings = settings ?? AppSettings.defaults;

  List<FinishedGameRecord> _games;
  AppSettings _settings;

  @override
  List<FinishedGameRecord> readGames() => List.unmodifiable(_games);

  @override
  void writeGames(List<FinishedGameRecord> games) {
    _games = [...games];
  }

  @override
  AppSettings readSettings() => _settings;

  @override
  void writeSettings(AppSettings settings) {
    _settings = settings;
  }
}
