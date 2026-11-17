import 'package:material_ui/material_ui.dart';

/// Preferences that survive a restart. Defaults match the settings mock.
@immutable
final class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.soundEffects = false,
    this.haptics = true,
    this.showExplanations = true,
  });

  final ThemeMode themeMode;

  /// Off until the player turns answer sounds on.
  final bool soundEffects;

  /// Gameplay haptics. On until the player turns them off.
  final bool haptics;

  /// The one-line explanation under an answer. The reference still shows.
  final bool showExplanations;

  static const defaults = AppSettings();

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? soundEffects,
    bool? haptics,
    bool? showExplanations,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      soundEffects: soundEffects ?? this.soundEffects,
      haptics: haptics ?? this.haptics,
      showExplanations: showExplanations ?? this.showExplanations,
    );
  }

  Map<String, Object> toJson() {
    return {
      'themeMode': themeMode.name,
      'soundEffects': soundEffects,
      'haptics': haptics,
      'showExplanations': showExplanations,
    };
  }

  /// Falls back field by field. A bad value keeps that field's default.
  static AppSettings fromJson(Object? json) {
    if (json is! Map) return defaults;
    return AppSettings(
      themeMode: _themeMode(json['themeMode']) ?? ThemeMode.system,
      soundEffects: json['soundEffects'] is bool
          ? json['soundEffects'] as bool
          : false,
      haptics: json['haptics'] is bool ? json['haptics'] as bool : true,
      showExplanations: json['showExplanations'] is bool
          ? json['showExplanations'] as bool
          : true,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AppSettings &&
        themeMode == other.themeMode &&
        soundEffects == other.soundEffects &&
        haptics == other.haptics &&
        showExplanations == other.showExplanations;
  }

  @override
  int get hashCode =>
      Object.hash(themeMode, soundEffects, haptics, showExplanations);
}

ThemeMode? _themeMode(Object? value) {
  if (value is! String) return null;
  for (final mode in ThemeMode.values) {
    if (mode.name == value) return mode;
  }
  return null;
}
