import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../layout/error_state.dart';
import '../layout/new_game_bar.dart';
import '../progress/home_snapshot.dart';
import '../routing/routes.dart';

/// E2. The deal for [settings] had no questions.
///
/// The bar matches setup (iOS "Home", Android back arrow). Back to setup
/// opens setup again with [settings] still selected.
class NoQuestionsScreen extends StatelessWidget {
  const NoQuestionsScreen({super.key, required this.settings});

  final LastGameSettings? settings;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: newGameAppBar(context),
      body: ErrorState(
        icon: Icons.info,
        title: noQuestionsErrorTitle,
        body: noQuestionsErrorBody,
        actionLabel: noQuestionsErrorAction,
        onAction: () => context.go(AppRoutes.setup, extra: settings),
      ),
    );
  }
}
