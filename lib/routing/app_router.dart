import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../screens/game_screen.dart';
import '../screens/home_screen.dart';
import '../screens/results_screen.dart';
import '../screens/review_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/setup_screen.dart';
import '../screens/stats_screen.dart';
import 'routes.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        name: AppRouteNames.home,
        builder: (context, state) => const HomeScreen(),
        routes: [
          GoRoute(
            path: 'setup',
            name: AppRouteNames.setup,
            builder: (context, state) => const SetupScreen(),
          ),
          GoRoute(
            path: 'game',
            name: AppRouteNames.game,
            builder: (context, state) => const GameScreen(),
          ),
          GoRoute(
            path: 'results',
            name: AppRouteNames.results,
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
