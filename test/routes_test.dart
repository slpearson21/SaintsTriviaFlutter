import 'package:flutter_test/flutter_test.dart';

import 'pump_app.dart';

void main() {
  testWidgets('every route renders and is reachable', (tester) async {
    await pumpApp(tester);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Start a game'), findsOneWidget);

    await tester.tap(find.text('Start a game'));
    await tester.pumpAndSettle();
    expect(find.text('Game setup'), findsOneWidget);

    await tester.tap(find.text('Start game'));
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
    expect(find.text('Home'), findsOneWidget);

    await tester.tap(find.text('Stats'));
    await tester.pumpAndSettle();
    expect(find.text('Stats'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
  });
}
