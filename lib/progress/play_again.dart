import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../routing/routes.dart';
import 'home_snapshot.dart';

/// Opens setup with [settings] attached as go_router `extra`.
///
/// Play again should eventually skip setup and start a shuffled game,
/// the same path Results uses. The engine is not in this slice, so Home
/// calls only this function. STRIV-11 can prefill setup from
/// [LastGameSettings], or replace this function with a start-and-open
/// `/game` path, without rewriting Home.
void openPlayAgain(BuildContext context, LastGameSettings settings) {
  context.go(AppRoutes.setup, extra: settings);
}
