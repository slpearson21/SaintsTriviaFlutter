import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/st_theme.dart';

/// Mikey's large-text breakpoint. True at 150% and above, including 200%.
bool isLargeText(BuildContext context) {
  return MediaQuery.textScalerOf(context).scale(1) >= 1.5;
}

/// True for Remove animations on Android or Reduce Motion on iOS.
///
/// Android's "Remove animations" is [MediaQueryData.disableAnimations].
/// iOS "Reduce Motion" is [MediaQueryData.reduceMotion] and does not set
/// the Android flag. [MediaQueryData.accessibleNavigation] is a screen
/// reader, not a motion setting, so it stays false here.
bool isReducedMotion(MediaQueryData media) {
  return media.disableAnimations || media.reduceMotion;
}

/// Android, and the other Material platforms. iOS and macOS keep the
/// Cupertino chrome the mockups show.
///
/// This reads [defaultTargetPlatform], not [ThemeData.platform]. The app
/// themes are built once, so a test that overrides the platform would
/// otherwise keep the theme's original platform. Cupertino page transitions
/// stay on the theme, which is what the game screen's edge swipe expects.
bool usesMaterialChrome(BuildContext context) {
  return switch (defaultTargetPlatform) {
    TargetPlatform.iOS || TargetPlatform.macOS => false,
    TargetPlatform.android ||
    TargetPlatform.fuchsia ||
    TargetPlatform.linux ||
    TargetPlatform.windows => true,
  };
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
double minTapTarget(BuildContext context) {
  return switch (Theme.of(context).platform) {
    TargetPlatform.iOS || TargetPlatform.macOS => 44,
    TargetPlatform.android ||
    TargetPlatform.fuchsia ||
    TargetPlatform.linux ||
    TargetPlatform.windows => StSpace.minTap,
  };
}
