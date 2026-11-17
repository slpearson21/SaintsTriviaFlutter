import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'pump_app.dart';

void main() {
  testWidgets('every route renders and is reachable', (tester) async {
    await pumpApp(tester);
    expect(find.text('Scripture Trivia'), findsOneWidget);
    expect(find.text('Start a game'), findsOneWidget);

    await tester.tap(find.text('Start a game'));
    await tester.pumpAndSettle();
    expect(find.text('New game'), findsOneWidget);

    await tester.tap(find.textContaining('Start game'));
    await tester.pumpAndSettle();
    expect(find.text('Question'), findsOneWidget);

    await tester.tap(find.text('See results'));
    await tester.pumpAndSettle();
    expect(find.text('Results'), findsOneWidget);

    await tester.tap(find.text('Review answers'));
    await tester.pumpAndSettle();
    expect(find.text('Review answers'), findsOneWidget);
    expect(find.text('Back to results'), findsOneWidget);

    await tester.tap(find.text('Back to results'));
    await tester.pumpAndSettle();
    expect(find.text('Results'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Scripture Trivia'), findsOneWidget);

    await tester.tap(find.byTooltip('Stats'));
    await tester.pumpAndSettle();
    expect(find.text('Stats'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Scripture Trivia'), findsOneWidget);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('back from results lands on home, not the game', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Start a game'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Start game'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('See results'));
    await tester.pumpAndSettle();
    expect(find.text('Results'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Scripture Trivia'), findsOneWidget);
    expect(find.text('Question'), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('back from setup after new game lands on home', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Start a game'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Start game'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('See results'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New game'));
    await tester.pumpAndSettle();
    expect(find.text('Select all'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Scripture Trivia'), findsOneWidget);
    expect(find.text('Select all'), findsNothing);
    expect(find.text('Question'), findsNothing);
  });
}
