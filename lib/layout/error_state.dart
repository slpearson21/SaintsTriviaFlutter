import 'package:flutter/semantics.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/st_theme.dart';
import 'screen_body.dart';
import 'st_icon.dart';
import 'text_scale.dart';

/// E1, ios-19. The bundled bank could not be read.
const contentLoadErrorTitle = 'Something went wrong';
const contentLoadErrorBody =
    "We couldn't load the questions on this device. "
    'Please try again. If this keeps happening, reinstall the app.';
const contentLoadErrorAction = 'Try again';

/// E2, ios-20. The selection dealt no questions.
const noQuestionsErrorTitle = "Couldn't start this game";
const noQuestionsErrorBody =
    "There aren't any questions for this selection yet. "
    'Choose different scriptures and try again.';
const noQuestionsErrorAction = 'Back to setup';

/// Full-screen error: decorative icon, header title, body, one action.
///
/// The icon is never the only signal. The title is a header. At text scale
/// 1.5 and above the body scrolls and the action stays pinned. The state is
/// announced once, through [SemanticsService], and this widget is not a live
/// region, so a screen reader does not hear it twice.
class ErrorState extends StatefulWidget {
  const ErrorState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
    this.actionIcon,
  });

  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  /// Drawn inside the action. Omitted for a text-only button.
  final IconData? actionIcon;

  @override
  State<ErrorState> createState() => _ErrorStateState();
}

class _ErrorStateState extends State<ErrorState> {
  String? _announced;

  @override
  void initState() {
    super.initState();
    _announce();
  }

  @override
  void didUpdateWidget(ErrorState oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title || oldWidget.body != widget.body) {
      _announce();
    }
  }

  /// One announcement for this title and body. A rebuild of the same copy
  /// does not send it again.
  void _announce() {
    final message = '${widget.title}. ${widget.body}';
    if (_announced == message) return;
    _announced = message;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      SemanticsService.sendAnnouncement(
        View.of(context),
        message,
        Directionality.of(context),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final large = isLargeText(context);
    final content = _ErrorCopy(
      icon: widget.icon,
      title: widget.title,
      body: widget.body,
    );
    final action = _ErrorAction(
      label: widget.actionLabel,
      icon: widget.actionIcon,
      onPressed: widget.onAction,
    );
    if (large) {
      return ScreenBody(primary: action, child: content);
    }
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          const vertical = StSpace.md * 2;
          final minHeight = constraints.maxHeight - vertical;
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: StSpace.screenH,
              vertical: StSpace.md,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: minHeight < 0 ? 0 : minHeight,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  content,
                  const SizedBox(height: StSpace.xl),
                  action,
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ErrorCopy extends StatelessWidget {
  const _ErrorCopy({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(
          child: Align(
            alignment: Alignment.center,
            child: SizedBox(
              key: const Key('error-state-icon'),
              width: 80,
              height: 80,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: StIcon(icon, size: 36, color: scheme.error),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: StSpace.xl),
        Semantics(
          header: true,
          child: Text(
            title,
            key: const Key('error-state-title'),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
        ),
        const SizedBox(height: StSpace.sm),
        Text(
          body,
          key: const Key('error-state-body'),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ErrorAction extends StatelessWidget {
  const _ErrorAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData? icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final target = minTapTarget(context);
    return FilledButton(
      key: const Key('error-state-action'),
      style: FilledButton.styleFrom(
        minimumSize: Size(target, target < 52 ? 52 : target),
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            ExcludeSemantics(child: StIcon(icon!, size: 20)),
            const SizedBox(width: StSpace.xs),
          ],
          Flexible(child: Text(label, textAlign: TextAlign.center)),
        ],
      ),
    );
  }
}
