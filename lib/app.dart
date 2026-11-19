import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'persistence/persistence_providers.dart';
import 'routing/app_router.dart';
import 'splash_fade.dart';
import 'theme/st_theme.dart';

/// Icons stay at their drawn size when the user enlarges text.
ThemeData _theme(Brightness brightness) {
  final theme = buildTheme(brightness);
  return theme.copyWith(
    iconTheme: theme.iconTheme.copyWith(applyTextScaling: false),
    primaryIconTheme: theme.primaryIconTheme.copyWith(applyTextScaling: false),
  );
}

/// Light theme for the platform at the moment it is built.
ThemeData buildLightTheme() => _theme(Brightness.light);

/// Dark theme for the platform at the moment it is built.
ThemeData buildDarkTheme() => _theme(Brightness.dark);

class SaintsTriviaApp extends ConsumerWidget {
  const SaintsTriviaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(
      settingsProvider.select((settings) => settings.themeMode),
    );
    return MaterialApp.router(
      title: 'Scripture Trivia',
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        return SplashFade(child: child ?? const SizedBox.shrink());
      },
    );
  }
}
