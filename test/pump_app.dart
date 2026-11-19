import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:saints_trivia_flutter/app.dart';

/// Builds [lightTheme] and [darkTheme] on the current platform.
///
/// Both are created on first use and then kept. `flutter_test_config.dart`
/// calls this from `setUpAll`, before a test can set
/// `debugDefaultTargetPlatformOverride`. A first read after that override
/// leaves every later [SaintsTriviaApp] on that platform, and tearDown
/// cannot rebuild the themes.
void captureAppThemes() {
  final platform = defaultTargetPlatform;
  if (lightTheme.platform != platform || darkTheme.platform != platform) {
    throw StateError(
      'App themes were built for ${lightTheme.platform} and '
      '${darkTheme.platform}, not $platform.',
    );
  }
}

Future<void> pumpApp(
  WidgetTester tester, {
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(overrides: overrides, child: const SaintsTriviaApp()),
  );
  await tester.pumpAndSettle();
}
