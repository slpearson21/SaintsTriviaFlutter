import 'package:material_ui/material_ui.dart';

import '../theme/st_theme.dart';
import 'text_scale.dart';

/// Side-by-side actions that stack vertically when text is large.
class AdaptiveActions extends StatelessWidget {
  const AdaptiveActions({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final large = isLargeText(context);
    final items = large
        ? children
        : [for (final child in children) Expanded(child: child)];
    final gap = large
        ? const SizedBox(height: StSpace.sm)
        : const SizedBox(width: StSpace.sm);
    final spaced = <Widget>[
      for (var i = 0; i < items.length; i++) ...[if (i > 0) gap, items[i]],
    ];
    if (large) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: spaced,
      );
    }
    return Row(children: spaced);
  }
}
