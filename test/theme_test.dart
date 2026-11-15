import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saints_trivia_flutter/theme/st_theme.dart';

import 'pump_app.dart';

void main() {
  testWidgets('light theme provides StColors and the serif display face', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await pumpApp(tester);

    final theme = Theme.of(tester.element(find.text('Home')));
    final colors = theme.extension<StColors>();
    expect(theme.brightness, Brightness.light);
    expect(colors, isNotNull);
    expect(colors!.correct, const Color(0xFF2E7D4F));
    expect(colors.onCorrect, const Color(0xFFFFFFFF));
    expect(colors.correctContainer, const Color(0xFFE3F2E8));
    expect(colors.onCorrectContainer, const Color(0xFF1E5E3A));
    expect(colors.wrong, const Color(0xFFB3261E));
    expect(colors.gold, const Color(0xFFB8862B));
    expect(colors.volume[Volume.bookOfMormon], const Color(0xFF7A5A12));
    expect(colors.volume[Volume.pearlOfGreatPrice], const Color(0xFF5C4A8A));
    expect(theme.colorScheme.primary, const Color(0xFF1F3A5F));
    expect(theme.colorScheme.surface, const Color(0xFFFBF8F2));
    expect(theme.textTheme.displaySmall?.fontFamily, 'SourceSerif4');
    expect(theme.textTheme.headlineMedium?.fontFamily, 'SourceSerif4');
    expect(theme.textTheme.titleLarge?.fontFamily, 'SourceSerif4');
    expect(theme.textTheme.titleLarge?.fontWeight, FontWeight.w600);
    expect(theme.textTheme.bodyLarge?.fontFamily, isNot('SourceSerif4'));
    expect(theme.textTheme.labelLarge?.fontFamily, isNot('SourceSerif4'));
  });

  testWidgets('dark theme provides StColors', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await pumpApp(tester);

    final theme = Theme.of(tester.element(find.text('Home')));
    final colors = theme.extension<StColors>();
    expect(theme.brightness, Brightness.dark);
    expect(colors, isNotNull);
    expect(colors!.correct, const Color(0xFF7FD6A0));
    expect(colors.onCorrect, const Color(0xFF0B3A1F));
    expect(colors.correctContainer, const Color(0xFF173826));
    expect(colors.onCorrectContainer, const Color(0xFFA8E8BE));
    expect(colors.wrong, const Color(0xFFF2B8B5));
    expect(colors.wrongContainer, const Color(0xFF4A1612));
    expect(colors.onWrongContainer, const Color(0xFFFFDAD6));
    expect(colors.gold, const Color(0xFFE3B95C));
    expect(colors.volume[Volume.oldTestament], const Color(0xFFF0B496));
    expect(colors.volume[Volume.doctrineAndCovenants], const Color(0xFF9FD3AF));
    expect(theme.colorScheme.primary, const Color(0xFFA9C7F0));
    expect(theme.colorScheme.surface, const Color(0xFF0F1620));
    expect(theme.textTheme.headlineSmall?.fontFamily, 'SourceSerif4');
  });
}
