import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saints_trivia_flutter/layout/platform_style.dart';
import 'package:saints_trivia_flutter/layout/text_scale.dart';
import 'package:saints_trivia_flutter/theme/st_theme.dart';

void main() {
  testWidgets('every platform maps to Cupertino or Material', (tester) async {
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    for (final platform in TargetPlatform.values) {
      final cupertino =
          platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
      expect(isCupertinoPlatform(platform), cupertino, reason: platform.name);

      debugDefaultTargetPlatformOverride = platform;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: const SizedBox.shrink(),
        ),
      );
      final context = tester.element(find.byType(SizedBox));
      expect(usesMaterialChrome(), isNot(cupertino), reason: platform.name);
      expect(
        minTapTarget(context),
        cupertino ? 44 : StSpace.minTap,
        reason: platform.name,
      );
    }
  });

  testWidgets('an iOS theme keeps the 44 pt target on a Material device', (
    tester,
  ) async {
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: const SizedBox.shrink(),
      ),
    );

    final context = tester.element(find.byType(SizedBox));
    expect(usesMaterialChrome(), isTrue);
    expect(minTapTarget(context), 44);
  });
}
