import 'app_settings.dart';
import 'finished_game_record.dart';

/// On-device games and settings.
///
/// Reads are synchronous so Home can render on the first frame. The
/// shared_preferences implementation caches them. Tests pass a
/// [MemoryProgressRepository] or a repository wrapped around
/// `SharedPreferences.setMockInitialValues`.
abstract interface class ProgressRepository {
  List<FinishedGameRecord> readGames();

  void writeGames(List<FinishedGameRecord> games);

  AppSettings readSettings();

  void writeSettings(AppSettings settings);
}
