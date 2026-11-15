import 'package:material_ui/material_ui.dart';

import '../theme/st_theme.dart';

/// Scrollable screen content with the primary action pinned at the bottom.
///
/// Safe area insets stay outside both the scroller and the button, so 200%
/// text can scroll without covering the action or overflowing the screen.
class ScreenBody extends StatelessWidget {
  const ScreenBody({super.key, required this.child, this.primary});

  final Widget child;
  final Widget? primary;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: StSpace.screenH,
                vertical: StSpace.md,
              ),
              child: child,
            ),
          ),
          if (primary != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                StSpace.screenH,
                StSpace.xs,
                StSpace.screenH,
                StSpace.md,
              ),
              child: primary,
            ),
        ],
      ),
    );
  }
}

/// Full-width pill. Height is a minimum, so the label can wrap at large text.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      child: Text(label, textAlign: TextAlign.center),
    );
  }
}
