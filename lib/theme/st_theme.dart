// Scripture Trivia — design tokens (v1). Material 3, Flutter 3.22+.
// Fonts: Source Serif 4 (SIL OFL) bundled for display/headline/title + question prompts.
// UI text uses the platform default (SF Pro on iOS, Roboto on Android).
import 'package:cupertino_ui/cupertino_ui.dart'
    show CupertinoPageTransitionsBuilder;
import 'package:material_ui/material_ui.dart';

abstract final class StSpace {
  // 4-pt grid
  static const xxs = 4.0,
      xs = 8.0,
      sm = 12.0,
      md = 16.0,
      lg = 20.0,
      xl = 24.0,
      xxl = 32.0,
      xxxl = 40.0;
  static const screenH = 20.0; // horizontal screen padding
  static const minTap = 48.0; // Android min target (iOS 44)
  static const answerMinHeight = 56.0;
}

abstract final class StRadius {
  static const sm = Radius.circular(8); // chips, tags
  static const md = Radius.circular(12); // inputs, answer buttons
  static const lg = Radius.circular(16); // cards, feedback panel top
  static const xl = Radius.circular(24); // sheets, hero cards
  static const full = Radius.circular(999);
}

abstract final class StMotion {
  static const fast = Duration(milliseconds: 150); // option state change
  static const medium = Duration(milliseconds: 250); // panel slide, progress
  static const slow = Duration(
    milliseconds: 400,
  ); // results ring count-up start
  static const emphasized = Curves.easeOutCubic;
  static const standard = Curves.easeInOutCubic;
  // Respect MediaQuery.disableAnimations: swap slides for fades, skip count-up & confetti.
}

const _serif = 'SourceSerif4';

/// Finite minimum so a button can sit in a [Row]. [Size.fromHeight] is infinite
/// in width and throws there.
const _buttonMinSize = Size(64, 52);

TextTheme _textTheme(Color on) => TextTheme(
  displaySmall: TextStyle(
    fontFamily: _serif,
    fontSize: 36,
    height: 44 / 36,
    fontWeight: FontWeight.w600,
    color: on,
  ),
  headlineMedium: TextStyle(
    fontFamily: _serif,
    fontSize: 28,
    height: 36 / 28,
    fontWeight: FontWeight.w600,
    color: on,
  ),
  headlineSmall: TextStyle(
    fontFamily: _serif,
    fontSize: 24,
    height: 32 / 24,
    fontWeight: FontWeight.w600,
    color: on,
  ),
  titleLarge: TextStyle(
    fontFamily: _serif,
    fontSize: 22,
    height: 30 / 22,
    fontWeight: FontWeight.w600,
    color: on,
  ), // question prompt
  titleMedium: const TextStyle(
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w600,
  ),
  bodyLarge: const TextStyle(
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
  ),
  bodyMedium: const TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
  ),
  labelLarge: const TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  ),
  labelMedium: const TextStyle(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.4,
  ),
);

const lightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFF1F3A5F),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFD6E3F5),
  onPrimaryContainer: Color(0xFF0B2541),
  secondary: Color(0xFF8A6A1F),
  onSecondary: Color(0xFFFFFFFF),
  secondaryContainer: Color(0xFFF5E7C4),
  onSecondaryContainer: Color(0xFF3A2C05),
  tertiary: Color(0xFF3F6E4E),
  onTertiary: Color(0xFFFFFFFF),
  error: Color(0xFFB3261E),
  onError: Color(0xFFFFFFFF),
  errorContainer: Color(0xFFFBE9E7),
  onErrorContainer: Color(0xFF8C1D18),
  surface: Color(0xFFFBF8F2),
  onSurface: Color(0xFF1C1B1F),
  onSurfaceVariant: Color(0xFF5E5A52),
  surfaceContainerLowest: Color(0xFFFFFFFF),
  surfaceContainerLow: Color(0xFFF6F1E7),
  surfaceContainer: Color(0xFFF0EADF),
  surfaceContainerHigh: Color(0xFFEAE3D6),
  surfaceContainerHighest: Color(0xFFE3DBCC),
  outline: Color(0xFF8C857A),
  outlineVariant: Color(0xFFDDD5C7),
);

const darkScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFFA9C7F0),
  onPrimary: Color(0xFF0B2541),
  primaryContainer: Color(0xFF23446B),
  onPrimaryContainer: Color(0xFFD6E3F5),
  secondary: Color(0xFFE3B95C),
  onSecondary: Color(0xFF3A2C05),
  secondaryContainer: Color(0xFF5A4410),
  onSecondaryContainer: Color(0xFFF5E7C4),
  tertiary: Color(0xFF9FD3AF),
  onTertiary: Color(0xFF0B3A1F),
  error: Color(0xFFF2B8B5),
  onError: Color(0xFF601410),
  errorContainer: Color(0xFF4A1612),
  onErrorContainer: Color(0xFFFFDAD6),
  surface: Color(0xFF0F1620),
  onSurface: Color(0xFFE6E1D8),
  onSurfaceVariant: Color(0xFFB9B2A6),
  surfaceContainerLowest: Color(0xFF0A1018),
  surfaceContainerLow: Color(0xFF141C27),
  surfaceContainer: Color(0xFF18212D),
  surfaceContainerHigh: Color(0xFF212B38),
  surfaceContainerHighest: Color(0xFF2B3644),
  outline: Color(0xFF8A8F98),
  outlineVariant: Color(0xFF343E4B),
);

enum Volume {
  oldTestament,
  newTestament,
  bookOfMormon,
  doctrineAndCovenants,
  pearlOfGreatPrice,
}

@immutable
class StColors extends ThemeExtension<StColors> {
  const StColors({
    required this.correct,
    required this.onCorrect,
    required this.correctContainer,
    required this.onCorrectContainer,
    required this.wrong,
    required this.onWrong,
    required this.wrongContainer,
    required this.onWrongContainer,
    required this.gold,
    required this.volume,
  });
  final Color correct, onCorrect, correctContainer, onCorrectContainer;
  final Color wrong, onWrong, wrongContainer, onWrongContainer;
  final Color gold; // decorative only (stars, ring, streak flame) — never body text on light
  final Map<Volume, Color> volume;

  static const light = StColors(
    correct: Color(0xFF2E7D4F),
    onCorrect: Color(0xFFFFFFFF),
    correctContainer: Color(0xFFE3F2E8),
    onCorrectContainer: Color(0xFF1E5E3A),
    wrong: Color(0xFFB3261E),
    onWrong: Color(0xFFFFFFFF),
    wrongContainer: Color(0xFFFBE9E7),
    onWrongContainer: Color(0xFF8C1D18),
    gold: Color(0xFFB8862B),
    volume: {
      Volume.oldTestament: Color(0xFF9A4F2E),
      Volume.newTestament: Color(0xFF2F5F8F),
      Volume.bookOfMormon: Color(0xFF7A5A12),
      Volume.doctrineAndCovenants: Color(0xFF3F6E4E),
      Volume.pearlOfGreatPrice: Color(0xFF5C4A8A),
    },
  );
  static const dark = StColors(
    correct: Color(0xFF7FD6A0),
    onCorrect: Color(0xFF0B3A1F),
    correctContainer: Color(0xFF173826),
    onCorrectContainer: Color(0xFFA8E8BE),
    wrong: Color(0xFFF2B8B5),
    onWrong: Color(0xFF601410),
    wrongContainer: Color(0xFF4A1612),
    onWrongContainer: Color(0xFFFFDAD6),
    gold: Color(0xFFE3B95C),
    volume: {
      Volume.oldTestament: Color(0xFFF0B496),
      Volume.newTestament: Color(0xFFA9C7F0),
      Volume.bookOfMormon: Color(0xFFE3C878),
      Volume.doctrineAndCovenants: Color(0xFF9FD3AF),
      Volume.pearlOfGreatPrice: Color(0xFFC9B8F0),
    },
  );

  @override
  StColors copyWith({Color? correct, Color? wrong}) => StColors(
    correct: correct ?? this.correct,
    onCorrect: onCorrect,
    correctContainer: correctContainer,
    onCorrectContainer: onCorrectContainer,
    wrong: wrong ?? this.wrong,
    onWrong: onWrong,
    wrongContainer: wrongContainer,
    onWrongContainer: onWrongContainer,
    gold: gold,
    volume: volume,
  );

  @override
  StColors lerp(StColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return StColors(
      correct: l(correct, other.correct),
      onCorrect: l(onCorrect, other.onCorrect),
      correctContainer: l(correctContainer, other.correctContainer),
      onCorrectContainer: l(onCorrectContainer, other.onCorrectContainer),
      wrong: l(wrong, other.wrong),
      onWrong: l(onWrong, other.onWrong),
      wrongContainer: l(wrongContainer, other.wrongContainer),
      onWrongContainer: l(onWrongContainer, other.onWrongContainer),
      gold: l(gold, other.gold),
      volume: {
        for (final v in Volume.values) v: l(volume[v]!, other.volume[v]!),
      },
    );
  }
}

ThemeData buildTheme(Brightness b) {
  final scheme = b == Brightness.light ? lightScheme : darkScheme;
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    textTheme: _textTheme(scheme.onSurface),
    extensions: [b == Brightness.light ? StColors.light : StColors.dark],
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 1,
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLowest,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(StRadius.lg),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    // All four button types are 52 tall. Width is finite (64) so they can
    // share a Row. Segmented controls and icon buttons stay at the 48 dp
    // minimum, which also covers the 44 pt iOS target.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: _buttonMinSize,
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: _buttonMinSize,
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: _buttonMinSize,
        shape: const StadiumBorder(),
        side: BorderSide(color: scheme.outline),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: _buttonMinSize,
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        minimumSize: const Size(StSpace.minTap, StSpace.minTap),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size.square(StSpace.minTap),
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
    ),
    chipTheme: const ChipThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(StRadius.sm),
      ),
    ),
    checkboxTheme: const CheckboxThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(4)),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.surfaceContainerHigh,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: StRadius.xl),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}

// Usage:
// MaterialApp.router(theme: buildTheme(Brightness.light), darkTheme: buildTheme(Brightness.dark), themeMode: settings.themeMode, ...)
// final st = Theme.of(context).extension<StColors>()!;
