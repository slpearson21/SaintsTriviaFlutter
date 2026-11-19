import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../data/questions/question_bank_provider.dart';
import '../layout/error_state.dart';
import '../layout/new_game_bar.dart';
import '../routing/routes.dart';

/// E1. Shown when [questionBankProvider] fails, including the splash timeout.
///
/// [onLoaded] runs after Try again reads a bank. The splash route uses it to
/// open Home. Setup and the preparing step omit it: they already watch the
/// provider, so a successful retry rebuilds them in place.
class ContentLoadErrorView extends ConsumerStatefulWidget {
  const ContentLoadErrorView({
    super.key,
    this.onLoaded,
    this.showNewGameBar = false,
  });

  final void Function(BuildContext context)? onLoaded;

  /// Setup and the preparing step keep the New game bar, so there is a way
  /// home. The splash route leaves this false: ios-19 has no bar.
  final bool showNewGameBar;

  @override
  ConsumerState<ContentLoadErrorView> createState() =>
      _ContentLoadErrorViewState();
}

class _ContentLoadErrorViewState extends ConsumerState<ContentLoadErrorView> {
  /// How many times this view has landed on a failure after Try again.
  ///
  /// The first failure is announced by [ErrorState] at attempt 0. Each later
  /// failure bumps this so the same copy is announced once more.
  var _attempt = 0;

  @override
  Widget build(BuildContext context) {
    final bank = ref.watch(questionBankProvider);
    ref.listen(questionBankProvider, (previous, next) {
      final wasLoading = previous?.isLoading ?? false;
      if (wasLoading && !next.isLoading && next.hasError) {
        setState(() => _attempt++);
      }
    });
    return Scaffold(
      appBar: widget.showNewGameBar ? newGameAppBar(context) : null,
      body: ErrorState(
        icon: errorStateIcon,
        actionIcon: Icons.refresh,
        title: contentLoadErrorTitle,
        body: contentLoadErrorBody,
        actionLabel: contentLoadErrorAction,
        busy: bank.isLoading,
        attempt: _attempt,
        onAction: () => unawaited(_tryAgain()),
      ),
    );
  }

  Future<void> _tryAgain() async {
    ref.invalidate(questionBankProvider);
    final onLoaded = widget.onLoaded;
    if (onLoaded == null) return;
    try {
      await ref.read(questionBankProvider.future);
    } on Object catch (error) {
      debugPrint('Question bank retry failed: $error');
      return;
    }
    if (!mounted) return;
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
