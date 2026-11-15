/// Full paths used with go_router navigation.
abstract final class AppRoutes {
  static const home = '/';
  static const setup = '/setup';
  static const game = '/game';
  static const results = '/results';
  static const review = '/results/review';
  static const stats = '/stats';
  static const settings = '/settings';

  /// E1. The bundled bank timed out or failed to load.
  static const contentError = '/content-error';
}

/// go_router route names.
abstract final class AppRouteNames {
  static const home = 'home';
  static const setup = 'setup';
  static const game = 'game';
  static const results = 'results';
  static const review = 'review';
  static const stats = 'stats';
  static const settings = 'settings';
  static const contentError = 'contentError';
}
