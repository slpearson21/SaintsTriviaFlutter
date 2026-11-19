import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../game/game_launch.dart';
import '../game/game_providers.dart';
import '../progress/home_providers.dart';
import '../progress/home_snapshot.dart';
import '../results/results_summary.dart';
import '../screens/content_load_error_screen.dart';
import '../screens/game_screen.dart';
import '../screens/home_screen.dart';
import '../screens/results_screen.dart';
import '../screens/review_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/setup_screen.dart';
import '../screens/stats_screen.dart';
import 'routes.dart';

/// Settings the game route will deal.
///
/// [GoRouterState.extra] is read twice on purpose: it is a getter, so the `is`
/// check does not promote it, and the cast runs only after that check.
LastGameSettings? gameRouteSettings(Ref ref, GoRouterState state) {
  final fromRoute = state.extra is LastGameSettings
      ? state.extra as LastGameSettings
      : null;
  return gameSettingsFromRoute(fromRoute, ref.read(homeSnapshotProvider));
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(
        path: AppRoutes.contentError,
        name: AppRouteNames.contentError,
        builder: (context, state) => const ContentLoadErrorScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        name: AppRouteNames.home,
        builder: (context, state) => const HomeScreen(),
        routes: [
          GoRoute(
            path: 'setup',
            name: AppRouteNames.setup,
            builder: (context, state) {
              final extra = state.extra;
              return SetupScreen(
                initial: extra is LastGameSettings ? extra : null,
              );
            },
          ),
          GoRoute(
            path: 'game',
            name: AppRouteNames.game,
            redirect: (context, state) {
              if (gameRouteSettings(ref, state) == null) return AppRoutes.setup;
              return null;
            },
            builder: (context, state) {
              return GameScreen(settings: gameRouteSettings(ref, state));
            },
          ),
          GoRoute(
            path: 'results',
            name: AppRouteNames.results,
            redirect: (context, state) {
              // A deep link or a restore has no finished game in memory.
              // An in-progress session is not results either.
              if (!isFinishedSession(ref.read(gameControllerProvider))) {
                return AppRoutes.home;
              }
              return null;
            },
            builder: (context, state) => const ResultsScreen(),
            routes: [
              GoRoute(
                path: 'review',
                name: AppRouteNames.review,
                builder: (context, state) => const ReviewScreen(),
              ),
            ],
          ),
          GoRoute(
            path: 'stats',
            name: AppRouteNames.stats,
            builder: (context, state) => const StatsScreen(),
          ),
          GoRoute(
            path: 'settings',
            name: AppRouteNames.settings,
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
