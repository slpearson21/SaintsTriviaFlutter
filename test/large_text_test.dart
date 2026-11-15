import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saints_trivia_flutter/app.dart';
import 'package:saints_trivia_flutter/layout/adaptive_actions.dart';
import 'package:saints_trivia_flutter/layout/question_progress.dart';
import 'package:saints_trivia_flutter/layout/screen_body.dart';
import 'package:saints_trivia_flutter/layout/st_icon.dart';
import 'package:saints_trivia_flutter/layout/text_scale.dart';
import 'package:saints_trivia_flutter/routing/app_router.dart';
import 'package:saints_trivia_flutter/routing/routes.dart';
import 'package:saints_trivia_flutter/theme/st_theme.dart';

const _spoken = 'Question 7 of 10';

Future<void> _pumpScaled(
  WidgetTester tester, {
  required double scale,
  required Widget home,
  Size surface = const Size(360, 640),
}) async {
  await tester.binding.setSurfaceSize(surface);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(Brightness.light),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        );
      },
      home: home,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('large text starts at scale 1.5', (tester) async {
    late bool atBoundary;
    late bool belowBoundary;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Column(
              children: [
                MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(1.5)),
                  child: Builder(
                    builder: (context) {
                      atBoundary = isLargeText(context);
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(1.49)),
                  child: Builder(
                    builder: (context) {
                      belowBoundary = isLargeText(context);
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );

    expect(atBoundary, isTrue);
    expect(belowBoundary, isFalse);
  });

  testWidgets('screen body scrolls at text scale 2 without overflow', (
    tester,
  ) async {
    await _pumpScaled(
      tester,
      scale: 2,
      home: Scaffold(
        body: ScreenBody(
          primary: const PrimaryButton(label: 'Start game', onPressed: _noop),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < 40; i++)
                Text('Line $i of placeholder content that wraps on a phone'),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final button = find.text('Start game');
    expect(button, findsOneWidget);
    final pinned = tester.getRect(button);
    expect(pinned.top, greaterThanOrEqualTo(0));
    expect(pinned.bottom, lessThanOrEqualTo(640));

    final lastLine = find.textContaining('Line 39');
    expect(tester.getRect(lastLine).top, greaterThan(640));

    await tester.scrollUntilVisible(
      lastLine,
      400,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(tester.getRect(button), pinned);
    expect(tester.getRect(lastLine).bottom, lessThanOrEqualTo(pinned.top));
  });

  testWidgets('side-by-side actions stack when text is large', (tester) async {
    Widget actions() {
      return Scaffold(
        body: AdaptiveActions(
          children: [
            OutlinedButton(onPressed: () {}, child: const Text('New game')),
            OutlinedButton(
              onPressed: () {},
              child: const Text('Review answers'),
            ),
          ],
        ),
      );
    }

    Rect button(String label) {
      return tester.getRect(find.widgetWithText(OutlinedButton, label));
    }

    await _pumpScaled(tester, scale: 1, home: actions());
    final first = button('New game');
    final second = button('Review answers');
    expect(second.left, greaterThanOrEqualTo(first.right - 1));
    expect(second.center.dy, closeTo(first.center.dy, 1));

    await _pumpScaled(tester, scale: 2, home: actions());
    final stackedFirst = button('New game');
    final stackedSecond = button('Review answers');
    expect(stackedSecond.top, greaterThanOrEqualTo(stackedFirst.bottom - 1));
    expect(stackedFirst.left, closeTo(stackedSecond.left, 1));
  });

  testWidgets(
    'icons do not scale with text and hit targets stay large enough',
    (tester) async {
      await _pumpScaled(
        tester,
        scale: 2,
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: IconButton(
                onPressed: () {},
                style: IconButton.styleFrom(
                  minimumSize: Size.square(minTapTarget(context)),
                  tapTargetSize: MaterialTapTargetSize.padded,
                ),
                icon: const StIcon(Icons.close),
              ),
            );
          },
        ),
      );

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.applyTextScaling, isFalse);
      expect(icon.size, 24);
      expect(tester.getSize(find.byType(Icon)), const Size(24, 24));
      expect(
        tester.getSize(find.byType(IconButton)).shortestSide,
        greaterThanOrEqualTo(StSpace.minTap),
      );
    },
  );

  testWidgets('iOS hit target is at least 44', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: IconButton(
                onPressed: () {},
                style: IconButton.styleFrom(
                  minimumSize: Size.square(minTapTarget(context)),
                ),
                icon: const StIcon(Icons.star, size: 16),
              ),
            );
          },
        ),
      ),
    );

    expect(minTapTarget(tester.element(find.byType(IconButton))), 44);
    expect(
      tester.getSize(find.byType(IconButton)).shortestSide,
      greaterThanOrEqualTo(44),
    );
    expect(tester.widget<Icon>(find.byType(Icon)).size, 16);
  });

  testWidgets('progress counter shortens at scale 2 and keeps its label', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await _pumpScaled(
        tester,
        scale: 2,
        home: const Scaffold(body: QuestionProgress(current: 7, total: 10)),
      );
      expect(find.text('7 / 10'), findsOneWidget);
      expect(find.text(_spoken), findsNothing);
      expect(find.bySemanticsLabel(_spoken), findsOneWidget);

      await _pumpScaled(
        tester,
        scale: 1,
        home: const Scaffold(body: QuestionProgress(current: 7, total: 10)),
      );
      expect(find.text(_spoken), findsOneWidget);
      expect(find.text('7 / 10'), findsNothing);
      expect(find.bySemanticsLabel(_spoken), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
    'primary and outlined buttons are at least 52, text buttons at least 48',
    (tester) async {
      const scales = <double>[1, 2];
      for (final brightness in Brightness.values) {
        for (final scale in scales) {
          await tester.pumpWidget(
            MaterialApp(
              theme: buildTheme(brightness),
              builder: (context, child) {
                return MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                );
              },
              home: const Scaffold(
                body: SingleChildScrollView(
                  child: Column(
                    children: [
                      FilledButton(onPressed: _noop, child: Text('Filled')),
                      ElevatedButton(onPressed: _noop, child: Text('Elevated')),
                      OutlinedButton(onPressed: _noop, child: Text('Outlined')),
                      TextButton(onPressed: _noop, child: Text('Text')),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          expect(
            tester.getSize(find.widgetWithText(FilledButton, 'Filled')).height,
            greaterThanOrEqualTo(52),
          );
          expect(
            tester
                .getSize(find.widgetWithText(ElevatedButton, 'Elevated'))
                .height,
            greaterThanOrEqualTo(52),
          );
          expect(
            tester
                .getSize(find.widgetWithText(OutlinedButton, 'Outlined'))
                .height,
            greaterThanOrEqualTo(52),
          );
          expect(
            tester.getSize(find.widgetWithText(TextButton, 'Text')).height,
            greaterThanOrEqualTo(StSpace.minTap),
          );
        }
      }
    },
  );

  testWidgets('every route renders at text scale 1 and 2 without overflow', (
    tester,
  ) async {
    const routes = <String>[
      AppRoutes.home,
      AppRoutes.setup,
      AppRoutes.game,
      AppRoutes.results,
      AppRoutes.review,
      AppRoutes.stats,
      AppRoutes.settings,
    ];

    for (final scale in <double>[1, 2]) {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      tester.platformDispatcher.textScaleFactorTestValue = scale;

      final container = ProviderContainer();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const SaintsTriviaApp(),
        ),
      );
      await tester.pumpAndSettle();
      final router = container.read(appRouterProvider);

      for (final path in routes) {
        router.go(path);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$path at $scale');
        if (scale == 2 && path == AppRoutes.game) {
          expect(find.text('7 / 10'), findsOneWidget);
        }
      }

      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    }

    tester.platformDispatcher.clearTextScaleFactorTestValue();
    await tester.binding.setSurfaceSize(null);
  });
}

void _noop() {}
