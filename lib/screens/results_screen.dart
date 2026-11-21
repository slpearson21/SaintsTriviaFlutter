import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../data/questions/scripture_volume.dart';
import '../game/game_engine.dart';
import '../game/game_providers.dart';
import '../layout/adaptive_actions.dart';
import '../layout/platform_style.dart';
import '../layout/screen_body.dart';
import '../layout/section_label.dart';
import '../layout/st_icon.dart';
import '../layout/text_scale.dart';
import '../progress/home_providers.dart';
import '../progress/play_again.dart';
import '../progress/record_finished_game.dart';
import '../results/results_summary.dart';
import '../routing/routes.dart';
import '../theme/st_theme.dart';

/// Ring sweep and the score count-up. The delight spec is 800 ms.
const _countUp = Duration(milliseconds: 800);

const _ringExtent = 168.0;
const _ringStroke = 12.0;

/// S09. Score, breakdown, and the next step after a finished game.
class ResultsScreen extends ConsumerStatefulWidget {
  const ResultsScreen({super.key});

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen> {
  GameSession? _recordScheduled;

  void _scheduleRecord(GameSession session) {
    if (identical(_recordScheduled, session)) return;
    _recordScheduled = session;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(finishedGameRecorderProvider)(session);
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(gameControllerProvider);
    if (!isFinishedSession(session)) {
      // Play again replaces the finished session and then leaves. The
      // route redirect covers a deep link. This frame stays blank so that
      // replace does not send the player home.
      return const Scaffold(body: SizedBox.shrink());
    }
    final finished = session!;
    _scheduleRecord(finished);

    final snapshot = ref.watch(homeSnapshotProvider);
    final recorded = ref.watch(recordedBestProvider);
    final percent = scorePercent(finished.score, finished.questionCount);
    // Before this game is stored, the snapshot's best is every earlier
    // game. Once it is stored, that best includes this game, so the
    // comparison uses the percent remembered at record time. The first
    // game remembers null and is never a personal best.
    final previous = identical(recorded.session, finished)
        ? recorded.previousBestPercent
        : snapshot.bestScorePercent;
    final personalBest = isNewPersonalBestPercent(percent, previous);
    // previous == null is the first game ever. No chip and no sparkle,
    // including a perfect score.
    final sparkle = showResultsSparkle(
      percent: percent,
      personalBest: personalBest,
      firstGame: previous == null,
    );
    final sentence = answeredCorrectlySentence(
      finished.score,
      finished.questionCount,
    );
    final large = isLargeText(context);
    final material = usesMaterialChrome();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final score = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          container: true,
          label: sentence,
          excludeSemantics: true,
          child: _ScoreRing(
            score: finished.score,
            total: finished.questionCount,
            percent: percent,
            sparkle: sparkle,
          ),
        ),
        const SizedBox(height: StSpace.lg),
        Semantics(
          header: true,
          child: Text(
            resultsHeadline(percent),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
        ),
        const SizedBox(height: StSpace.xs),
        ExcludeSemantics(
          child: Text(
            sentence,
            key: const Key('results-summary'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: StSpace.md),
        _ScoreChips(
          bestStreak: finished.bestStreak,
          personalBest: personalBest,
        ),
        const SizedBox(height: StSpace.lg),
        const SectionLabel('By scripture'),
        const SizedBox(height: StSpace.sm),
        _VolumeCard(rows: breakdownByVolume(finished)),
      ],
    );
    final playAgain = FilledButton.icon(
      key: const Key('results-play-again'),
      onPressed: () => unawaited(dealAndPlayAgain(ref, context, finished)),
      icon: const StIcon(Icons.replay_rounded, size: 20),
      label: const Text('Play again'),
    );
    final otherActions = <Widget>[
      AdaptiveActions(
        children: [
          OutlinedButton(
            key: const Key('results-new-game'),
            onPressed: () => openPlayAgain(context, lastSettingsFor(finished)),
            child: const Text('New game'),
          ),
          OutlinedButton(
            key: const Key('results-review'),
            onPressed: () => context.go(AppRoutes.review),
            child: Text(large ? 'Review answers' : 'Review'),
          ),
        ],
      ),
      FilledButton.tonal(
        key: const Key('results-done'),
        style: FilledButton.styleFrom(
          side: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
        onPressed: () => context.go(AppRoutes.home),
        child: const Text('Done'),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: material,
        centerTitle: !material,
        toolbarHeight: largeTitleToolbarHeight(context),
        title: const Text('Results', maxLines: 2),
      ),
      // Large text pins Play again the way Home and Setup pin their
      // primary action. New game, Review, and Done scroll with the score.
      body: large
          ? ScreenBody(
              primary: playAgain,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  score,
                  const SizedBox(height: StSpace.xl),
                  ...otherActions,
                ],
              ),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  StSpace.screenH,
                  StSpace.md,
                  StSpace.screenH,
                  StSpace.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    score,
                    const SizedBox(height: StSpace.xl),
                    playAgain,
                    const SizedBox(height: StSpace.sm),
                    ...otherActions,
                  ],
                ),
              ),
            ),
    );
  }
}

class _ScoreChips extends StatelessWidget {
  const _ScoreChips({required this.bestStreak, required this.personalBest});

  final int bestStreak;
  final bool personalBest;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: StSpace.sm,
      runSpacing: StSpace.xs,
      children: [
        _ResultChip(
          key: const Key('results-best-streak'),
          icon: Icons.local_fire_department_rounded,
          label: 'Best streak $bestStreak',
        ),
        if (personalBest)
          const _ResultChip(
            key: Key('results-personal-best'),
            icon: Icons.emoji_events_rounded,
            label: 'New personal best',
          ),
      ],
    );
  }
}

class _ResultChip extends StatelessWidget {
  const _ResultChip({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final gold = theme.extension<StColors>()!.gold;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: const BorderRadius.all(StRadius.full),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: StSpace.sm,
          vertical: StSpace.xs,
        ),
        // Text.rich wraps when the label is wider than the screen, and the
        // chip still hugs the words when they fit on one line.
        child: Text.rich(
          TextSpan(
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: scheme.onSecondaryContainer,
            ),
            children: [
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: ExcludeSemantics(
                  child: Padding(
                    padding: const EdgeInsets.only(right: StSpace.xxs),
                    child: StIcon(icon, size: 18, color: gold),
                  ),
                ),
              ),
              TextSpan(text: label),
            ],
          ),
        ),
      ),
    );
  }
}

class _VolumeCard extends StatelessWidget {
  const _VolumeCard({required this.rows});

  final List<VolumeBreakdown> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(StSpace.md),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const SizedBox(height: StSpace.md),
              _VolumeRow(row: rows[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _VolumeRow extends StatelessWidget {
  const _VolumeRow({required this.row});

  final VolumeBreakdown row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = theme
        .extension<StColors>()!
        .volume[_themeVolume(row.volume)]!;
    final fraction = '${row.correct}/${row.total}';
    return Semantics(
      container: true,
      label: '${row.volume.label}, ${row.correct} of ${row.total}',
      excludeSemantics: true,
      child: Column(
        key: Key('results-volume-${row.volume.name}'),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: StIcon(Icons.menu_book_rounded, size: 20, color: color),
              ),
              const SizedBox(width: StSpace.sm),
              Expanded(
                child: Text(
                  row.volume.label,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: StSpace.sm),
              Text(fraction, style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: StSpace.xs),
          ClipRRect(
            borderRadius: const BorderRadius.all(StRadius.full),
            child: LinearProgressIndicator(
              value: row.total == 0 ? 0 : row.correct / row.total,
              minHeight: 8,
              color: color,
              backgroundColor: scheme.surfaceContainerHigh,
            ),
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

class _ScoreRing extends StatefulWidget {
  const _ScoreRing({
    required this.score,
    required this.total,
    required this.percent,
    required this.sparkle,
  });

  final int score;
  final int total;
  final int percent;
  final bool sparkle;

  @override
  State<_ScoreRing> createState() => _ScoreRingState();
}

class _ScoreRingState extends State<_ScoreRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  var _motionApplied = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _countUp);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_motionApplied) return;
    _motionApplied = true;
    // MediaQuery.disableAnimations is the reduced-motion flag the spec
    // names. The final ring is frame one; there is no count-up to skip.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = theme.extension<StColors>()!.gold;
    final track = theme.colorScheme.secondaryContainer;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = StMotion.emphasized.transform(_controller.value);
        final shownScore = (widget.score * t).round();
        final shownPercent = (widget.percent * t).round();
        final revealSparkle = widget.sparkle && _controller.value == 1;
        return Center(
          child: SizedBox(
            width: _ringExtent,
            height: _ringExtent,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size.square(_ringExtent),
                  painter: _RingPainter(
                    progress: widget.percent / 100 * t,
                    color: gold,
                    track: track,
                  ),
                ),
                SizedBox(
                  width: _ringExtent - _ringStroke * 4,
                  height: _ringExtent - _ringStroke * 4,
                  child: FittedBox(
                    key: const Key('results-score-numeral'),
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$shownScore / ${widget.total}',
                          style: theme.textTheme.displaySmall,
                        ),
                        Text(
                          '$shownPercent%',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (revealSparkle)
                  const Positioned(top: 6, right: 18, child: _Sparkle()),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Sparkle extends StatelessWidget {
  const _Sparkle();

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).extension<StColors>()!.gold;
    return ExcludeSemantics(
      child: StIcon(
        Icons.auto_awesome,
        key: const Key('results-sparkle'),
        size: 18,
        color: gold,
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.color,
    required this.track,
  });

  final double progress;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arc = rect.deflate(_ringStroke / 2);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _ringStroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arc, 0, math.pi * 2, false, stroke..color = track);
    final sweep = (math.pi * 2 * progress).clamp(0.0, math.pi * 2);
    if (sweep <= 0) return;
    canvas.drawArc(arc, -math.pi / 2, sweep, false, stroke..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.track != track;
  }
}
