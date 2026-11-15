import 'package:material_ui/material_ui.dart';

import '../theme/st_theme.dart';

/// Mikey's large-text breakpoint. True at 150% and above, including 200%.
bool isLargeText(BuildContext context) {
  return MediaQuery.textScalerOf(context).scale(1) >= 1.5;
}

/// Minimum hit target: 48 dp on Android, 44 pt on iOS.
double minTapTarget(BuildContext context) {
  return switch (Theme.of(context).platform) {
    TargetPlatform.iOS || TargetPlatform.macOS => 44,
    TargetPlatform.android ||
    TargetPlatform.fuchsia ||
    TargetPlatform.linux ||
    TargetPlatform.windows => StSpace.minTap,
  };
}
