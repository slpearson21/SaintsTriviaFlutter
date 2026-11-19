import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../layout/platform_style.dart';
import '../layout/screen_body.dart';
import '../layout/section_label.dart';
import '../layout/st_icon.dart';
import '../layout/text_scale.dart';
import '../progress/home_providers.dart';
import '../progress/home_snapshot.dart';
import '../progress/play_again.dart';
import '../routing/routes.dart';
import '../theme/st_theme.dart';

/// Mockup inset that is not on the 4-pt grid.
const _cardInset = 14.0;

/// How-it-works rule starts at the copy: 16 pad + 36 icon + 16 gap.
const _howItWorksDividerIndent = 68.0;

/// Home hub. Reads [homeSnapshotProvider] and does not load the question bank.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(homeSnapshotProvider);
    final now = ref.watch(homeClockProvider)();
    final material = usesMaterialChrome();
    final settings = snapshot.lastSettings;
    final lastGame = snapshot.lastGame;

    return Scaffold(
      appBar: material
          ? _AndroidHomeBar(toolbarHeight: _androidToolbarHeight(context))
          : null,
      body: ScreenBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!material) ...[
              const _IosHomeHeader(),
              const SizedBox(height: StSpace.md),
            ],
            _HomeHero(firstRun: snapshot.isFirstRun),
            const SizedBox(height: StSpace.xl),
            if (snapshot.isFirstRun) ...[
              const SectionLabel('How it works'),
              const SizedBox(height: StSpace.sm),
              const _HowItWorksCard(),
              const SizedBox(height: StSpace.lg),
              const _EmptyStats(),
            ] else ...[
              if (settings != null) ...[
                _PlayAgainCard(settings: settings),
                const SizedBox(height: StSpace.lg),
              ],
              const _ProgressHeader(),
              _ProgressCard(game: lastGame, snapshot: snapshot, now: now),
            ],
          ],
        ),
      ),
    );
  }
}

/// Room for two serif lines at the current text scale, and at least 64 dp.
///
/// A Material [AppBar] title does not wrap and clamps text scale, so the
/// Android bar is custom. The scaffold caps the bar at this height. The
/// bar itself shrinks to the title when that title is a single line.
double _androidToolbarHeight(BuildContext context) {
  final line = MediaQuery.textScalerOf(context).scale(32);
  final twoLines = line * 2 + StSpace.md;
  return twoLines < 64 ? 64 : twoLines;
}

class _AndroidHomeBar extends StatelessWidget implements PreferredSizeWidget {
  const _AndroidHomeBar({required this.toolbarHeight});

  final double toolbarHeight;

  @override
  Size get preferredSize => Size.fromHeight(toolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      child: SafeArea(
        bottom: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: 64, maxHeight: toolbarHeight),
          child: Padding(
            padding: const EdgeInsets.only(
              left: StSpace.screenH,
              right: StSpace.xxs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      'Scripture Trivia',
                      style: theme.textTheme.headlineSmall,
                      softWrap: true,
                      overflow: TextOverflow.clip,
                    ),
                  ),
                ),
                const _HomeIconButton(
                  tooltip: 'Stats',
                  icon: Icons.bar_chart_rounded,
                  route: AppRoutes.stats,
                ),
                const _HomeIconButton(
                  tooltip: 'Settings',
                  icon: Icons.settings_rounded,
                  route: AppRoutes.settings,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IosHomeHeader extends StatelessWidget {
  const _IosHomeHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _HomeIconButton(
              tooltip: 'Stats',
              icon: Icons.bar_chart_rounded,
              route: AppRoutes.stats,
            ),
            _HomeIconButton(
              tooltip: 'Settings',
              icon: Icons.settings_rounded,
              route: AppRoutes.settings,
            ),
          ],
        ),
        const SizedBox(height: StSpace.xxs),
        Semantics(
          header: true,
          child: Text(
            'Scripture Trivia',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
      ],
    );
  }
}

class _HomeIconButton extends StatelessWidget {
  const _HomeIconButton({
    required this.tooltip,
    required this.icon,
    required this.route,
  });

  final String tooltip;
  final IconData icon;
  final String route;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = usesMaterialChrome()
        ? scheme.onSurfaceVariant
        : scheme.primary;
    final target = minTapTarget(context);
    return IconButton(
      tooltip: tooltip,
      onPressed: () => context.go(route),
      style: IconButton.styleFrom(
        minimumSize: Size.square(target),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: EdgeInsets.zero,
        foregroundColor: color,
      ),
      icon: StIcon(icon, color: color),
    );
  }
}

class _HomeHero extends StatelessWidget {
  const _HomeHero({required this.firstRun});

  final bool firstRun;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final gold = theme.extension<StColors>()!.gold;
    final light = theme.brightness == Brightness.light;
    // Light hero is primary. Dark hero is primaryContainer, so the pill
    // uses primary / onPrimary there and stays visible on that fill.
    final heroColor = light ? scheme.primary : scheme.primaryContainer;
    final onHero = light ? scheme.onPrimary : scheme.onPrimaryContainer;
    final subtitleColor = light ? scheme.primaryContainer : scheme.primary;
    final buttonBackground = light ? scheme.primaryContainer : scheme.primary;
    final buttonForeground = light
        ? scheme.onPrimaryContainer
        : scheme.onPrimary;

    final overline = firstRun ? 'WELCOME' : 'READY WHEN YOU ARE';
    final headline = firstRun
        ? 'Test your scripture knowledge'
        : 'Welcome back!';
    final subtitle = firstRun
        ? 'All five volumes of scripture. Free, offline, no account needed.'
        : 'Up to 50 questions from the scriptures you choose.';

    return DecoratedBox(
      key: const Key('home-hero'),
      decoration: BoxDecoration(
        color: heroColor,
        borderRadius: const BorderRadius.all(StRadius.xl),
      ),
      child: Padding(
        padding: const EdgeInsets.all(StSpace.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ExcludeSemantics(
                  child: StIcon(Icons.star_rounded, size: 16, color: gold),
                ),
                const SizedBox(width: StSpace.xs),
                Expanded(
                  child: Text(
                    overline,
                    style: text.labelMedium?.copyWith(color: onHero),
                  ),
                ),
              ],
            ),
            const SizedBox(height: StSpace.xs),
            Semantics(
              header: true,
              child: Text(
                headline,
                style: text.headlineSmall?.copyWith(color: onHero),
              ),
            ),
            const SizedBox(height: StSpace.xs),
            Text(
              subtitle,
              style: text.bodyMedium?.copyWith(color: subtitleColor),
            ),
            const SizedBox(height: StSpace.md),
            FilledButton(
              key: const Key('home-start-game'),
              style: FilledButton.styleFrom(
                backgroundColor: buttonBackground,
                foregroundColor: buttonForeground,
              ),
              onPressed: () => context.go(AppRoutes.setup),
              child: const Text('Start a game', textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }
}

class _HowItWorksStep {
  const _HowItWorksStep(this.icon, this.title, this.body);

  final IconData icon;
  final String title;
  final String body;
}

const _howItWorks = <_HowItWorksStep>[
  _HowItWorksStep(
    Icons.menu_book_rounded,
    'Choose your scriptures',
    'Pick one volume, a few, or all five.',
  ),
  _HowItWorksStep(
    Icons.check_circle_rounded,
    'Answer and learn',
    'See right away if you were correct, with a reference to study.',
  ),
  _HowItWorksStep(
    Icons.emoji_events_rounded,
    'Track your progress',
    'Scores and streaks are saved on this device.',
  ),
];

class _HowItWorksCard extends StatelessWidget {
  const _HowItWorksCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: const Key('home-how-it-works'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: StSpace.sm),
        child: Column(
          children: [
            for (var i = 0; i < _howItWorks.length; i++) ...[
              if (i > 0)
                Divider(
                  height: StSpace.md,
                  thickness: 1,
                  indent: _howItWorksDividerIndent,
                  color: scheme.outlineVariant,
                ),
              _HowItWorksRow(step: _howItWorks[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _HowItWorksRow extends StatelessWidget {
  const _HowItWorksRow({required this.step});

  final _HowItWorksStep step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: StSpace.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: SizedBox(
              width: 36,
              height: 36,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: StIcon(
                    step.icon,
                    size: 20,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: StSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step.title, style: text.titleMedium),
                Text(
                  step.body,
                  style: text.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
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
    final text = theme.textTheme;
    return DecoratedBox(
      key: const Key('home-empty-stats'),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: const BorderRadius.all(StRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          StSpace.md,
          _cardInset,
          StSpace.md,
          _cardInset,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: StIcon(Icons.bar_chart_rounded, color: scheme.outline),
            ),
            const SizedBox(width: StSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('No games yet', style: text.titleMedium),
                  Text(
                    'Your stats will appear here after your first game.',
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayAgainCard extends StatelessWidget {
  const _PlayAgainCard({required this.settings});

  final LastGameSettings settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final spoken = playAgainSemanticsLabel(settings);
    return Semantics(
      button: true,
      label: spoken,
      onTap: () => openPlayAgain(context, settings),
      excludeSemantics: true,
      child: Card(
        key: const Key('home-play-again'),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openPlayAgain(context, settings),
          child: ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                StSpace.md,
                _cardInset,
                StSpace.sm,
                _cardInset,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: StIcon(
                          Icons.replay_rounded,
                          color: scheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: _cardInset),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Play again', style: text.titleMedium),
                        Text(
                          playAgainSubtitle(settings),
                          style: text.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: _cardInset),
                  StIcon(
                    Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: SectionLabel('Your progress')),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.primary,
            padding: const EdgeInsets.symmetric(horizontal: StSpace.xs),
          ),
          onPressed: () => context.go(AppRoutes.stats),
          child: const Text('See all'),
        ),
      ],
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.game,
    required this.snapshot,
    required this.now,
  });

  final LastGameSummary? game;
  final HomeSnapshot snapshot;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final gold = theme.extension<StColors>()!.gold;
    final large = isLargeText(context);
    final stats = [
      _Stat(value: '${snapshot.gamesPlayed}', label: 'Games'),
      _Stat(value: '${snapshot.accuracyPercent}%', label: 'Accuracy'),
      _Stat(
        value: '${snapshot.bestStreak}',
        label: 'Best streak',
        leading: StIcon(
          Icons.local_fire_department_rounded,
          size: 20,
          color: gold,
        ),
      ),
    ];

    return Card(
      key: const Key('home-progress'),
      child: Padding(
        padding: const EdgeInsets.all(StSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (large)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < stats.length; i++) ...[
                    if (i > 0) const SizedBox(height: StSpace.sm),
                    stats[i],
                  ],
                ],
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [for (final stat in stats) Expanded(child: stat)],
              ),
            if (game != null) ...[
              const SizedBox(height: StSpace.sm),
              Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
              const SizedBox(height: StSpace.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: ExcludeSemantics(
                      child: StIcon(
                        Icons.emoji_events_rounded,
                        size: 18,
                        color: gold,
                      ),
                    ),
                  ),
                  const SizedBox(width: StSpace.xs),
                  Expanded(
                    child: Text(
                      lastGameLine(game!, now),
                      semanticsLabel: lastGameSemanticsLabel(game!, now),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.leading});

  final String value;
  final String label;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alignStart = isLargeText(context);
    final valueStyle = theme.textTheme.headlineSmall;
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: alignStart
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading case final icon?) ...[
                ExcludeSemantics(child: icon),
                const SizedBox(width: StSpace.xxs),
              ],
              Text(value, style: valueStyle),
            ],
          ),
          Text(
            label,
            textAlign: alignStart ? TextAlign.start : TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
