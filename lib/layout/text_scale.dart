import 'package:material_ui/material_ui.dart';

import '../theme/st_theme.dart';
import 'platform_style.dart';

/// Mikey's large-text breakpoint. True at 150% and above, including 200%.
bool isLargeText(BuildContext context) {
  return MediaQuery.textScalerOf(context).scale(1) >= 1.5;
}

/// Toolbar height when text is large enough to need a second title line.
///
/// The Material toolbar is 56, which clips one scaled titleLarge line.
/// Large text gets two lines of that style.
double? largeTitleToolbarHeight(BuildContext context) {
  if (!isLargeText(context)) return null;
  final scaler = MediaQuery.textScalerOf(context);
  final style = Theme.of(context).textTheme.titleLarge;
  final fontSize = style?.fontSize ?? 22;
  final heightFactor = style?.height ?? 30 / 22;
  final line = scaler.scale(fontSize * heightFactor);
  return line * 2 + StSpace.md;
}

/// Minimum hit target: 48 dp on Android, 44 pt on iOS.
///
/// This follows [ThemeData.platform], so a theme can ask for the 44 pt
/// target without changing the device platform.
double minTapTarget(BuildContext context) {
  if (isCupertinoPlatform(Theme.of(context).platform)) return 44;
  return StSpace.minTap;
}
