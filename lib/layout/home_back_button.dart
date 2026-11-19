import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../routing/routes.dart';
import '../theme/st_theme.dart';
import 'platform_style.dart';
import 'st_icon.dart';
import 'text_scale.dart';

/// Back control for screens opened from Home.
///
/// iOS shows "Home" until text is large, then just the chevron. Android
/// keeps the arrow. [leadingWidth] is wide enough for the word Home.
class HomeBackButton extends StatelessWidget {
  const HomeBackButton({super.key});

  static double? leadingWidth(BuildContext context) {
    if (usesMaterialChrome() || isLargeText(context)) return null;
    return 112;
  }

  @override
  Widget build(BuildContext context) {
    final material = usesMaterialChrome();
    final scheme = Theme.of(context).colorScheme;
    final target = minTapTarget(context);
    if (material || isLargeText(context)) {
      return IconButton(
        tooltip: material ? 'Back' : 'Home',
        onPressed: () => _leave(context),
        style: IconButton.styleFrom(
          minimumSize: Size.square(target),
          tapTargetSize: MaterialTapTargetSize.padded,
          foregroundColor: material ? null : scheme.primary,
        ),
        icon: StIcon(
          material ? Icons.arrow_back : Icons.arrow_back_ios_new,
          size: material ? 24 : 20,
          color: material ? null : scheme.primary,
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        style: TextButton.styleFrom(
          minimumSize: Size(target, target),
          padding: const EdgeInsets.symmetric(horizontal: StSpace.xs),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: scheme.primary,
        ),
        onPressed: () => _leave(context),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StIcon(Icons.arrow_back_ios_new, size: 18),
            SizedBox(width: 2),
            Text('Home'),
          ],
        ),
      ),
    );
  }
}

void _leave(BuildContext context) {
  if (context.canPop()) {
    context.pop();
    return;
  }
  context.go(AppRoutes.home);
}
