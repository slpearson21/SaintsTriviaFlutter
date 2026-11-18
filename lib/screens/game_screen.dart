import 'dart:async';
import 'dart:math' show max, min;

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../data/questions/question_bank.dart';
import '../data/questions/question_bank_provider.dart';
import '../data/questions/scripture_volume.dart';
import '../game/game_engine.dart';
import '../game/game_providers.dart';
import '../layout/question_progress.dart';
import '../layout/screen_body.dart';
import '../layout/st_icon.dart';
import '../layout/text_scale.dart';
import '../progress/home_snapshot.dart';
import '../report/report_sheet.dart';
import '../report/reported_questions_provider.dart';
import '../routing/routes.dart';
import '../scripture/scripture_reference_chip.dart';
import '../theme/st_theme.dart';
import 'content_load_error_screen.dart';
import 'no_questions_screen.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key, this.settings});

  /// Resolved by the game route. Null only if the route is built without
  /// going through that redirect.
  final LastGameSettings? settings;

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  bool _confirming = false;
  bool _locked = false;
  bool _showingFeedback = false;

  /// Question ids of the deal this screen is already showing.
  ///
  /// Answering the last question marks the session complete, which no longer
  /// matches [widget.settings]. That deal is still the one on screen, so it
  /// must not be hidden or replaced while its feedback is up.
  List<String>? _presentedQuestionIds;

  ProviderSubscription<AsyncValue<QuestionBank>>? _bankSubscription;

  @override
  void initState() {
    super.initState();
    // The splash starts the bank load. A restore can mount this screen
    // while that future is still running. Listen only when the load has
    // already started, so this screen deals when it arrives and does not
    // open a second load of its own.
    if (ref.read(questionBankProvider.exists)) {
      _bankSubscription = ref.listenManual(questionBankProvider, (
        previous,
        next,
      ) {
        if (!next.hasValue) return;
        _dealIfNeeded();
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _dealIfNeeded());
  }

  @override
  void didUpdateWidget(GameScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings == widget.settings) return;
    _presentedQuestionIds = null;
    _locked = false;
    _showingFeedback = false;
    WidgetsBinding.instance.addPostFrameCallback((_) => _dealIfNeeded());
  }

  @override
  void dispose() {
    _bankSubscription?.close();
    super.dispose();
  }

  /// Deals only when the current session is not already this screen's game.
  ///
  /// Setup calls [GameController.start] before it opens `/game`, so the first
  /// frame here is the new deal. Dealing again would shuffle a second game
  /// and, if it happened a frame later, flash the finished one.
  void _dealIfNeeded() {
    if (!mounted) return;
    final settings = widget.settings;
    if (settings == null) return;
    final current = ref.read(gameControllerProvider);
    if (current != null && _isPresented(current)) return;
    // An empty deal still matches. Build shows E2; dealing again would
    // only shuffle another empty list.
    if (current != null && _sessionMatches(current, settings)) return;
    // Reading the provider when it does not exist starts the 5s load.
    // The splash is what starts it. This screen only deals a bank that
    // is already loading or already loaded.
    if (!ref.read(questionBankProvider.exists)) return;
    final bank = ref.read(questionBankProvider).asData?.value;
    if (bank == null) return;
    _locked = false;
    _showingFeedback = false;
    _presentedQuestionIds = null;
    ref
        .read(gameControllerProvider.notifier)
        .start(
          bank: bank,
          volumes: settings.volumes,
          requestedCount: settings.questionCount,
        );
  }

  bool _isPresented(GameSession session) {
    final ids = _presentedQuestionIds;
    if (ids == null || ids.length != session.questions.length) return false;
    for (var i = 0; i < ids.length; i++) {
      if (ids[i] != session.questions[i].id) return false;
    }
    return true;
  }

  void _choose(int index) {
    if (_locked || _showingFeedback) return;
    final session = ref.read(gameControllerProvider);
    if (session == null || session.isComplete) return;
    final current = session.currentIndex;
    if (current < 0 || current >= session.questions.length) return;
    // Lock before the engine call so a second tap in this same turn cannot
    // score another option.
    _locked = true;
    final question = session.questions[current];
    final correct = index == question.answerIndex;
    ref.read(gameControllerProvider.notifier).answer(index);
    // One announcement. The sheet also shows the result, without a live
    // region, so a screen reader does not speak it a second time.
    final message = correct
        ? 'Correct'
        : 'Not quite. The answer is ${question.answer}.';
    setState(() => _showingFeedback = true);
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        message,
        Directionality.of(context),
      ),
    );
    if (ref.read(hapticsEnabledProvider)) {
      unawaited(
        correct ? HapticFeedback.lightImpact() : HapticFeedback.heavyImpact(),
      );
    }
    playAnswerSound(
      enabled: ref.read(soundEffectsEnabledProvider),
      correct: correct,
    );
  }

  void _next() {
    if (!_showingFeedback) return;
    final session = ref.read(gameControllerProvider);
    if (session == null) return;
    if (session.isComplete) {
      _showingFeedback = false;
      context.go(AppRoutes.results);
      return;
    }
    setState(() {
      _showingFeedback = false;
      _locked = false;
    });
  }

  Future<void> _requestQuit() async {
    if (_confirming || !mounted) return;
    _confirming = true;
    final quit = await showQuitGameDialog(context);
    _confirming = false;
    if (!mounted) return;
    if (!quit) return;
    ref.read(gameControllerProvider.notifier).discard();
    if (!mounted) return;
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    // Same rule as setup: watch a load that already started. Watching an
    // untouched provider would open the 5s timeout from this screen.
    final bankAsync = ref.read(questionBankProvider.exists)
        ? ref.watch(questionBankProvider)
        : const AsyncLoading<QuestionBank>();
    final session = ref.watch(gameControllerProvider);
    final showExplanations = ref.watch(showExplanationsProvider);
    final settings = widget.settings;
    final matches =
        session != null &&
        settings != null &&
        _sessionMatches(session, settings);
    if (matches && session.questions.isNotEmpty) {
      _presentedQuestionIds = [
        for (final question in session.questions) question.id,
      ];
    }
    final showingThisDeal = session != null && _isPresented(session);
    // A finished game stays in the controller until the next deal. Hide it
    // until this route's settings are the ones on screen. The deal this
    // screen is already presenting stays up, including its last answer.
    final hideStale =
        session != null && settings != null && !matches && !showingThisDeal;
    final playing =
        session != null && !hideStale && session.questions.isNotEmpty;
    final emptyDeal = session != null && matches && session.questions.isEmpty;
    // A deal with nothing in it is E2. A bank that never arrived, while this
    // screen is still waiting to deal, is E1. Neither path builds a question.
    if (emptyDeal) return NoQuestionsScreen(settings: settings);
    if (!playing && bankAsync.hasError) {
      return const ContentLoadErrorView(showNewGameBar: true);
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        unawaited(_requestQuit());
      },
      child: _IosBackSwipe(
        onQuit: () => unawaited(_requestQuit()),
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            toolbarHeight: _toolbarHeight(context),
            leading: IconButton(
              tooltip: 'Close',
              onPressed: () => unawaited(_requestQuit()),
              style: IconButton.styleFrom(
                minimumSize: const Size.square(StSpace.minTap),
                tapTargetSize: MaterialTapTargetSize.padded,
              ),
              icon: const StIcon(Icons.close),
            ),
            title: Text(hideStale ? 'Preparing' : 'Question', maxLines: 2),
          ),
          body: playing
              ? _QuestionBody(
                  session: session,
                  showingFeedback: _showingFeedback,
                  showExplanations: showExplanations,
                  onChoose: _choose,
                  onNext: _next,
                )
              : const SafeArea(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: StSpace.screenH,
                      vertical: StSpace.md,
                    ),
                    child: _PreparingBody(),
                  ),
                ),
        ),
      ),
    );
  }
}

/// iOS and macOS use a Cupertino alert. Android and the other Material
/// platforms use a Material 3 alert.
///
/// [defaultTargetPlatform] is read at the call, not [ThemeData.platform].
/// The app themes are built once, so a test that overrides the platform
/// after that would otherwise keep the theme's original platform.
bool _usesCupertino() {
  return switch (defaultTargetPlatform) {
    TargetPlatform.iOS || TargetPlatform.macOS => true,
    TargetPlatform.android ||
    TargetPlatform.fuchsia ||
    TargetPlatform.linux ||
    TargetPlatform.windows => false,
  };
}

Future<bool> showQuitGameDialog(BuildContext context) async {
  final quit = await showDialog<bool>(
    context: context,
    builder: (context) {
      const title = Text('Quit game?');
      const message = Text('Your progress in this game will be lost.');
      if (_usesCupertino()) {
        return CupertinoAlertDialog(
          title: title,
          content: message,
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep playing'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Quit'),
            ),
          ],
        );
      }
      return AlertDialog(
        title: title,
        content: message,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep playing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Quit'),
          ),
        ],
      );
    },
  );
  return quit ?? false;
}

/// True when [session] was dealt for [settings] and is still in progress.
///
/// Volume order does not matter. A finished game does not match: Play again
/// opens `/game` with the same settings and has to deal a new game rather
/// than reopen the one that just ended. An empty deal still matches so this
/// screen shows E2 instead of dealing again.
bool _sessionMatches(GameSession session, LastGameSettings settings) {
  if (session.questions.isNotEmpty && session.isComplete) return false;
  if (session.requestedCount != settings.questionCount) return false;
  if (session.volumes.length != settings.volumes.length) return false;
  final dealt = session.volumes.toSet();
  for (final volume in settings.volumes) {
    if (!dealt.contains(volume)) return false;
  }
  return true;
}

double? _toolbarHeight(BuildContext context) {
  if (!isLargeText(context)) return null;
  final titleStyle = Theme.of(context).textTheme.titleLarge;
  final fontSize = titleStyle?.fontSize ?? 22;
  final heightFactor = titleStyle?.height ?? 30 / 22;
  final line = MediaQuery.textScalerOf(context).scale(fontSize * heightFactor);
  return line * 2 + StSpace.md;
}

bool _reducedMotion(BuildContext context) {
  final media = MediaQuery.of(context);
  return media.disableAnimations || media.reduceMotion;
}

/// The framework turns the iOS edge swipe off when [PopScope] refuses the
/// pop. This strip calls the same quit path the system back button uses.
class _IosBackSwipe extends StatefulWidget {
  const _IosBackSwipe({required this.onQuit, required this.child});

  final VoidCallback onQuit;
  final Widget child;

  @override
  State<_IosBackSwipe> createState() => _IosBackSwipeState();
}

class _IosBackSwipeState extends State<_IosBackSwipe> {
  double _drag = 0;

  @override
  Widget build(BuildContext context) {
    if (!_usesCupertino()) return widget.child;
    final toolbar = _toolbarHeight(context) ?? kToolbarHeight;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        PositionedDirectional(
          start: 0,
          top: toolbar,
          bottom: 0,
          width: 20,
          child: GestureDetector(
            key: const Key('ios-back-swipe'),
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (details) {
              _drag += details.primaryDelta ?? 0;
            },
            onHorizontalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              final quit = velocity > 300 || _drag > 64;
              _drag = 0;
              if (quit) widget.onQuit();
            },
            onHorizontalDragCancel: () => _drag = 0,
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }
}

class _PreparingBody extends StatelessWidget {
  const _PreparingBody();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHigh;
    Widget bar({double? width, double height = 20}) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.all(StRadius.md),
          ),
        ),
      );
    }

    return Semantics(
      label: 'Preparing the question',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          bar(width: 160),
          const SizedBox(height: StSpace.md),
          bar(height: 96),
          const SizedBox(height: StSpace.lg),
          for (var i = 0; i < 4; i++) ...[
            bar(height: StSpace.answerMinHeight),
            const SizedBox(height: StSpace.sm),
          ],
        ],
      ),
    );
  }
}

class _QuestionBody extends StatelessWidget {
  const _QuestionBody({
    required this.session,
    required this.showingFeedback,
    required this.showExplanations,
    required this.onChoose,
    required this.onNext,
  });

  final GameSession session;
  final bool showingFeedback;
  final bool showExplanations;
  final ValueChanged<int> onChoose;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final large = isLargeText(context);
    final reduced = _reducedMotion(context);
    final index = _displayIndex(session, showingFeedback);
    final question = session.questions[index];
    final answer =
        showingFeedback && index >= 0 && index < session.answers.length
        ? session.answers[index]
        : null;
    final screenHeight = MediaQuery.sizeOf(context).height;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Large text keeps the sheet near 60% of the screen so Next stays
        // on screen. The body is shorter than the screen once the app bar
        // is subtracted, so the cap also has to fit in that space.
        final sheetCap = max(
          1.0,
          large
              ? min(constraints.maxHeight, screenHeight * 0.6)
              : min(constraints.maxHeight, screenHeight * 0.5),
        );
        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  StSpace.screenH,
                  StSpace.md,
                  StSpace.screenH,
                  StSpace.md,
                ),
                child: _QuestionColumn(
                  question: question,
                  index: index,
                  total: session.questionCount,
                  answer: answer,
                  locked: answer != null,
                  large: large,
                  reduced: reduced,
                  onChoose: onChoose,
                ),
              ),
            ),
            if (answer != null)
              _FeedbackEntrance(
                reduced: reduced,
                child: _FeedbackSheet(
                  maxHeight: sheetCap,
                  question: question,
                  answer: answer,
                  showExplanation: showExplanations,
                  streak: session.currentStreak,
                  isLast: session.isComplete,
                  onNext: onNext,
                ),
              ),
          ],
        );
      },
    );
  }
}

int _displayIndex(GameSession session, bool showingFeedback) {
  if (showingFeedback) {
    final answered = session.currentIndex - 1;
    if (answered >= 0 && answered < session.questions.length) return answered;
  }
  if (session.currentIndex < session.questions.length) {
    return session.currentIndex;
  }
  return session.questions.length - 1;
}

class _QuestionColumn extends StatelessWidget {
  const _QuestionColumn({
    required this.question,
    required this.index,
    required this.total,
    required this.answer,
    required this.locked,
    required this.large,
    required this.reduced,
    required this.onChoose,
  });

  final GameQuestion question;
  final int index;
  final int total;
  final GameAnswer? answer;
  final bool locked;
  final bool large;
  final bool reduced;
  final ValueChanged<int> onChoose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: StSpace.sm,
          runSpacing: StSpace.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            QuestionProgress(current: index + 1, total: total),
            _VolumeTag(volume: question.volume),
          ],
        ),
        const SizedBox(height: StSpace.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(StSpace.md),
            child: Text(question.prompt, style: theme.textTheme.titleLarge),
          ),
        ),
        const SizedBox(height: StSpace.lg),
        for (var option = 0; option < question.options.length; option++) ...[
          if (option > 0) const SizedBox(height: StSpace.sm),
          _AnswerButton(
            index: option,
            label: question.options[option],
            mark: _markFor(question, option, answer),
            pickedCorrect: answer?.correct ?? false,
            locked: locked,
            large: large,
            reduced: reduced,
            onTap: () => onChoose(option),
          ),
        ],
      ],
    );
  }
}

enum _AnswerMark { none, correct, yours }

_AnswerMark _markFor(GameQuestion question, int index, GameAnswer? answer) {
  if (answer == null) return _AnswerMark.none;
  if (index == question.answerIndex) return _AnswerMark.correct;
  if (index == answer.selectedIndex && !answer.correct) {
    return _AnswerMark.yours;
  }
  return _AnswerMark.none;
}

class _AnswerButton extends StatelessWidget {
  const _AnswerButton({
    required this.index,
    required this.label,
    required this.mark,
    required this.pickedCorrect,
    required this.locked,
    required this.large,
    required this.reduced,
    required this.onTap,
  });

  final int index;
  final String label;
  final _AnswerMark mark;

  /// True when the player picked the right option. A revealed right option
  /// is tagged "Correct answer"; the option they picked is tagged "Correct".
  final bool pickedCorrect;
  final bool locked;
  final bool large;
  final bool reduced;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = theme.extension<StColors>()!;
    final (fill, border, foreground) = switch (mark) {
      _AnswerMark.correct => (
        colors.correctContainer,
        colors.correct,
        colors.onCorrectContainer,
      ),
      _AnswerMark.yours => (
        colors.wrongContainer,
        colors.wrong,
        colors.onWrongContainer,
      ),
      _AnswerMark.none => (
        scheme.surfaceContainerLowest,
        scheme.outlineVariant,
        locked ? scheme.onSurfaceVariant : scheme.onSurface,
      ),
    };
    final status = switch (mark) {
      _AnswerMark.correct => _StatusTag(
        icon: Icons.check,
        label: pickedCorrect ? 'Correct' : 'Correct answer',
        color: colors.correct,
        textColor: colors.onCorrectContainer,
        iconMotion: reduced ? _IconMotion.fade : _IconMotion.pop,
      ),
      _AnswerMark.yours => _StatusTag(
        icon: Icons.close,
        label: 'Your answer',
        color: colors.wrong,
        textColor: colors.onWrongContainer,
        iconMotion: _IconMotion.none,
      ),
      _AnswerMark.none => null,
    };
    final text = Text(label, style: theme.textTheme.bodyLarge);
    final content = status == null
        ? Align(alignment: Alignment.centerLeft, child: text)
        : large
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              text,
              const SizedBox(height: StSpace.xs),
              status,
            ],
          )
        : Row(
            children: [
              Expanded(child: text),
              const SizedBox(width: StSpace.sm),
              status,
            ],
          );
    final target = max(StSpace.answerMinHeight, minTapTarget(context));
    final button = Semantics(
      button: true,
      enabled: !locked,
      child: Material(
        key: ValueKey('answer-fill-$index'),
        color: fill,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(StRadius.md),
          side: BorderSide(
            color: border,
            width: mark == _AnswerMark.none ? 1 : 2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('answer-$index'),
          onTap: locked ? null : onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: target),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: StSpace.md,
                vertical: StSpace.sm,
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
    if (mark != _AnswerMark.yours) return button;
    return _WrongMotion(reduced: reduced, child: button);
  }
}

enum _IconMotion { none, pop, fade }

class _StatusTag extends StatelessWidget {
  const _StatusTag({
    required this.icon,
    required this.label,
    required this.color,
    required this.textColor,
    required this.iconMotion,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;
  final _IconMotion iconMotion;

  @override
  Widget build(BuildContext context) {
    final iconWidget = ExcludeSemantics(
      child: StIcon(icon, size: 20, color: color),
    );
    final moving = switch (iconMotion) {
      _IconMotion.pop => _CheckPop(child: iconWidget),
      _IconMotion.fade => _FadeIn(
        motionKey: const Key('correct-fade'),
        child: iconWidget,
      ),
      _IconMotion.none => iconWidget,
    };
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: StSpace.xs,
      children: [
        moving,
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(color: textColor),
        ),
      ],
    );
  }
}

class _VolumeTag extends StatelessWidget {
  const _VolumeTag({required this.volume});

  final ScriptureVolume volume;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<StColors>()!;
    final tint = colors.volume[_themeVolume(volume)]!;
    return Container(
      key: const Key('volume-tag'),
      padding: const EdgeInsets.symmetric(
        horizontal: StSpace.sm,
        vertical: StSpace.xs,
      ),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.16),
        borderRadius: const BorderRadius.all(StRadius.sm),
      ),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: StSpace.xs),
          Flexible(
            child: Text(volume.label, style: theme.textTheme.labelLarge),
          ),
        ],
      ),
    );
  }
}

Volume _themeVolume(ScriptureVolume volume) {
  return switch (volume) {
    ScriptureVolume.ot => Volume.oldTestament,
    ScriptureVolume.nt => Volume.newTestament,
    ScriptureVolume.bom => Volume.bookOfMormon,
    ScriptureVolume.dc => Volume.doctrineAndCovenants,
    ScriptureVolume.pgp => Volume.pearlOfGreatPrice,
  };
}

const _streakMarks = {3, 5, 10};

class _FeedbackSheet extends ConsumerWidget {
  const _FeedbackSheet({
    required this.maxHeight,
    required this.question,
    required this.answer,
    required this.showExplanation,
    required this.streak,
    required this.isLast,
    required this.onNext,
  });

  final double maxHeight;
  final GameQuestion question;
  final GameAnswer answer;
  final bool showExplanation;
  final int streak;
  final bool isLast;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = theme.extension<StColors>()!;
    final reported = ref.watch(
      reportedQuestionIdsProvider.select(
        (memory) => memory.isReported(question.id),
      ),
    );
    final correct = answer.correct;
    final reference = question.reference;
    final explanation = question.explanation;
    final selected = answer.selectedIndex;
    final selectedAnswer =
        selected >= 0 && selected < question.options.length
        ? question.options[selected]
        : '';
    final showStreak = _streakMarks.contains(streak);
    final tone = correct ? colors.correct : colors.wrong;
    final headline = correct ? 'Correct!' : 'Not quite';
    return ConstrainedBox(
      key: const Key('feedback-sheet'),
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Material(
        color: scheme.surfaceContainerLowest,
        elevation: 3,
        shadowColor: scheme.shadow.withValues(alpha: 0.2),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: StRadius.lg),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              fit: FlexFit.loose,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  StSpace.screenH,
                  StSpace.md,
                  StSpace.screenH,
                  StSpace.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ExcludeSemantics(
                          child: StIcon(
                            correct ? Icons.check : Icons.close,
                            size: 32,
                            color: tone,
                          ),
                        ),
                        const SizedBox(width: StSpace.sm),
                        Flexible(
                          child: Text(
                            headline,
                            key: const Key('result-headline'),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: tone,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (!correct) ...[
                      const SizedBox(height: StSpace.sm),
                      Text.rich(
                        TextSpan(
                          style: theme.textTheme.bodyLarge,
                          children: [
                            const TextSpan(text: 'The answer is '),
                            TextSpan(
                              text: question.answer,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const TextSpan(text: '.'),
                          ],
                        ),
                      ),
                    ],
                    if (showStreak) ...[
                      const SizedBox(height: StSpace.sm),
                      _StreakChip(streak: streak),
                    ],
                    if (showExplanation) ...[
                      const SizedBox(height: StSpace.sm),
                      Text(
                        explanation,
                        key: const Key('explanation'),
                        style: theme.textTheme.bodyLarge,
                      ),
                    ],
                    const SizedBox(height: StSpace.sm),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: ScriptureReferenceChip(
                            key: const Key('reference-chip'),
                            reference: reference,
                            background: scheme.secondaryContainer,
                            foreground: scheme.onSecondaryContainer,
                          ),
                        ),
                        const Spacer(),
                        ReportFlag(
                          key: Key('report-flag-${question.id}'),
                          target: ReportTarget(
                            questionId: question.id,
                            prompt: question.prompt,
                            correctAnswer: question.answer,
                            selectedAnswer: selectedAnswer,
                            reference: reference,
                            source: 'game',
                          ),
                        ),
                      ],
                    ),
                    if (reported) ...[
                      const SizedBox(height: StSpace.xs),
                      Text(
                        reportThanksLine,
                        key: const Key('report-thanks'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                StSpace.screenH,
                StSpace.xs,
                StSpace.screenH,
                StSpace.md,
              ),
              child: PrimaryButton(
                label: isLast ? 'See results' : 'Next question',
                onPressed: onNext,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StreakChip extends StatelessWidget {
  const _StreakChip({required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final gold = theme.extension<StColors>()!.gold;
    return Container(
      key: const Key('streak-chip'),
      padding: const EdgeInsets.symmetric(
        horizontal: StSpace.sm,
        vertical: StSpace.xs,
      ),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: const BorderRadius.all(StRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: StIcon(Icons.local_fire_department, size: 18, color: gold),
          ),
          const SizedBox(width: StSpace.xs),
          Text(
            '$streak in a row',
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackEntrance extends StatefulWidget {
  const _FeedbackEntrance({required this.reduced, required this.child});

  final bool reduced;
  final Widget child;

  @override
  State<_FeedbackEntrance> createState() => _FeedbackEntranceState();
}

class _FeedbackEntranceState extends State<_FeedbackEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _curve;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.reduced ? StMotion.fast : StMotion.medium,
      // disableAnimations would otherwise squash this to one frame. Reduced
      // motion still gets the 150 ms fade.
      animationBehavior: AnimationBehavior.preserve,
    );
    _curve = CurvedAnimation(parent: _controller, curve: StMotion.emphasized);
    _controller.forward();
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reduced) {
      return FadeTransition(
        key: const Key('feedback-fade'),
        opacity: _curve,
        child: widget.child,
      );
    }
    return SlideTransition(
      key: const Key('feedback-slide'),
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(_curve),
      child: widget.child,
    );
  }
}

class _CheckPop extends StatefulWidget {
  const _CheckPop({required this.child});

  final Widget child;

  @override
  State<_CheckPop> createState() => _CheckPopState();
}

class _CheckPopState extends State<_CheckPop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: StMotion.medium,
      animationBehavior: AnimationBehavior.preserve,
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.4,
          end: 1.15,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.15,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 40,
      ),
    ]).animate(_controller);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      key: const Key('correct-pop'),
      scale: _scale,
      child: widget.child,
    );
  }
}

class _FadeIn extends StatefulWidget {
  const _FadeIn({required this.motionKey, required this.child});

  final Key motionKey;
  final Widget child;

  @override
  State<_FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<_FadeIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _curve;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: StMotion.fast,
      animationBehavior: AnimationBehavior.preserve,
    );
    _curve = CurvedAnimation(parent: _controller, curve: StMotion.emphasized);
    _controller.forward();
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      key: widget.motionKey,
      opacity: _curve,
      child: widget.child,
    );
  }
}

class _WrongMotion extends StatefulWidget {
  const _WrongMotion({required this.reduced, required this.child});

  final bool reduced;
  final Widget child;

  @override
  State<_WrongMotion> createState() => _WrongMotionState();
}

class _WrongMotionState extends State<_WrongMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _offset;
  late final CurvedAnimation _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.reduced ? StMotion.fast : StMotion.medium,
      animationBehavior: AnimationBehavior.preserve,
    );
    _fade = CurvedAnimation(parent: _controller, curve: StMotion.emphasized);
    _offset = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -8), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8, end: -6), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6, end: 4), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 4, end: 0), weight: 1),
    ]).animate(_controller);
    _controller.forward();
  }

  @override
  void dispose() {
    _fade.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reduced) {
      return FadeTransition(
        key: const Key('wrong-fade'),
        opacity: _fade,
        child: widget.child,
      );
    }
    return AnimatedBuilder(
      key: const Key('wrong-shake'),
      animation: _offset,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_offset.value, 0),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
