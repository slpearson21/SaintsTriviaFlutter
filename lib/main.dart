import 'package:flutter/widgets.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'data/questions/bundled_question_bank_loader.dart';
import 'splash_fade.dart';

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  holdSplashForHandoff();
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
    }
  } catch (error) {
    debugPrint('Bundled question bank failed to load: $error');
  } finally {
    revealSplash();
    removeSplash();
  }
}
