import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/services.dart' show MethodChannel;
import 'package:material_ui/material_ui.dart';

import 'theme/st_theme.dart';

/// How the native splash hands off to the first Flutter frame.
enum SplashHandoff {
  /// Widget tests and any run that never preserves the splash.
  inactive,

  /// Native splash is up. The first frame stays covered until [revealSplash].
  holding,

  /// Splash has been removed. The cover fades out over [splashFadeDuration].
  revealing,
}

/// Phase of the splash handoff. [main] moves this from [SplashHandoff.holding]
/// to [SplashHandoff.revealing] in the same finally block that removes the
/// native splash.
final ValueNotifier<SplashHandoff> splashHandoff = ValueNotifier(
  SplashHandoff.inactive,
);

/// Finder key for the cover while the handoff is on screen.
const splashFadeKey = ValueKey<String>('splash-fade');

/// Finder key for the launch-color background inside [splashFadeKey].
const splashBackgroundKey = ValueKey<String>('splash-background');

/// Finder key for the Open Book + Spark mark inside [splashFadeKey].
const splashLogoKey = ValueKey<String>('splash-logo');

/// Paper launch color (`flutter_native_splash` `color`, #FBF8F2).
const splashLaunchLight = Color(0xFFFBF8F2);

/// Navy launch color (`flutter_native_splash` `color_dark`, #0F1620).
const splashLaunchDark = Color(0xFF0F1620);

/// On-screen size of the iOS and pre-Android-12 launch mark, in logical pixels.
const splashMarkExtent = 192.0;

/// On-screen size of the Android 12+ splash icon, including its clear margin.
const splashAndroid12MarkExtent = 288.0;

/// Android 12, when [windowSplashScreenAnimatedIcon] replaced launch_background.
const splashAndroid12Api = 31;

const splashMarkLightAsset = 'assets/splash/splash-image-light-768.png';
const splashMarkDarkAsset = 'assets/splash/splash-image-dark-768.png';
const splashAndroid12MarkLightAsset =
    'assets/splash/splash-android12-light-1152.png';
const splashAndroid12MarkDarkAsset =
    'assets/splash/splash-android12-dark-1152.png';

const _splashSdkChannel = MethodChannel('saints_trivia/splash');

/// SDK_INT once [prepareSplashHandoff] has read it. Null on iOS and in tests
/// that never set it, which selects the pre-12 mark.
int? _splashAndroidSdkInt;

/// The launch image that lines up with the native splash.
///
/// iOS pins `LaunchImage` to every edge of the launch screen and draws it
/// with `contentMode="center"`. The imageset is 192 pt (@1x 192, @2x 384,
/// @3x 576). The storyboard resource entry still says 768×768, which is the
/// master pixel size flutter_native_splash recorded, not the size UIKit draws.
///
/// Android 11 and earlier center `drawable/splash` (`android:gravity="center"`)
/// in `launch_background`. Those density buckets are the same 192 dp artwork
/// (mdpi 192 px through xxxhdpi 768 px).
///
/// Android 12+ ignores that window background and shows
/// `windowSplashScreenAnimatedIcon`. With no icon background, AOSP sizes the
/// icon to 160 dp × 1.2 = 192 dp, then paints the bitmap through an
/// adaptive-icon viewport that maps the full 1152 px asset onto 288 dp and
/// masks it to the center 192 dp. The mark sits inside that circle and the
/// corners of the asset are transparent, so a 288 dp image centered on the
/// screen matches the masked icon.
///
/// What this does not copy: the system mask shape (a circle on Pixel, a
/// squircle on some other devices) does not change this artwork, and AOSP
/// truncates the viewport inset to whole pixels, which can leave the system
/// icon about one pixel off a pure 288 dp square on unusual densities. The
/// overlay scales the master PNG; the OS shows the pre-rasterized density
/// bucket, so the edge can be a hair softer without moving or resizing.
@visibleForTesting
SplashMark splashMarkFor({
  required TargetPlatform platform,
  required Brightness brightness,
  int? androidSdkInt,
}) {
  final dark = brightness == Brightness.dark;
  final android12 =
      platform == TargetPlatform.android &&
      (androidSdkInt ?? 0) >= splashAndroid12Api;
  if (android12) {
    return SplashMark(
      asset: dark
          ? splashAndroid12MarkDarkAsset
          : splashAndroid12MarkLightAsset,
      extent: splashAndroid12MarkExtent,
    );
  }
  return SplashMark(
    asset: dark ? splashMarkDarkAsset : splashMarkLightAsset,
    extent: splashMarkExtent,
  );
}

/// Launch background for [brightness]. These are the native splash colors,
/// not [ColorScheme.surface], even where the two happen to match today.
@visibleForTesting
Color splashLaunchColor(Brightness brightness) {
  return brightness == Brightness.dark ? splashLaunchDark : splashLaunchLight;
}

/// Reads the Android SDK, then decodes the splash mark before the first frame.
///
/// [FlutterNativeSplash.preserve] keeps the native splash up while this runs,
/// so the first Flutter frame can paint the logo instead of an empty color.
/// A failed lookup leaves the SDK unknown and the pre-12 mark is used.
Future<void> prepareSplashHandoff() async {
  final platform = defaultTargetPlatform;
  if (platform == TargetPlatform.android) {
    _splashAndroidSdkInt = await _readAndroidSdkInt();
  }
  final light = splashMarkFor(
    platform: platform,
    brightness: Brightness.light,
    androidSdkInt: _splashAndroidSdkInt,
  );
  final dark = splashMarkFor(
    platform: platform,
    brightness: Brightness.dark,
    androidSdkInt: _splashAndroidSdkInt,
  );
  await warmSplashMark(light.asset);
  if (dark.asset != light.asset) {
    await warmSplashMark(dark.asset);
  }
}

/// Decodes [asset] into the image cache. Errors are swallowed so a bad asset
/// cannot hold the native splash up.
@visibleForTesting
Future<void> warmSplashMark(String asset) async {
  try {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    final dpr = views.isEmpty ? 1.0 : views.first.devicePixelRatio;
    final stream = AssetImage(asset)
        .resolve(ImageConfiguration(devicePixelRatio: dpr));
    final completer = Completer<void>();
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo image, bool synchronousCall) {
        stream.removeListener(listener);
        if (!completer.isCompleted) completer.complete();
      },
      onError: (Object error, StackTrace? stackTrace) {
        debugPrint('Splash mark failed to decode ($asset): $error');
        stream.removeListener(listener);
        if (!completer.isCompleted) completer.complete();
      },
    );
    stream.addListener(listener);
    await completer.future.timeout(
      const Duration(seconds: 2),
      onTimeout: () {},
    );
  } catch (error) {
    debugPrint('Splash mark failed to decode ($asset): $error');
  }
}

Future<int?> _readAndroidSdkInt() async {
  try {
    return await _splashSdkChannel
        .invokeMethod<int>('sdkInt')
        .timeout(const Duration(seconds: 1), onTimeout: () => null);
  } catch (error) {
    debugPrint('Splash SDK lookup failed: $error');
    return null;
  }
}

/// The Open Book + Spark asset and the logical size the native splash uses.
@immutable
class SplashMark {
  const SplashMark({required this.asset, required this.extent});

  final String asset;
  final double extent;
}

/// Marks the app as waiting under the native splash.
///
/// Call this before [runApp], after [FlutterNativeSplash.preserve]. The first
/// frame then paints the launch color and logo instead of popping Home in.
void holdSplashForHandoff() {
  splashHandoff.value = SplashHandoff.holding;
}

/// Starts the cross-fade. No-op unless [holdSplashForHandoff] ran.
void revealSplash() {
  if (splashHandoff.value == SplashHandoff.holding) {
    splashHandoff.value = SplashHandoff.revealing;
  }
}

/// Puts the handoff back to [SplashHandoff.inactive] between tests.
@visibleForTesting
void debugResetSplashHandoff() {
  splashHandoff.value = SplashHandoff.inactive;
  _splashAndroidSdkInt = null;
}

/// Pins the Android SDK the overlay uses. Null selects the pre-12 mark.
@visibleForTesting
void debugSetSplashAndroidSdkInt(int? sdkInt) {
  _splashAndroidSdkInt = sdkInt;
}

/// How long the splash cover takes to fade out.
///
/// Full motion is [StMotion.medium] (250ms). Reduced motion is [StMotion.fast]
/// (150ms). Android's "Remove animations" is [MediaQueryData.disableAnimations];
/// iOS "Reduce Motion" is [MediaQueryData.reduceMotion] and does not set the
/// Android flag. [MediaQueryData.accessibleNavigation] is a screen reader, not
/// a motion setting, so it keeps the 250ms fade.
@visibleForTesting
Duration splashFadeDuration(MediaQueryData media) {
  final reducedMotion = media.disableAnimations || media.reduceMotion;
  return reducedMotion ? StMotion.fast : StMotion.medium;
}

/// Covers [child] with the native splash, then fades that cover out.
///
/// The background and the logo share one [FadeTransition], so they leave
/// together. While the handoff is [SplashHandoff.inactive] this is just
/// [child], so widget tests that never preserve the splash keep their layout.
class SplashFade extends StatefulWidget {
  const SplashFade({super.key, required this.child});

  final Widget child;

  @override
  State<SplashFade> createState() => _SplashFadeState();
}

class _SplashFadeState extends State<SplashFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _opacity;
  bool _revealStarted = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: StMotion.medium,
      // Keep the 150ms/250ms we chose. The framework would otherwise squash
      // a normal controller to one frame when disableAnimations is set.
      animationBehavior: AnimationBehavior.preserve,
      value: 0,
    );
    _opacity = CurvedAnimation(parent: _controller, curve: StMotion.standard);
    _controller.addStatusListener(_onStatus);
    splashHandoff.addListener(_handleHandoffNotice);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _onHandoff();
  }

  @override
  void dispose() {
    splashHandoff.removeListener(_handleHandoffNotice);
    _controller.removeStatusListener(_onStatus);
    _opacity.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleHandoffNotice() {
    _onHandoff();
    if (mounted) setState(() {});
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed &&
        splashHandoff.value == SplashHandoff.revealing &&
        mounted) {
      setState(() {});
    }
  }

  void _onHandoff() {
    if (!mounted) return;
    switch (splashHandoff.value) {
      case SplashHandoff.inactive:
        _revealStarted = false;
        if (_controller.isAnimating) {
          _controller.stop();
        }
        _controller.value = 0;
      case SplashHandoff.holding:
        _revealStarted = false;
        if (_controller.isAnimating) {
          _controller.stop();
        }
        // Fully covered. reverse() below is what fades the cover out.
        _controller.value = 1;
      case SplashHandoff.revealing:
        if (_revealStarted) return;
        _revealStarted = true;
        _controller.duration = splashFadeDuration(MediaQuery.of(context));
        _controller.reverse(from: 1);
    }
  }

  bool get _showCover {
    final phase = splashHandoff.value;
    if (phase == SplashHandoff.holding) return true;
    return phase == SplashHandoff.revealing &&
        _controller.status != AnimationStatus.dismissed;
  }

  @override
  Widget build(BuildContext context) {
    if (!_showCover) return widget.child;
    final brightness = Theme.of(context).brightness;
    final mark = splashMarkFor(
      platform: defaultTargetPlatform,
      brightness: brightness,
      androidSdkInt: _splashAndroidSdkInt,
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Positioned.fill(
          child: ExcludeSemantics(
            child: IgnorePointer(
              child: FadeTransition(
                key: splashFadeKey,
                opacity: _opacity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      key: splashBackgroundKey,
                      color: splashLaunchColor(brightness),
                    ),
                    Center(
                      child: Image.asset(
                        mark.asset,
                        key: splashLogoKey,
                        width: mark.extent,
                        height: mark.extent,
                        fit: BoxFit.fill,
                        filterQuality: FilterQuality.medium,
                        excludeFromSemantics: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
