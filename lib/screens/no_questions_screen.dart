import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../layout/error_state.dart';
import '../layout/st_icon.dart';
import '../layout/text_scale.dart';
import '../progress/home_snapshot.dart';
import '../routing/routes.dart';
import '../theme/st_theme.dart';

/// E2. The deal for [settings] had no questions.
///
/// The bar matches setup (iOS "Home", Android back arrow). Back to setup
/// opens setup again with [settings] still selected.
class NoQuestionsScreen extends StatelessWidget {
  const NoQuestionsScreen({super.key, required this.settings});

  final LastGameSettings? settings;

  @override
  Widget build(BuildContext context) {
    final material = _materialChrome(context);
    final large = isLargeText(context);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: !material,
        toolbarHeight: _toolbarHeight(context),
        leadingWidth: !material && !large ? 112 : null,
        leading: _HomeButton(showHomeLabel: !material && !large),
        title: const Text('New game', maxLines: 2),
      ),
      body: ErrorState(
        icon: Icons.error_outline,
        title: noQuestionsErrorTitle,
        body: noQuestionsErrorBody,
        actionLabel: noQuestionsErrorAction,
        onAction: () => context.go(AppRoutes.setup, extra: settings),
      ),
    );
  }
}

bool _materialChrome(BuildContext context) {
  return switch (Theme.of(context).platform) {
    TargetPlatform.iOS || TargetPlatform.macOS => false,
    TargetPlatform.android ||
    TargetPlatform.fuchsia ||
    TargetPlatform.linux ||
    TargetPlatform.windows => true,
  };
}

double? _toolbarHeight(BuildContext context) {
  if (!isLargeText(context)) return null;
  final titleStyle = Theme.of(context).textTheme.titleLarge;
  final fontSize = titleStyle?.fontSize ?? 22;
  final heightFactor = titleStyle?.height ?? 30 / 22;
  final line = MediaQuery.textScalerOf(context).scale(fontSize * heightFactor);
  return line * 2 + StSpace.md;
}

class _HomeButton extends StatelessWidget {
  const _HomeButton({required this.showHomeLabel});

  final bool showHomeLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final target = minTapTarget(context);
    if (!showHomeLabel) {
      final material = _materialChrome(context);
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
