import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saints_trivia_flutter/game/game_providers.dart';

import 'pump_app.dart';

Future<void> _openGame(WidgetTester tester) async {
  await pumpApp(
    tester,
    overrides: [gameRandomProvider.overrideWith((ref) => Random(1))],
  );
  await tester.tap(find.text('Start a game'));
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining('Start game'));
  await tester.pumpAndSettle();
  expect(find.text('Question'), findsOneWidget);
}

void main() {
  testWidgets('system back on /game opens the quit dialog', (tester) async {
    await _openGame(tester);

    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(handled, isTrue);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Quit'), findsOneWidget);
    expect(find.text('Keep playing'), findsOneWidget);
    expect(find.text('Question'), findsOneWidget);

    await tester.tap(find.text('Keep playing'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Question'), findsOneWidget);
  });

  testWidgets('close on /game opens the quit dialog', (tester) async {
    await _openGame(tester);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(find.text('Quit'), findsOneWidget);
    expect(find.text('Keep playing'), findsOneWidget);

    await tester.tap(find.text('Quit'));
    await tester.pumpAndSettle();

    expect(find.text('Scripture Trivia'), findsOneWidget);
    expect(find.text('Question'), findsNothing);
  });
}
