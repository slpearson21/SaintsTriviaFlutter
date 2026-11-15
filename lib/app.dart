import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

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

/// Built once. [SaintsTriviaApp] must not call [buildTheme] on every rebuild.
final ThemeData lightTheme = _theme(Brightness.light);
final ThemeData darkTheme = _theme(Brightness.dark);

class SaintsTriviaApp extends ConsumerWidget {
  const SaintsTriviaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Scripture Trivia',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
      builder: (context, child) {
        return SplashFade(child: child ?? const SizedBox.shrink());
      },
    );
  }
}
