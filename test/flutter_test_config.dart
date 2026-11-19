import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'pump_app.dart';

/// Each test file runs in its own isolate. The app themes are built on
/// their first read and then kept, so an iOS override that pumps first
/// would leave the rest of the file with an iOS theme. Read them here,
/// before any test sets the override.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUpAll(captureAppThemes);
  await testMain();
}
