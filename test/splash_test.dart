import 'dart:async';

import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saints_trivia_flutter/main.dart';

void main() {
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
}
