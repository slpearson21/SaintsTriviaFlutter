import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../layout/screen_body.dart';
import '../routing/routes.dart';
import 'placeholder_scaffold.dart';

class ReviewScreen extends StatelessWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderScaffold(
      title: 'Review answers',
      primary: PrimaryButton(
        label: 'Back to results',
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(AppRoutes.results);
          }
        },
      ),
      body: Text(
        'Answer review will go here.',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    );
  }
}
