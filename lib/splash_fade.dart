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

/// Marks the app as waiting under the native splash.
///
/// Call this before [runApp], after [FlutterNativeSplash.preserve]. The first
/// frame then paints a surface-colored cover instead of popping Home in.
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

/// Covers [child] with the theme surface, then fades that cover out.
///
/// While the handoff is [SplashHandoff.inactive] this is just [child], so
/// widget tests that never preserve the splash keep their layout.
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
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: FadeTransition(
              key: splashFadeKey,
              opacity: _opacity,
              child: ColoredBox(color: Theme.of(context).colorScheme.surface),
            ),
          ),
        ),
      ],
    );
  }
}
