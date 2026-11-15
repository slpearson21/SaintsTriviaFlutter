import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../routing/routes.dart';
import 'home_snapshot.dart';

/// Opens setup with [settings] attached as go_router `extra`.
///
/// Home's Play again still lands on setup, which is the screen-inventory
/// path. Starting the dealt game — Results' Play again, or a restored
/// `/game` — goes through the game route. That route reads
/// [LastGameSettings] from `extra` only when `extra` is one, and otherwise
/// uses the last settings on the home snapshot.
void openPlayAgain(BuildContext context, LastGameSettings settings) {
  context.go(AppRoutes.setup, extra: settings);
}
