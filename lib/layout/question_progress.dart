import 'package:material_ui/material_ui.dart';

import 'text_scale.dart';

/// Question counter. Large text shows "7 / 10"; otherwise "Question 7 of 10".
///
/// The semantics label is always the long form.
class QuestionProgress extends StatelessWidget {
  const QuestionProgress({
    super.key,
    required this.current,
    required this.total,
  });

  final int current;
  final int total;

  static String semanticsLabelFor(int current, int total) {
    return 'Question $current of $total';
  }

  static String visibleLabelFor(
    int current,
    int total, {
    required bool largeText,
  }) {
    if (largeText) {
      return '$current / $total';
    }
    return semanticsLabelFor(current, total);
  }

  @override
  Widget build(BuildContext context) {
    final large = isLargeText(context);
    final spoken = semanticsLabelFor(current, total);
    return Semantics(
      container: true,
      label: spoken,
      excludeSemantics: true,
      child: Text(
        visibleLabelFor(current, total, largeText: large),
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}
