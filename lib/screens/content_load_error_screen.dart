import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../data/questions/question_bank_provider.dart';
import '../layout/error_state.dart';
import '../routing/routes.dart';

/// E1. Shown when [questionBankProvider] fails, including the splash timeout.
///
/// [onLoaded] runs after Try again reads a bank. The splash route uses it to
/// open Home. Setup and the preparing step omit it: they already watch the
/// provider, so a successful retry rebuilds them in place.
class ContentLoadErrorView extends ConsumerWidget {
  const ContentLoadErrorView({super.key, this.onLoaded});

  final void Function(BuildContext context)? onLoaded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: ErrorState(
        icon: Icons.error_outline,
        actionIcon: Icons.refresh,
        title: contentLoadErrorTitle,
        body: contentLoadErrorBody,
        actionLabel: contentLoadErrorAction,
        onAction: () => unawaited(_tryAgain(context, ref)),
      ),
    );
  }

  Future<void> _tryAgain(BuildContext context, WidgetRef ref) async {
    ref.invalidate(questionBankProvider);
    final onLoaded = this.onLoaded;
    if (onLoaded == null) return;
    try {
      await ref.read(questionBankProvider.future);
    } catch (error) {
      debugPrint('Question bank retry failed: $error');
      return;
    }
    if (!context.mounted) return;
    onLoaded(context);
  }
}

/// Route for a bank that failed before Home opened.
class ContentLoadErrorScreen extends StatelessWidget {
  const ContentLoadErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ContentLoadErrorView(
      onLoaded: (context) => context.go(AppRoutes.home),
    );
  }
}
