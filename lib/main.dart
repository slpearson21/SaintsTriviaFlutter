import 'package:flutter/widgets.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'data/questions/bundled_question_bank_loader.dart';
import 'splash_fade.dart';

Future<void> main(List<String> args) async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  // Android passes SDK_INT as the first entrypoint argument.
  final sdk = args.isEmpty ? null : int.tryParse(args.first);
  if (sdk != null) {
    setSplashAndroidSdkInt(sdk);
  }
  holdSplashForHandoff();
  await prepareSplashHandoff();
  runApp(const ProviderScope(child: SaintsTriviaApp()));
  await removeSplashAfterBundledQuestionBank();
}

/// Loads the bundled question bank, then takes the native splash down.
///
/// [FlutterNativeSplash.preserve] must already have run. The splash comes
/// down after a successful load and after a failed one, so a bad question
/// bank cannot leave the launch screen up. [revealSplash] runs in this
/// finally block so the first frame cross-fades in as the splash leaves.
@visibleForTesting
Future<void> removeSplashAfterBundledQuestionBank({
  Future<void> Function()? loadQuestionBank,
  void Function() removeSplash = FlutterNativeSplash.remove,
}) async {
  try {
    if (loadQuestionBank != null) {
      await loadQuestionBank();
    } else {
      await loadBundledQuestionBank();
      // Device-shot builds pass SPLASH_HOLD_MS so the native splash stays
      // up long enough to photograph. Tests and normal builds leave it at 0.
      const holdMs = int.fromEnvironment('SPLASH_HOLD_MS');
      if (holdMs > 0) {
        await Future<void>.delayed(Duration(milliseconds: holdMs));
      }
    }
  } catch (error) {
    debugPrint('Bundled question bank failed to load: $error');
  } finally {
    // With a hold, drop the native splash while the cover is still opaque
    // and leave that first Flutter frame up long enough to photograph.
    const holdMs = int.fromEnvironment('SPLASH_HOLD_MS');
    if (holdMs > 0) {
      removeSplash();
      await Future<void>.delayed(const Duration(seconds: 4));
    }
    revealSplash();
    removeSplash();
  }
}
