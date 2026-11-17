import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'app_settings.dart';
import 'memory_progress_repository.dart';
import 'progress_repository.dart';

/// Games and settings for this process.
///
/// The default keeps them in memory so a test that never overrides this
/// still boots. `main` overrides it with shared_preferences after
/// `SharedPreferences.getInstance`. A test that wants a restart uses the
/// same override with `SharedPreferences.setMockInitialValues`.
final progressRepositoryProvider = Provider<ProgressRepository>(
  (ref) => MemoryProgressRepository(),
);

/// Appearance, sound, haptics, and explanations.
final settingsProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.read(progressRepositoryProvider).readSettings();

  void setThemeMode(ThemeMode mode) => _save(state.copyWith(themeMode: mode));

  void setSoundEffects(bool enabled) =>
      _save(state.copyWith(soundEffects: enabled));

  void setHaptics(bool enabled) => _save(state.copyWith(haptics: enabled));

  void setShowExplanations(bool enabled) =>
      _save(state.copyWith(showExplanations: enabled));

  void _save(AppSettings next) {
    state = next;
    ref.read(progressRepositoryProvider).writeSettings(next);
  }
}
