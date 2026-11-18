import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../data/questions/scripture_volume.dart';
import '../layout/home_back_button.dart';
import '../layout/section_label.dart';
import '../layout/st_icon.dart';
import '../layout/text_scale.dart';
import '../persistence/finished_game_record.dart';
import '../progress/home_providers.dart';
import '../progress/stats_summary.dart';
import '../routing/routes.dart';
import '../theme/st_theme.dart';

/// S11. Totals, best game, and accuracy by volume. Empty until a game ends.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(statsSummaryProvider);
    final now = ref.watch(homeClockProvider)();
    final material = usesMaterialChrome(context);
    return Scaffold(
      appBar: AppBar(
        centerTitle: !material,
        toolbarHeight: largeTitleToolbarHeight(context),
        leadingWidth: HomeBackButton.leadingWidth(context),
        leading: const HomeBackButton(),
        title: const Text('Stats', maxLines: 2),
      ),
      body: SafeArea(
        child: summary.gamesPlayed == 0
            ? const _EmptyStats()
            : _PopulatedStats(summary: summary, now: now),
      ),
    );
  }
}

class _EmptyStats extends StatelessWidget {
  const _EmptyStats();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: StSpace.screenH,
            vertical: StSpace.md,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight.isFinite
                  ? (constraints.maxHeight - StSpace.md * 2).clamp(
                      0,
                      double.infinity,
                    )
                  : 0,
            ),
            child: Column(
              key: const Key('stats-empty'),
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ExcludeSemantics(
                  child: Center(
                    child: SizedBox(
                      width: 96,
                      height: 96,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: StIcon(
                            Icons.bar_chart_rounded,
                            size: 40,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: StSpace.lg),
                Text(
                  'No stats yet',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: StSpace.xs),
                Text(
                  'Play your first game to see your '
                  'accuracy, best scores and streaks here.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: StSpace.lg),
                FilledButton.icon(
                  key: const Key('stats-start'),
                  onPressed: () => context.go(AppRoutes.setup),
                  icon: const StIcon(Icons.play_arrow_rounded, size: 20),
                  label: const Text(
                    'Start a game',
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: StSpace.lg),
                const _SavedOnDevice(showIcon: false),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PopulatedStats extends StatelessWidget {
  const _PopulatedStats({required this.summary, required this.now});

  final StatsSummary summary;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final large = isLargeText(context);
    final cards = [
      _StatCard(
        key: const Key('stats-games'),
        value: '${summary.gamesPlayed}',
        label: 'Games played',
      ),
      _StatCard(
        key: const Key('stats-questions'),
        value: '${summary.questionsAnswered}',
        label: 'Questions answered',
      ),
      _StatCard(
        key: const Key('stats-accuracy'),
        value: '${summary.accuracyPercent}%',
        label: 'Accuracy',
      ),
      _StatCard(
        key: const Key('stats-streak'),
        value: '${summary.bestStreak}',
        label: 'Best streak',
        leading: Icons.local_fire_department_rounded,
      ),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        StSpace.screenH,
        StSpace.md,
        StSpace.screenH,
        StSpace.xl,
      ),
      children: [
        if (large)
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(height: StSpace.sm),
            cards[i],
          ]
        else ...[
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: StSpace.sm),
                Expanded(child: cards[1]),
              ],
            ),
          ),
          const SizedBox(height: StSpace.sm),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: cards[2]),
                const SizedBox(width: StSpace.sm),
                Expanded(child: cards[3]),
              ],
            ),
          ),
        ],
        if (summary.bestGame case final best?) ...[
          const SizedBox(height: StSpace.sm),
          _BestGameCard(game: best, now: now),
        ],
        const SizedBox(height: StSpace.lg),
        const SectionLabel('Accuracy by scripture'),
        const SizedBox(height: StSpace.sm),
        _VolumeCard(rows: summary.byVolume),
        const SizedBox(height: StSpace.lg),
        const _SavedOnDevice(),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    super.key,
    required this.value,
    required this.label,
    this.leading,
  });

  final String value;
  final String label;
  final IconData? leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final gold = theme.extension<StColors>()!.gold;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(StSpace.md),
        child: MergeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (leading case final icon?) ...[
                    ExcludeSemantics(
                      child: StIcon(icon, size: 22, color: gold),
                    ),
                    const SizedBox(width: StSpace.xxs),
                  ],
                  Flexible(
                    child: Text(value, style: theme.textTheme.headlineSmall),
                  ),
                ],
              ),
              const SizedBox(height: StSpace.xxs),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BestGameCard extends StatelessWidget {
  const _BestGameCard({required this.game, required this.now});

  final FinishedGameRecord game;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final gold = theme.extension<StColors>()!.gold;
    final line = bestGameLine(game, now);
    return Semantics(
      key: const Key('stats-best-game'),
      container: true,
      label: bestGameSemanticsLabel(game, now),
      excludeSemantics: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(StSpace.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StIcon(Icons.emoji_events_rounded, size: 22, color: gold),
              const SizedBox(width: StSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Best game', style: theme.textTheme.titleMedium),
                    Text(
                      line,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VolumeCard extends StatelessWidget {
  const _VolumeCard({required this.rows});

  final List<VolumeAccuracy> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
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

  final VolumeAccuracy row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = theme
        .extension<StColors>()!
        .volume[_themeVolume(row.volume)]!;
    return Semantics(
      container: true,
      label: '${row.volume.label}, ${row.correct} of ${row.total}',
      excludeSemantics: true,
      child: Column(
        key: Key('stats-volume-${row.volume.name}'),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: StIcon(_volumeIcon(row.volume), size: 20, color: color),
              ),
              const SizedBox(width: StSpace.sm),
              Expanded(
                child: Text(
                  row.volume.label,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: StSpace.sm),
              Text(
                '${row.correct}/${row.total}',
                style: theme.textTheme.titleMedium,
              ),
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

class _SavedOnDevice extends StatelessWidget {
  const _SavedOnDevice({this.showIcon = true});

  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    const message = 'Stats are saved on this device only.';
    if (!showIcon) {
      return Text(message, textAlign: TextAlign.center, style: style);
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: ExcludeSemantics(
            child: StIcon(Icons.info_outline, size: 16, color: scheme.outline),
          ),
        ),
        const SizedBox(width: StSpace.xs),
        Flexible(
          child: Text(message, textAlign: TextAlign.center, style: style),
        ),
      ],
    );
  }
}

IconData _volumeIcon(ScriptureVolume volume) {
  return switch (volume) {
    ScriptureVolume.ot => Icons.menu_book_rounded,
    ScriptureVolume.nt => Icons.wb_sunny_rounded,
    ScriptureVolume.bom => Icons.auto_stories_rounded,
    ScriptureVolume.dc => Icons.menu_book_outlined,
    ScriptureVolume.pgp => Icons.diamond_rounded,
  }
}

Volume _themeVolume(ScriptureVolume volume) {
  return switch (volume) {
    ScriptureVolume.ot => Volume.oldTestament,
    ScriptureVolume.nt => Volume.newTestament,
    ScriptureVolume.bom => Volume.bookOfMormon,
    ScriptureVolume.dc => Volume.doctrineAndCovenants,
    ScriptureVolume.pgp => Volume.pearlOfGreatPrice,
  }
}
