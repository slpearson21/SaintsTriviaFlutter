import '../progress/home_snapshot.dart';

/// Settings for the game route.
///
/// [extra] is go_router's `state.extra`. It is only a [LastGameSettings]
/// when the caller passed one. A restore or a deep link leaves it null,
/// and then the last finished game on [snapshot] is the fallback. Anything
/// else is ignored rather than cast.
LastGameSettings? gameSettingsFromRoute(Object? extra, HomeSnapshot snapshot) {
  // `is` promotes [extra]. A blind cast of go_router's extra throws on a
  // restore, a deep link, or any other payload.
  final LastGameSettings? fromRoute = extra is LastGameSettings ? extra : null;
  return fromRoute ?? snapshot.lastSettings;
}
