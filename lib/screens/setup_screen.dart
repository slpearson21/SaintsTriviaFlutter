import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../layout/screen_body.dart';
import '../routing/routes.dart';
import 'placeholder_scaffold.dart';

class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderScaffold(
      title: 'Game setup',
      primary: PrimaryButton(
        label: 'Start game',
        onPressed: () => context.go(AppRoutes.game),
      ),
      body: Text(
        'Volume picker and question count will go here.',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    );
  }
}
