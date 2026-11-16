import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../data/questions/question_bank_exception.dart';
import '../data/questions/question_bank_provider.dart';
import '../layout/screen_body.dart';
import '../layout/st_icon.dart';
import '../routing/routes.dart';
import '../theme/st_theme.dart';
import 'placeholder_scaffold.dart';

/// Placeholder for the E1 content-load error until STRIV-17.
///
/// The designed screen (icon, copy, Try again per ios-19) is still backlog.
/// This shows [QuestionBankException.userMessage] and retries the same
/// [questionBankProvider] the splash waited on.
class ContentLoadErrorScreen extends ConsumerWidget {
  const ContentLoadErrorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return PlaceholderScaffold(
      title: 'Content failed to load',
      automaticallyImplyLeading: false,
      primary: PrimaryButton(
        label: 'Try again',
        onPressed: () => _tryAgain(context, ref),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: StIcon(Icons.error_outline, size: 32, color: scheme.error),
          ),
          const SizedBox(height: StSpace.md),
          Text(
            QuestionBankException.userMessage,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }

  Future<void> _tryAgain(BuildContext context, WidgetRef ref) async {
    ref.invalidate(questionBankProvider);
    try {
      await ref.read(questionBankProvider.future);
    } catch (error) {
      debugPrint('Question bank retry failed: $error');
      return;
    }
    if (!context.mounted) return;
    context.go(AppRoutes.home);
  }
}
