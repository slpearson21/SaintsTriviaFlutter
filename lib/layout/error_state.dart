import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/st_theme.dart';
import 'screen_body.dart';
import 'st_icon.dart';
import 'text_scale.dart';

/// E1, ios-19. The bundled bank could not be read.
const contentLoadErrorTitle = 'Something went wrong';
const contentLoadErrorBody =
    'We couldn’t load the questions on this device. '
    'Please try again. If this keeps happening, reinstall the app.';
const contentLoadErrorAction = 'Try again';

/// E2, ios-20. The selection dealt no questions.
const noQuestionsErrorTitle = 'Couldn’t start this game';
const noQuestionsErrorBody =
    'There aren’t any questions for this selection yet. '
    'Choose different scriptures and try again.';
const noQuestionsErrorAction = 'Back to setup';

/// Spoken name while Try again is in flight. The spinner replaces the
/// visible label, so this is what a screen reader hears.
const errorStateBusyLabel = 'Trying again';

/// ios-19 / ios-20 badge. The frames show an exclamation in a circle, drawn
/// in [StColors.wrong] on the [StColors.wrongContainer] disc. The glyph stays
/// this size when text scales, and it stays decorative: the title is the name.
const errorStateIcon = Icons.error_outline;
const _badgeSize = 88.0;
const _badgeIconSize = 44.0;

/// Body measure from the frames, at the default text scale only.
const _bodyMaxWidth = 280.0;

/// Centered pill from the frames. Large text uses the full width instead.
const _actionMinWidth = 220.0;

/// Extra space under the group so it sits above the geometric center.
const _opticalLift = 60.0;

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
    this.busy = false,
    this.attempt = 0,
  });

  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  /// Drawn inside the action. Omitted for a text-only button.
  final IconData? actionIcon;

  /// Try again is in flight. The action shows progress, does not accept taps,
  /// and is named [errorStateBusyLabel] for a screen reader.
  final bool busy;

  /// Increments after each new failure of the same copy, so that failure is
  /// announced once more. A rebuild of the same attempt stays quiet.
  final int attempt;

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
    if (oldWidget.attempt != widget.attempt ||
        oldWidget.title != widget.title ||
        oldWidget.body != widget.body) {
      _announce();
    }
  }

  /// One announcement for this attempt's title and body. The same attempt
  /// rebuilding, including while Try again is in flight, does not send it again.
  void _announce() {
    final message = '${widget.title}. ${widget.body}';
    final token = '${widget.attempt}|$message';
    if (_announced == token) return;
    _announced = token;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        SemanticsService.sendAnnouncement(
          View.of(context),
          message,
          Directionality.of(context),
        ),
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
      limitWidth: !large,
    );
    final action = _ErrorAction(
      label: widget.actionLabel,
      icon: widget.actionIcon,
      onPressed: widget.busy ? null : widget.onAction,
      expanded: large,
      busy: widget.busy,
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
                  const SizedBox(height: StSpace.lg),
                  Center(child: action),
                  const SizedBox(height: _opticalLift),
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
    required this.limitWidth,
  });

  final IconData icon;
  final String title;
  final String body;

  /// Frames cap the body near 280. Large text uses the full screen width.
  final bool limitWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tone = theme.extension<StColors>()!;
    final badge = ExcludeSemantics(
      child: Align(
        child: SizedBox(
          key: const Key('error-state-icon'),
          width: _badgeSize,
          height: _badgeSize,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tone.wrongContainer,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: StIcon(icon, size: _badgeIconSize, color: tone.wrong),
            ),
          ),
        ),
      ),
    );
    final message = Text(
      body,
      key: const Key('error-state-body'),
      textAlign: TextAlign.center,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        badge,
        const SizedBox(height: StSpace.sm),
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
        if (limitWidth)
          Align(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _bodyMaxWidth),
              child: message,
            ),
          )
        else
          message,
      ],
    );
  }
}

class _ErrorAction extends StatelessWidget {
  const _ErrorAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.expanded,
    required this.busy,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  /// Large text pins a full-width button. The default scale is a 220 pill.
  final bool expanded;

  final bool busy;

  @override
  Widget build(BuildContext context) {
    final target = minTapTarget(context);
    final minHeight = target < 52 ? 52.0 : target;
    final text = Text(label, textAlign: TextAlign.center);
    final glyph = icon;
    final Widget child;
    if (busy) {
      child = const SizedBox(
        key: Key('error-state-progress'),
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (glyph == null) {
      child = text;
    } else if (expanded) {
      child = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ExcludeSemantics(child: StIcon(glyph, size: 20)),
          const SizedBox(width: StSpace.xs),
          Flexible(child: text),
        ],
      );
    } else {
      child = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ExcludeSemantics(child: StIcon(glyph, size: 20)),
          const SizedBox(width: StSpace.xs),
          text,
        ],
      );
    }
    final button = FilledButton(
      key: const Key('error-state-action'),
      style: FilledButton.styleFrom(
        minimumSize: Size(expanded ? target : _actionMinWidth, minHeight),
      ),
      onPressed: onPressed,
      child: child,
    );
    if (!busy) return button;
    // The spinner is the only child, so the button would otherwise be an
    // unlabeled dimmed control. One stop, named for the action in flight.
    return Semantics(
      container: true,
      button: true,
      enabled: false,
      focusable: true,
      label: errorStateBusyLabel,
      excludeSemantics: true,
      child: button,
    );
  }
}
