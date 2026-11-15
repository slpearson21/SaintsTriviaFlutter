import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../layout/screen_body.dart';
import '../routing/routes.dart';
import 'placeholder_scaffold.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderScaffold(
      title: 'Stats',
      primary: PrimaryButton(
        label: 'Start a game',
        onPressed: () => context.go(AppRoutes.setup),
      ),
      body: Text(
        'On-device stats will go here. No games yet.',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    );
  }
}
