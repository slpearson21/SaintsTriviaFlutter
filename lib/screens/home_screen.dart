import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../layout/adaptive_actions.dart';
import '../layout/screen_body.dart';
import '../routing/routes.dart';
import '../theme/st_theme.dart';
import 'placeholder_scaffold.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return PlaceholderScaffold(
      title: 'Home',
      primary: PrimaryButton(
        label: 'Start a game',
        onPressed: () => context.push(AppRoutes.setup),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Scripture Trivia', style: text.headlineMedium),
          const SizedBox(height: StSpace.sm),
          Text(
            'Test your scripture knowledge. Free, offline, no account.',
            style: text.bodyLarge,
          ),
          const SizedBox(height: StSpace.xl),
          AdaptiveActions(
            children: [
              OutlinedButton(
                onPressed: () => context.push(AppRoutes.stats),
                child: const Text('Stats'),
              ),
              OutlinedButton(
                onPressed: () => context.push(AppRoutes.settings),
                child: const Text('Settings'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
