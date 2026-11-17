import 'package:flutter/widgets.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/questions/question_bank_provider.dart';
import 'persistence/memory_progress_repository.dart';
import 'persistence/persistence_providers.dart';
import 'persistence/progress_repository.dart';
import 'persistence/shared_preferences_progress_repository.dart';
import 'routing/app_router.dart';
import 'routing/routes.dart';
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
  final repository = await progressRepositoryForLaunch(
    loadPrefs: SharedPreferences.getInstance,
  );
  final container = ProviderContainer(
    overrides: [progressRepositoryProvider.overrideWithValue(repository)],
  );
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const SaintsTriviaApp(),
    ),
  );
  await removeSplashAfterBundledQuestionBank(container: container);
}

/// Opens on-device storage, or an empty in-memory store if that fails.
///
/// A thrown [SharedPreferences.getInstance] used to skip [runApp], which
/// left the preserved native splash up. Stats from this launch are not
/// written through, and the next launch tries the store again.
@visibleForTesting
Future<ProgressRepository> progressRepositoryForLaunch({
  required Future<SharedPreferences> Function() loadPrefs,
}) async {
  try {
    final prefs = await loadPrefs();
    return SharedPreferencesProgressRepository(prefs);
  } catch (error, stackTrace) {
    debugPrint('Shared preferences failed to load: $error\n$stackTrace');
    return MemoryProgressRepository();
  }
}

/// Waits for the question bank, then takes the native splash down.
///
/// [FlutterNativeSplash.preserve] must already have run. Pass [container]
/// so this waits on [questionBankProvider] — the same future the rest of
/// the app reads — instead of loading the bank a second time. The splash
/// comes down after a successful load and after a failed one, including
/// the provider's timeout, so a bad bank cannot leave the launch screen
/// up. A failure also opens the content-load error route. [revealSplash]
/// runs in this finally block so the first frame cross-fades in as the
/// splash leaves.
///
/// [loadQuestionBank] is the test seam. When it is set, [container] is
/// not read.
@visibleForTesting
Future<void> removeSplashAfterBundledQuestionBank({
  Future<void> Function()? loadQuestionBank,
  void Function() removeSplash = FlutterNativeSplash.remove,
  ProviderContainer? container,
}) async {
  try {
    if (loadQuestionBank != null) {
      await loadQuestionBank();
    } else {
      await _awaitQuestionBank(container);
    }
  } catch (error) {
    debugPrint('Bundled question bank failed to load: $error');
    _openContentLoadError(container);
  } finally {
    revealSplash();
    removeSplash();
  }
}

Future<void> _awaitQuestionBank(ProviderContainer? container) async {
  final scope = container ?? ProviderContainer();
  try {
    await scope.read(questionBankProvider.future);
  } finally {
    if (container == null) scope.dispose();
  }
}

void _openContentLoadError(ProviderContainer? container) {
  if (container == null) return;
  try {
    container.read(appRouterProvider).go(AppRoutes.contentError);
  } catch (error) {
    debugPrint('Could not open the content-load error screen: $error');
  }
}
