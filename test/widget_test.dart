import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saints_trivia_flutter/main.dart';

void main() {
  testWidgets('volume picker renders five scripture checkboxes', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Saints Trivia'), findsOneWidget);
    expect(find.text('Pick Your Trivia'), findsOneWidget);
    expect(find.text('GO!'), findsOneWidget);

    expect(find.byType(CheckboxListTile), findsNWidgets(5));
    expect(find.text('Old Testament'), findsOneWidget);
    expect(find.text('New Testament'), findsOneWidget);
    expect(find.text('Book of Mormon'), findsOneWidget);
    expect(find.text('Doctrine and Covenants'), findsOneWidget);
    expect(find.text('Pearl of Great Price'), findsOneWidget);
  });
}
