import 'dart:async';

import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/rendering.dart' show RenderImage;
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saints_trivia_flutter/app.dart';
import 'package:saints_trivia_flutter/main.dart';
import 'package:saints_trivia_flutter/splash_fade.dart';
import 'package:saints_trivia_flutter/theme/st_theme.dart';

void main() {
  tearDown(debugResetSplashHandoff);
  testWidgets('splash stays up until the question bank load finishes', (
    tester,
  ) async {
    final gate = Completer<void>();
    var removed = false;
    final pending = removeSplashAfterBundledQuestionBank(
      loadQuestionBank: () => gate.future,
      removeSplash: () => removed = true,
    );

    await tester.pump();
    expect(removed, isFalse, reason: 'splash removed before the bank loaded');

    gate.complete();
    await pending;
    expect(removed, isTrue);
  });

  testWidgets('splash comes down when the question bank load fails', (
    tester,
  ) async {
    var removed = false;
    await removeSplashAfterBundledQuestionBank(
      loadQuestionBank: () async {
        throw Exception('bank failed');
      },
      removeSplash: () => removed = true,
    );
    expect(removed, isTrue);
  });

  testWidgets('native splash stays until the bundled bank load finishes', (
    tester,
  ) async {
    tester.binding.resetFirstFrameSent();
    FlutterNativeSplash.preserve(widgetsBinding: tester.binding);
    expect(tester.binding.sendFramesToEngine, isFalse);

    final gate = Completer<void>();
    final pending = removeSplashAfterBundledQuestionBank(
      loadQuestionBank: () => gate.future,
    );
    await tester.pump();
    expect(tester.binding.sendFramesToEngine, isFalse);

    gate.complete();
    await pending;
    await tester.pump();
    expect(tester.binding.sendFramesToEngine, isTrue);
  });

  testWidgets('native splash comes down when the bundled bank load fails', (
    tester,
  ) async {
    tester.binding.resetFirstFrameSent();
    FlutterNativeSplash.preserve(widgetsBinding: tester.binding);

    await removeSplashAfterBundledQuestionBank(
      loadQuestionBank: () async {
        throw Exception('bank failed');
      },
    );
    await tester.pump();

    expect(tester.binding.sendFramesToEngine, isTrue);
  });

  testWidgets('bundled question bank load removes the native splash', (
    tester,
  ) async {
    tester.binding.resetFirstFrameSent();
    FlutterNativeSplash.preserve(widgetsBinding: tester.binding);

    await removeSplashAfterBundledQuestionBank();
    await tester.pump();

    expect(tester.binding.sendFramesToEngine, isTrue);
  });

  testWidgets('splash fades into the first frame over 250ms', (tester) async {
    await _expectCoverFade(tester, fade: StMotion.medium);
  });

  testWidgets('reduced motion fades the splash out over 150ms', (tester) async {
    await _expectCoverFade(
      tester,
      fade: StMotion.fast,
      features: const FakeAccessibilityFeatures(disableAnimations: true),
    );
  });

  testWidgets('iOS reduce motion fades the splash out over 150ms', (
    tester,
  ) async {
    await _expectCoverFade(
      tester,
      fade: StMotion.fast,
      features: const FakeAccessibilityFeatures(reduceMotion: true),
    );
  });

  testWidgets('screen readers keep the 250ms splash fade', (tester) async {
    await _expectCoverFade(
      tester,
      fade: StMotion.medium,
      features: const FakeAccessibilityFeatures(accessibleNavigation: true),
    );
  });

  testWidgets('first frame uses the light launch color and the logo', (
    tester,
  ) async {
    await _pumpHeldSplash(tester, brightness: Brightness.light);
    _expectLaunchFrame(
      tester,
      color: splashLaunchLight,
      asset: splashMarkLightAsset,
      extent: splashMarkExtent,
    );
  });

  testWidgets('first frame uses the dark launch color and the logo', (
    tester,
  ) async {
    await _pumpHeldSplash(tester, brightness: Brightness.dark);
    _expectLaunchFrame(
      tester,
      color: splashLaunchDark,
      asset: splashMarkDarkAsset,
      extent: splashMarkExtent,
    );
  });

  testWidgets('cover keeps the launch color when the theme surface differs', (
    tester,
  ) async {
    holdSplashForHandoff();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          brightness: Brightness.light,
          colorScheme: const ColorScheme.light(surface: Color(0xFFFF00FF)),
        ),
        home: const SplashFade(child: SizedBox.expand()),
      ),
    );
    final theme = Theme.of(tester.element(find.byKey(splashBackgroundKey)));
    expect(theme.colorScheme.surface, isNot(splashLaunchLight));
    _expectLaunchFrame(
      tester,
      color: splashLaunchLight,
      asset: splashMarkLightAsset,
      extent: splashMarkExtent,
    );
  });

  testWidgets('dark platform keeps the dark launch color under a light theme', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    holdSplashForHandoff();
    await tester.pumpWidget(
      MaterialApp(
        themeMode: ThemeMode.light,
        theme: ThemeData(
          brightness: Brightness.light,
          colorScheme: const ColorScheme.light(surface: Color(0xFFFF00FF)),
        ),
        home: const SplashFade(child: SizedBox.expand()),
      ),
    );
    final context = tester.element(find.byKey(splashBackgroundKey));
    expect(Theme.of(context).brightness, Brightness.light);
    expect(MediaQuery.platformBrightnessOf(context), Brightness.dark);
    _expectLaunchFrame(
      tester,
      color: splashLaunchDark,
      asset: splashMarkDarkAsset,
      extent: splashMarkExtent,
    );
  });

  testWidgets(
    'light platform keeps the light launch color under a dark theme',
    (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      holdSplashForHandoff();
      await tester.pumpWidget(
        MaterialApp(
          themeMode: ThemeMode.dark,
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            colorScheme: const ColorScheme.dark(surface: Color(0xFF010203)),
          ),
          home: const SplashFade(child: SizedBox.expand()),
        ),
      );
      final context = tester.element(find.byKey(splashBackgroundKey));
      expect(Theme.of(context).brightness, Brightness.dark);
      expect(MediaQuery.platformBrightnessOf(context), Brightness.light);
      _expectLaunchFrame(
        tester,
        color: splashLaunchLight,
        asset: splashMarkLightAsset,
        extent: splashMarkExtent,
      );
    },
  );

  testWidgets('Android 12+ light frame uses the 288 dp splash icon', (
    tester,
  ) async {
    debugSetSplashAndroidSdkInt(34);
    await _pumpHeldSplash(tester, brightness: Brightness.light);
    _expectLaunchFrame(
      tester,
      color: splashLaunchLight,
      asset: splashAndroid12MarkLightAsset,
      extent: splashAndroid12MarkExtent,
    );
  });

  testWidgets('Android 12+ dark frame uses the 288 dp splash icon', (
    tester,
  ) async {
    debugSetSplashAndroidSdkInt(31);
    await _pumpHeldSplash(tester, brightness: Brightness.dark);
    _expectLaunchFrame(
      tester,
      color: splashLaunchDark,
      asset: splashAndroid12MarkDarkAsset,
      extent: splashAndroid12MarkExtent,
    );
  });

  testWidgets('Android 11 first frame uses the 192 dp launch image', (
    tester,
  ) async {
    debugSetSplashAndroidSdkInt(30);
    await _pumpHeldSplash(tester, brightness: Brightness.light);
    _expectLaunchFrame(
      tester,
      color: splashLaunchLight,
      asset: splashMarkLightAsset,
      extent: splashMarkExtent,
    );
  });

  testWidgets('pre-12 logo centers above the navigation bar', (tester) async {
    debugSetSplashAndroidSdkInt(30);
    holdSplashForHandoff();
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) {
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(
              viewPadding: const EdgeInsets.only(bottom: 80),
              padding: const EdgeInsets.only(bottom: 80),
            ),
            child: child!,
          );
        },
        home: const SplashFade(child: SizedBox.expand()),
      ),
    );
    final overlay = tester.getRect(find.byKey(splashFadeKey));
    final logo = tester.getRect(find.byKey(splashLogoKey));
    expect(logo.center.dx, closeTo(overlay.center.dx, 0.01));
    expect(logo.center.dy, closeTo((overlay.height - 80) / 2, 0.01));
  });

  testWidgets('Android 12 and iOS ignore the navigation bar inset', (
    tester,
  ) async {
    debugSetSplashAndroidSdkInt(34);
    holdSplashForHandoff();
    await tester.pumpWidget(_insetApp());
    final overlay = tester.getRect(find.byKey(splashFadeKey));
    expect(
      tester.getRect(find.byKey(splashLogoKey)).center.dy,
      closeTo(overlay.center.dy, 0.01),
    );

    debugResetSplashHandoff();
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    holdSplashForHandoff();
    await tester.pumpWidget(_insetApp());
    final iosOverlay = tester.getRect(find.byKey(splashFadeKey));
    expect(
      tester.getRect(find.byKey(splashLogoKey)).center.dy,
      closeTo(iosOverlay.center.dy, 0.01),
    );
  });

  testWidgets('iOS first frame uses the centered 192 pt launch image', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await _pumpHeldSplash(tester, brightness: Brightness.dark);
    _expectLaunchFrame(
      tester,
      color: splashLaunchDark,
      asset: splashMarkDarkAsset,
      extent: splashMarkExtent,
    );
  });

  testWidgets('logo and background fade out together', (tester) async {
    await _expectCoverFade(tester, fade: StMotion.medium);
  });

  testWidgets('failed question bank load still fades the splash', (
    tester,
  ) async {
    holdSplashForHandoff();
    await tester.pumpWidget(const ProviderScope(child: SaintsTriviaApp()));
    expect(find.byKey(splashLogoKey), findsOneWidget);
    expect(
      tester.widget<ColoredBox>(find.byKey(splashBackgroundKey)).color,
      splashLaunchLight,
    );

    await removeSplashAfterBundledQuestionBank(
      loadQuestionBank: () async {
        throw Exception('bank failed');
      },
      removeSplash: () {},
    );
    await tester.pump();
    expect(_coverOpacity(tester), closeTo(1, 0.001));
    _expectSharedFade(tester);

    await tester.pump(const Duration(milliseconds: 125));
    final mid = _coverOpacity(tester);
    expect(mid, greaterThan(0));
    expect(mid, lessThan(1));
    _expectSharedFade(tester);

    await tester.pump(const Duration(milliseconds: 125));
    final done = _coverOpacity(tester);
    expect(done == null || done == 0, isTrue);
    if (done == 0) {
      _expectSharedFade(tester);
    }
    await tester.pump(const Duration(microseconds: 1));
    expect(_coverOpacity(tester), isNull);
    expect(find.byKey(splashLogoKey), findsNothing);
    expect(find.byKey(splashBackgroundKey), findsNothing);
  });

  testWidgets('the logo is decoded before the first frame', (tester) async {
    // Image decoding uses real async. The test clock would never fire the
    // warm-up timeout, so run it outside the fake async zone.
    await tester.runAsync(() => warmSplashMark(splashMarkLightAsset));
    holdSplashForHandoff();
    await tester.pumpWidget(const ProviderScope(child: SaintsTriviaApp()));
    final render = tester.renderObject<RenderImage>(find.byKey(splashLogoKey));
    expect(render.image, isNotNull);
    expect(render.image!.width, greaterThan(0));
  });
}

/// Holds the splash, proves the cover stays up until removal, then checks
/// [fade] against the cover's opacity.
Future<void> _expectCoverFade(
  WidgetTester tester, {
  required Duration fade,
  FakeAccessibilityFeatures? features,
}) async {
  if (features != null) {
    tester.platformDispatcher.accessibilityFeaturesTestValue = features;
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }

  holdSplashForHandoff();
  await tester.pumpWidget(const ProviderScope(child: SaintsTriviaApp()));
  expect(_coverOpacity(tester), 1);
  _expectSharedFade(tester);
  final logoAtRest = tester.getRect(find.byKey(splashLogoKey));
  final backgroundAtRest = tester.getRect(find.byKey(splashBackgroundKey));

  await tester.pump(const Duration(milliseconds: 400));
  expect(
    _coverOpacity(tester),
    1,
    reason: 'cover faded before the splash was removed',
  );
  expect(tester.getRect(find.byKey(splashLogoKey)), logoAtRest);

  await removeSplashAfterBundledQuestionBank(
    loadQuestionBank: () async {},
    removeSplash: () {},
  );
  await tester.pump();
  expect(_coverOpacity(tester), closeTo(1, 0.001));
  _expectSharedFade(tester);

  await tester.pump(fade - const Duration(milliseconds: 1));
  final mid = _coverOpacity(tester);
  expect(mid, isNotNull, reason: 'cover was gone before $fade');
  expect(mid, greaterThan(0));
  expect(mid, lessThan(1));
  _expectSharedFade(tester);
  expect(tester.getRect(find.byKey(splashLogoKey)), logoAtRest);
  expect(tester.getRect(find.byKey(splashBackgroundKey)), backgroundAtRest);
  expect(
    tester.widget<FadeTransition>(find.byKey(splashFadeKey)).opacity.value,
    mid,
  );

  await tester.pump(const Duration(milliseconds: 1));
  final done = _coverOpacity(tester);
  expect(
    done == null || done == 0,
    isTrue,
    reason: 'cover still up after $fade (opacity $done)',
  );
  if (done == 0) {
    _expectSharedFade(tester);
  }
  // The simulation reports done only after the duration, so the cover leaves
  // on the following tick. Logo and background go together.
  await tester.pump(const Duration(microseconds: 1));
  expect(_coverOpacity(tester), isNull);
  expect(find.byKey(splashLogoKey), findsNothing);
  expect(find.byKey(splashBackgroundKey), findsNothing);
}

Widget _insetApp() {
  return MaterialApp(
    builder: (context, child) {
      final media = MediaQuery.of(context);
      return MediaQuery(
        data: media.copyWith(
          viewPadding: const EdgeInsets.only(bottom: 80),
          padding: const EdgeInsets.only(bottom: 80),
        ),
        child: child!,
      );
    },
    home: const SplashFade(child: SizedBox.expand()),
  );
}

Future<void> _pumpHeldSplash(
  WidgetTester tester, {
  required Brightness brightness,
}) async {
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  holdSplashForHandoff();
  await tester.pumpWidget(const ProviderScope(child: SaintsTriviaApp()));
}

void _expectLaunchFrame(
  WidgetTester tester, {
  required Color color,
  required String asset,
  required double extent,
}) {
  final background = tester.widget<ColoredBox>(find.byKey(splashBackgroundKey));
  expect(background.color, color);

  final logo = tester.widget<Image>(find.byKey(splashLogoKey));
  expect(logo.image, isA<AssetImage>());
  expect((logo.image as AssetImage).assetName, asset);
  expect(logo.width, extent);
  expect(logo.height, extent);

  final overlay = tester.getRect(find.byKey(splashFadeKey));
  final logoRect = tester.getRect(find.byKey(splashLogoKey));
  final backgroundRect = tester.getRect(find.byKey(splashBackgroundKey));
  expect(backgroundRect, overlay);
  expect(logoRect.width, extent);
  expect(logoRect.height, extent);
  expect(logoRect.center.dx, closeTo(overlay.center.dx, 0.01));
  expect(logoRect.center.dy, closeTo(overlay.center.dy, 0.01));
  _expectSharedFade(tester);
  expect(_coverOpacity(tester), 1);
}

/// Logo and background are painted by the one splash fade, not two.
void _expectSharedFade(WidgetTester tester) {
  final fade = find.byKey(splashFadeKey);
  expect(fade, findsOneWidget);
  expect(
    find.descendant(of: fade, matching: find.byKey(splashBackgroundKey)),
    findsOneWidget,
  );
  expect(
    find.descendant(of: fade, matching: find.byKey(splashLogoKey)),
    findsOneWidget,
  );
  expect(
    find.descendant(of: fade, matching: find.byType(FadeTransition)),
    findsNothing,
  );
}

/// Opacity of the splash cover, or null once the fade has removed it.
double? _coverOpacity(WidgetTester tester) {
  final finder = find.byKey(splashFadeKey);
  if (finder.evaluate().isEmpty) return null;
  return tester.widget<FadeTransition>(finder).opacity.value;
}
