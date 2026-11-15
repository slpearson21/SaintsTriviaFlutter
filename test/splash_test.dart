import 'dart:async';

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

  await tester.pump(const Duration(milliseconds: 400));
  expect(
    _coverOpacity(tester),
    1,
    reason: 'cover faded before the splash was removed',
  );

  await removeSplashAfterBundledQuestionBank(
    loadQuestionBank: () async {},
    removeSplash: () {},
  );
  await tester.pump();
  expect(_coverOpacity(tester), closeTo(1, 0.001));

  await tester.pump(fade - const Duration(milliseconds: 1));
  final mid = _coverOpacity(tester);
  expect(mid, isNotNull, reason: 'cover was gone before $fade');
  expect(mid, greaterThan(0));
  expect(mid, lessThan(1));

  await tester.pump(const Duration(milliseconds: 1));
  final done = _coverOpacity(tester);
  expect(
    done == null || done == 0,
    isTrue,
    reason: 'cover still up after $fade (opacity $done)',
  );
}

/// Opacity of the splash cover, or null once the fade has removed it.
double? _coverOpacity(WidgetTester tester) {
  final finder = find.byKey(splashFadeKey);
  if (finder.evaluate().isEmpty) return null;
  return tester.widget<FadeTransition>(finder).opacity.value;
}
