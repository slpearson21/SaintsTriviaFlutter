import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:saints_trivia_flutter/app.dart';

/// Builds [lightTheme] and [darkTheme] on the current platform.
///
/// Both are created on first use and then kept. Call this before setting
/// `debugDefaultTargetPlatformOverride`. A test that reads them after the
/// override leaves every later [SaintsTriviaApp] on that platform, and
/// tearDown cannot rebuild them.
void captureAppThemes() {
  if (lightTheme.platform != darkTheme.platform) {
    throw StateError('App themes were built on different platforms.');
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
