import 'package:material_ui/material_ui.dart';

import '../layout/screen_body.dart';
import '../layout/text_scale.dart';
import '../theme/st_theme.dart';

/// Shared chrome for the skeleton screens: wrapping title, scrolling body,
/// primary action pinned by [ScreenBody].
class PlaceholderScaffold extends StatelessWidget {
  const PlaceholderScaffold({
    super.key,
    required this.title,
    required this.body,
    this.primary,
    this.leading,
    this.automaticallyImplyLeading = true,
  });

  final String title;
  final Widget body;
  final Widget? primary;
  final Widget? leading;
  final bool automaticallyImplyLeading;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    // titleLarge's line height is 30. Allow two lines once text is large.
    final toolbarHeight = isLargeText(context)
        ? scaler.scale(30) * 2 + StSpace.md
        : null;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: automaticallyImplyLeading,
        leading: leading,
        toolbarHeight: toolbarHeight,
        title: Text(title, maxLines: 2),
      ),
      body: ScreenBody(primary: primary, child: body),
    );
  }
}
