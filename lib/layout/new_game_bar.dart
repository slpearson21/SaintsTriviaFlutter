import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../routing/routes.dart';
import '../theme/st_theme.dart';
import 'platform_style.dart';
import 'st_icon.dart';
import 'text_scale.dart' hide usesMaterialChrome;

/// The setup bar, shared by E2 and by E1 when it replaces setup or preparing.
///
/// The splash content-error route stays bar-less. iOS shows "Home". Android
/// shows a back arrow. Both leave for Home, since these routes were opened
/// with [GoRouter.go].
AppBar newGameAppBar(BuildContext context) {
  final material = usesMaterialChrome(context);
  final large = isLargeText(context);
  return AppBar(
    automaticallyImplyLeading: false,
    // The error title is the header. Leaving this on would also mark
    // "New game" as a header (and, on Android, the route name), so a
    // screen reader would speak a title twice.
    excludeHeaderSemantics: true,
    centerTitle: !material,
    toolbarHeight: largeTitleToolbarHeight(context),
    leadingWidth: !material && !large ? 112 : null,
    leading: _HomeButton(showHomeLabel: !material && !large),
    title: const Text('New game', maxLines: 2),
  );
}

class _HomeButton extends StatelessWidget {
  const _HomeButton({required this.showHomeLabel});

  final bool showHomeLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final target = minTapTarget(context);
    if (!showHomeLabel) {
      final material = usesMaterialChrome(context);
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
