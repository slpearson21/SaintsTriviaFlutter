import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../game/game_providers.dart';
import '../layout/section_label.dart';
import '../layout/st_icon.dart';
import '../layout/text_scale.dart';
import '../progress/play_again.dart';
import '../results/results_summary.dart';
import '../routing/routes.dart';
import '../theme/st_theme.dart';

/// Which answers the review list is showing.
enum ReviewFilter { all, missed, correct }

/// S10. Every answer from the finished game, with a missed / correct filter.
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  ReviewFilter _filter = ReviewFilter.all;

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.results);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(gameControllerProvider);
    if (!isFinishedSession(session)) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final finished = session!;
    final answers = reviewedAnswers(finished);
    final missed = [
      for (final answer in answers)
        if (!answer.correct) answer,
    ];
    final correct = [
      for (final answer in answers)
        if (answer.correct) answer,
    ];
    final visible = switch (_filter) {
      ReviewFilter.all => answers,
      ReviewFilter.missed => missed,
      ReviewFilter.correct => correct,
    }
    final material = usesMaterialChrome(context);
    final large = isLargeText(context);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: !material,
        toolbarHeight: largeTitleToolbarHeight(context),
        leadingWidth: material ? null : (large ? StSpace.minTap : 148),
        leading: material
            ? IconButton(
                tooltip: 'Back',
                onPressed: _back,
                icon: const StIcon(Icons.arrow_back),
              )
            : _IosResultsBack(showLabel: !large, onPressed: _back),
        title: const Text('Review answers', maxLines: 2),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                StSpace.screenH,
                StSpace.sm,
                StSpace.screenH,
                StSpace.xs,
              ),
              child: Wrap(
                spacing: StSpace.xs,
                runSpacing: StSpace.xs,
                children: [
                  _FilterChip(
                    key: const Key('review-filter-all'),
                    label: 'All (${answers.length})',
                    selected: _filter == ReviewFilter.all,
                    onSelected: () =>
                        setState(() => _filter = ReviewFilter.all),
                  ),
                  _FilterChip(
                    key: const Key('review-filter-missed'),
                    label: 'Missed (${missed.length})',
                    selected: _filter == ReviewFilter.missed,
                    onSelected: () =>
                        setState(() => _filter = ReviewFilter.missed),
                  ),
                  _FilterChip(
                    key: const Key('review-filter-correct'),
                    label: 'Correct (${correct.length})',
                    selected: _filter == ReviewFilter.correct,
                    onSelected: () =>
                        setState(() => _filter = ReviewFilter.correct),
                  ),
                ],
              ),
            ),
            Expanded(
              child: visible.isEmpty
                  ? _EmptyReview(
                      filter: _filter,
                      onPlayAgain: () =>
                          unawaited(dealAndPlayAgain(ref, context, finished)),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(
                        StSpace.screenH,
                        StSpace.sm,
                        StSpace.screenH,
                        StSpace.xl,
                      ),
                      children: [
                        if (_filter != ReviewFilter.correct &&
                            missed.isNotEmpty) ...[
                          const SectionLabel('Missed'),
                          const SizedBox(height: StSpace.sm),
                          for (final answer in missed) ...[
                            _AnswerCard(answer: answer),
                            const SizedBox(height: StSpace.sm),
                          ],
                        ],
                        if (_filter != ReviewFilter.missed &&
                            correct.isNotEmpty) ...[
                          if (_filter == ReviewFilter.all && missed.isNotEmpty)
                            const SizedBox(height: StSpace.sm),
                          const SectionLabel('Correct'),
                          const SizedBox(height: StSpace.sm),
                          for (final answer in correct) ...[
                            _AnswerCard(answer: answer),
                            const SizedBox(height: StSpace.sm),
                          ],
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IosResultsBack extends StatelessWidget {
  const _IosResultsBack({required this.showLabel, required this.onPressed});

  final bool showLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (!showLabel) {
      return IconButton(
        tooltip: 'Results',
        onPressed: onPressed,
        style: IconButton.styleFrom(
          minimumSize: const Size.square(StSpace.minTap),
          tapTargetSize: MaterialTapTargetSize.padded,
          foregroundColor: scheme.primary,
        ),
        icon: StIcon(Icons.arrow_back_ios_new, size: 18, color: scheme.primary),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        style: TextButton.styleFrom(
          minimumSize: const Size(StSpace.minTap, StSpace.minTap),
          padding: const EdgeInsets.symmetric(horizontal: StSpace.xs),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: scheme.primary,
        ),
        onPressed: onPressed,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StIcon(Icons.arrow_back_ios_new, size: 18),
            SizedBox(width: 2),
            Text('Results'),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: true,
      onSelected: (_) => onSelected(),
      selectedColor: scheme.primary,
      checkmarkColor: scheme.onPrimary,
      backgroundColor: scheme.surface,
      labelStyle: theme.textTheme.labelLarge?.copyWith(
        color: selected ? scheme.onPrimary : scheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide(color: selected ? scheme.primary : scheme.outline),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(StRadius.md),
      ),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      padding: const EdgeInsets.symmetric(
        horizontal: StSpace.xs,
        vertical: StSpace.sm,
      ),
    );
  }
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({required this.answer});

  final ReviewedAnswer answer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<StColors>()!;
    final correct = answer.correct;
    final mark = correct ? colors.correct : colors.wrong;
    final status = correct ? 'Correct' : 'Missed';
    // The status label lives inside MergeSemantics. A label on a parent
    // outside that boundary is a second screen-reader stop.
    return MergeSemantics(
      key: Key('review-answer-${answer.question.id}'),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(StSpace.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    label: status,
                    excludeSemantics: true,
                    child: StIcon(
                      correct ? Icons.check_circle : Icons.cancel,
                      size: 22,
                      color: mark,
                    ),
                  ),
                  const SizedBox(width: StSpace.sm),
                  Expanded(
                    child: Text(
                      answer.question.prompt,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 22 + StSpace.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: StSpace.xs),
                    if (correct)
                      _AnswerLine(
                        label: 'Correct answer',
                        value: answer.correctText,
                        color: colors.correct,
                      )
                    else ...[
                      _AnswerLine(
                        label: 'Your answer',
                        value: answer.selectedText,
                        color: colors.wrong,
                      ),
                      const SizedBox(height: StSpace.xxs),
                      _AnswerLine(
                        label: 'Correct answer',
                        value: answer.correctText,
                        color: colors.correct,
                      ),
                    ],
                    const SizedBox(height: StSpace.sm),
                    _ReferenceChip(reference: answer.question.reference),
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

class _AnswerLine extends StatelessWidget {
  const _AnswerLine({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium
        ?.copyWith(color: color);
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }
}

class _ReferenceChip extends StatelessWidget {
  const _ReferenceChip({required this.reference});

  final String reference;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: const BorderRadius.all(StRadius.full),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: StSpace.sm,
          vertical: StSpace.xxs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: ExcludeSemantics(
                child: StIcon(
                  Icons.menu_book_rounded,
                  size: 16,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: StSpace.xxs),
            Flexible(
              child: Text(
                reference,
                softWrap: true,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyReview extends StatelessWidget {
  const _EmptyReview({required this.filter, required this.onPlayAgain});

  final ReviewFilter filter;
  final VoidCallback onPlayAgain;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = theme.extension<StColors>()!;
    final missed = filter == ReviewFilter.missed;
    final title = missed
        ? "You didn't miss any"
        : 'No correct answers this time';
    final body = missed
        ? 'A perfect game! Try a longer game or '
              'add more scriptures for a new challenge.'
        : 'Check Missed to see the right answers.';
    final icon = missed ? Icons.check_rounded : Icons.menu_book_rounded;
    final iconColor = missed ? colors.correct : scheme.primary;
    final disc = missed ? colors.correctContainer : scheme.primaryContainer;
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: StSpace.screenH),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Column(
                key: const Key('review-empty'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  ExcludeSemantics(
                    child: SizedBox(
                      width: 88,
                      height: 88,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: disc,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: StIcon(icon, size: 40, color: iconColor),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: StSpace.lg),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: StSpace.xs),
                  Text(
                    body,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (missed) ...[
                    const SizedBox(height: StSpace.lg),
                    FilledButton(
                      key: const Key('review-play-again'),
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.primaryContainer,
                        foregroundColor: scheme.onPrimaryContainer,
                        minimumSize: const Size(220, 52),
                      ),
                      onPressed: onPlayAgain,
                      child: const Text('Play again'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
