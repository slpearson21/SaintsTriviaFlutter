import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_settings.dart';
import 'finished_game_record.dart';
import 'progress_repository.dart';

/// [ProgressRepository] backed by [SharedPreferences].
///
/// A corrupt or partial record is dropped. Settings fall back field by field
/// so one bad value does not reset the rest. [writeGames] does not touch
/// settings, and [writeSettings] does not touch games.
final class SharedPreferencesProgressRepository implements ProgressRepository {
  SharedPreferencesProgressRepository(this._prefs);

  final SharedPreferences _prefs;

  static const gamesKey = 'st.finishedGames.v1';
  static const settingsKey = 'st.settings.v1';

  @override
  List<FinishedGameRecord> readGames() {
    final raw = _prefs.getString(gamesKey);
    if (raw == null || raw.isEmpty) return const [];
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return const [];
    }
    if (decoded is! List) return const [];
    final games = <FinishedGameRecord>[];
    for (final item in decoded) {
      final game = FinishedGameRecord.tryParse(item);
      if (game != null) games.add(game);
    }
    return List.unmodifiable(games);
  }

  @override
  void writeGames(List<FinishedGameRecord> games) {
    final encoded = jsonEncode([for (final game in games) game.toJson()]);
    _write(gamesKey, encoded);
  }

  @override
  AppSettings readSettings() {
    final raw = _prefs.getString(settingsKey);
    if (raw == null || raw.isEmpty) return AppSettings.defaults;
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return AppSettings.defaults;
    }
    return AppSettings.fromJson(decoded);
  }

  @override
  void writeSettings(AppSettings settings) {
    _write(settingsKey, jsonEncode(settings.toJson()));
  }

  void _write(String key, String value) {
    unawaited(
      _prefs.setString(key, value).catchError((Object error, StackTrace stack) {
        debugPrint('Could not save $key: $error\n$stack');
        return false;
      }),
    );
  }
}
