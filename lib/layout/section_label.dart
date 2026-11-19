import 'package:material_ui/material_ui.dart';

import 'platform_style.dart';

/// Small section title. iOS draws it as small caps; Android keeps title case.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.title, {super.key});

  /// Title case. The spoken label stays this string on both platforms.
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final material = usesMaterialChrome(context);
    final style = material
        ? theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)
        : theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          );
    return Semantics(
      header: true,
      child: Text(
        material ? title : title.toUpperCase(),
        semanticsLabel: title,
        style: style,
      ),
    );
  }
}
