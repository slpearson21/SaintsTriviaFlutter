import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../layout/screen_body.dart';
import '../routing/routes.dart';
import 'placeholder_scaffold.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderScaffold(
      title: 'Settings',
      primary: PrimaryButton(
        label: 'Done',
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(AppRoutes.home);
          }
        },
      ),
      body: Text(
        'Appearance follows the system for now. Sound, haptics, and about will go here.',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    );
  }
}
