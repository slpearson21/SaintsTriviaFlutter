import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../layout/adaptive_actions.dart';
import '../layout/screen_body.dart';
import '../routing/routes.dart';
import '../theme/st_theme.dart';
import 'placeholder_scaffold.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderScaffold(
      title: 'Results',
      primary: PrimaryButton(
        label: 'Done',
        onPressed: () => context.go(AppRoutes.home),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Score and breakdown will go here.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: StSpace.lg),
          AdaptiveActions(
            children: [
              OutlinedButton(
                onPressed: () => context.go(AppRoutes.setup),
                child: const Text('New game'),
              ),
              OutlinedButton(
                onPressed: () => context.go(AppRoutes.review),
                child: const Text('Review answers'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
