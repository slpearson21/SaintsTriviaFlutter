import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

/// True for Remove animations on Android or Reduce Motion on iOS.
///
/// Android's "Remove animations" is [MediaQueryData.disableAnimations].
/// iOS "Reduce Motion" is [MediaQueryData.reduceMotion] and does not set
/// the Android flag. [MediaQueryData.accessibleNavigation] is a screen
/// reader, not a motion setting, so it stays false here.
bool isReducedMotion(MediaQueryData media) {
  return media.disableAnimations || media.reduceMotion;
}

/// True on iOS and macOS. The other platforms use Material.
bool isCupertinoPlatform(TargetPlatform platform) {
  return switch (platform) {
    TargetPlatform.iOS || TargetPlatform.macOS => true,
    TargetPlatform.android ||
    TargetPlatform.fuchsia ||
    TargetPlatform.linux ||
    TargetPlatform.windows => false,
  };
}

/// Android, and the other Material platforms. iOS and macOS keep the
/// Cupertino chrome the mockups show.
///
/// This reads [defaultTargetPlatform], not [ThemeData.platform]. The app
/// themes are built once, so a test that overrides the platform would
/// otherwise keep the theme's original platform. Cupertino page transitions
/// stay on the theme, which is what the game screen's edge swipe expects.
bool usesMaterialChrome(BuildContext context) {
  return !isCupertinoPlatform(defaultTargetPlatform);
}
