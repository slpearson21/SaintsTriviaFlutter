import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../data/questions/question_bank.dart';
import '../data/questions/question_bank_provider.dart';
import '../data/questions/scripture_volume.dart';
import '../game/game_engine.dart';
import '../game/game_providers.dart';
import '../layout/screen_body.dart';
import '../layout/st_icon.dart';
import '../layout/platform_style.dart';
import '../layout/text_scale.dart' hide usesMaterialChrome;
import '../progress/home_snapshot.dart';
import '../routing/routes.dart';
import '../theme/st_theme.dart';
import 'content_load_error_screen.dart';

/// Presets from the setup mockups. Anything above the cap is disabled.
const _presets = <int>[5, 10, 20, 50];

/// Fresh games start at 10 questions, then clamp to the selection.
const _defaultQuestionCount = 10;

/// Volume picker and length. Start deals the game, then opens it.
class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key, this.initial});

  /// Last game, when Play again opened this screen. Null for a new game.
  final LastGameSettings? initial;

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  late final Set<ScriptureVolume> _selected;
  late int _requested;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial == null) {
      _selected = ScriptureVolume.values.toSet();
      _requested = _defaultQuestionCount;
      return;
    }
    _selected = initial.volumes.toSet();
    _requested = initial.questionCount.clamp(1, maxQuestionsPerGame);
  }

  void _setRequested(int count) {
    if (count < 1 || count > maxQuestionsPerGame) return;
    setState(() => _requested = count);
  }

  void _step(int delta, QuestionBank? bank) {
    final next = _visibleCount(bank) + delta;
    final cap = _cap(bank);
    if (next < 1 || next > cap) return;
    _setRequested(next);
  }

  void _toggle(ScriptureVolume volume) {
    setState(() {
      if (!_selected.add(volume)) _selected.remove(volume);
    });
  }

  void _toggleAll() {
    setState(() {
      if (_selected.length == ScriptureVolume.values.length) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(ScriptureVolume.values);
      }
    });
  }

  int _poolSize(QuestionBank? bank) {
    if (bank == null || _selected.isEmpty) return 0;
    var total = 0;
    for (final volume in ScriptureVolume.values) {
      if (_selected.contains(volume)) {
        total += bank.forVolume(volume).length;
      }
    }
    return total;
  }

  int _max(QuestionBank? bank) => maxAvailableQuestions(_poolSize(bank));

  /// Stepper ceiling: 50 with nothing chosen, otherwise the selection cap.
  ///
  /// An empty pool still lets the player set a length. Start stays disabled
  /// until the selection actually has a question.
  int _cap(QuestionBank? bank) {
    if (bank == null || _selected.isEmpty) return maxQuestionsPerGame;
    final max = _max(bank);
    if (max <= 0) return maxQuestionsPerGame;
    return max;
  }

  int _visibleCount(QuestionBank? bank) {
    final requested = _requested.clamp(1, maxQuestionsPerGame);
    final cap = _cap(bank);
    if (requested > cap) return cap;
    return requested;
  }

  bool _showClampBanner(QuestionBank? bank) {
    if (bank == null || _selected.isEmpty) return false;
    final max = _max(bank);
    return max > 0 && _requested > max;
  }

  bool _canStart(AsyncValue<QuestionBank> bankAsync) {
    if (_selected.isEmpty) return false;
    final bank = bankAsync.asData?.value;
    // Still loading: the game screen deals when the bank arrives. A failed
    // load has nothing to deal, so Start stays off.
    if (bank == null) return !bankAsync.hasError;
    final max = _max(bank);
    final count = _visibleCount(bank);
    return max > 0 &&
        count >= 1 &&
        count <= max &&
        count <= maxQuestionsPerGame;
  }

  void _start(AsyncValue<QuestionBank> bankAsync) {
    final bank = bankAsync.asData?.value;
    if (!_canStart(bankAsync)) return;
    final count = _visibleCount(bank);
    final volumes = [
      for (final volume in ScriptureVolume.values)
        if (_selected.contains(volume)) volume,
    ];
    final settings = LastGameSettings(volumes: volumes, questionCount: count);
    if (bank != null) {
      // Deal before the route changes so GameScreen's first frame is this
      // game, not the previous finished session.
      ref
          .read(gameControllerProvider.notifier)
          .start(bank: bank, volumes: volumes, requestedCount: count);
    }
    context.go(AppRoutes.game, extra: settings);
  }

  @override
  Widget build(BuildContext context) {
    // Watch only a load the splash (or a test) already started. Watching an
    // untouched provider would open the 5s timeout from this screen.
    final bankAsync = ref.read(questionBankProvider.exists)
        ? ref.watch(questionBankProvider)
        : const AsyncLoading<QuestionBank>();
    if (bankAsync.hasError) {
      return const ContentLoadErrorView(showNewGameBar: true);
    }
    final bank = bankAsync.asData?.value;
    final visible = _visibleCount(bank);
    final cap = _cap(bank);
    final canStart = _canStart(bankAsync);
    final banner = _showClampBanner(bank)
        ? _clampBanner(
            volumes: [
              for (final volume in ScriptureVolume.values)
                if (_selected.contains(volume)) volume,
            ],
            available: _max(bank),
          )
        : null;
    final material = usesMaterialChrome(context);
    final large = isLargeText(context);

    return Scaffold(
      appBar: AppBar(
        centerTitle: !material,
        toolbarHeight: largeTitleToolbarHeight(context),
        leadingWidth: !material && !large ? 112 : null,
        leading: _SetupBackButton(showHomeLabel: !material && !large),
        title: const Text('New game', maxLines: 2),
      ),
      body: ScreenBody(
        primary: _StartButton(
          label: _startLabel(enabled: canStart, count: visible),
          enabled: canStart,
          onPressed: () => _start(bankAsync),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionLabel('Choose scriptures'),
            const SizedBox(height: StSpace.sm),
            _VolumeCard(
              bank: bank,
              selected: _selected,
              onToggle: _toggle,
              onToggleAll: _toggleAll,
            ),
            const SizedBox(height: StSpace.lg),
            const _SectionLabel('Number of questions'),
            const SizedBox(height: StSpace.sm),
            if (banner != null) ...[
              _ClampBanner(message: banner),
              const SizedBox(height: StSpace.sm),
            ],
            _CountCard(
              count: visible,
              cap: cap,
              canDecrement: visible > 1,
              canIncrement: visible < cap,
              helper: _countHelper(
                bank: bank,
                hasSelection: _selected.isNotEmpty,
                maxAvailable: _max(bank),
                count: visible,
              ),
              helperIcon: _selected.isEmpty || bank == null || _max(bank) <= 0,
              onDecrement: () => _step(-1, bank),
              onIncrement: () => _step(1, bank),
              onPreset: _setRequested,
            ),
          ],
        ),
      ),
    );
  }
}

String _word(int count) => count == 1 ? 'question' : 'questions';

String _formatQuestionCount(int count) {
  return '${_grouped(count)} ${_word(count)}';
}

String _grouped(int count) {
  final digits = count.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return count < 0 ? '-$buffer' : buffer.toString();
}

String _startLabel({required bool enabled, required int count}) {
  if (!enabled) return 'Start game';
  return 'Start game · $count ${_word(count)}';
}

/// "Pearl of Great Price has 23 questions, so this game will have 23."
String _clampBanner({
  required List<ScriptureVolume> volumes,
  required int available,
}) {
  final has = available == 1 ? 'has 1 question' : 'has $available questions';
  final tail = 'so this game will have $available.';
  if (volumes.length == 1) {
    return '${volumes.single.label} $has, $tail';
  }
  return 'This selection $has, $tail';
}

String _countHelper({
  required QuestionBank? bank,
  required bool hasSelection,
  required int maxAvailable,
  required int count,
}) {
  if (bank == null) return 'Loading questions…';
  if (!hasSelection) return 'Choose at least one book of scripture';
  if (maxAvailable <= 0) {
    return 'No questions available for this selection';
  }
  if (maxAvailable < maxQuestionsPerGame) {
    return 'Only $maxAvailable ${_word(maxAvailable)} available for this selection';
  }
  if (count >= maxQuestionsPerGame) return '50 is the maximum';
  return 'Up to 50 questions per game';
}

class _SetupBackButton extends StatelessWidget {
  const _SetupBackButton({required this.showHomeLabel});

  final bool showHomeLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final target = minTapTarget(context);
    if (!showHomeLabel) {
      final material = usesMaterialChrome(context);
      return IconButton(
        tooltip: material ? 'Back' : 'Home',
        onPressed: () => _leave(context),
        style: IconButton.styleFrom(
          minimumSize: Size.square(target),
          tapTargetSize: MaterialTapTargetSize.padded,
          foregroundColor: material ? null : scheme.primary,
        ),
        icon: StIcon(
          material ? Icons.arrow_back : Icons.arrow_back_ios_new,
          size: material ? 24 : 20,
          color: material ? null : scheme.primary,
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        style: TextButton.styleFrom(
          minimumSize: Size(target, target),
          padding: const EdgeInsets.symmetric(horizontal: StSpace.xs),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: scheme.primary,
        ),
        onPressed: () => _leave(context),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StIcon(Icons.arrow_back_ios_new, size: 18),
            SizedBox(width: 2),
            Text('Home'),
          ],
        ),
      ),
    );
  }
}

void _leave(BuildContext context) {
  if (context.canPop()) {
    context.pop();
    return;
  }
  context.go(AppRoutes.home);
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final material = usesMaterialChrome(context);
    final style = material
        ? theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)
        : theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          );
    return Semantics(
      header: true,
      child: Text(
        material ? title : title.toUpperCase(),
        semanticsLabel: title,
        style: style,
      ),
    );
  }
}

class _VolumeCard extends StatelessWidget {
  const _VolumeCard({
    required this.bank,
    required this.selected,
    required this.onToggle,
    required this.onToggleAll,
  });

  final QuestionBank? bank;
  final Set<ScriptureVolume> selected;
  final void Function(ScriptureVolume volume) onToggle;
  final VoidCallback onToggleAll;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loaded = bank;
    final all = selected.length == ScriptureVolume.values.length;
    final none = selected.isEmpty;
    final selectAllValue = all ? true : (none ? false : null);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _VolumeRow(
            title: 'Select all',
            subtitle:
                '${selected.length} of ${ScriptureVolume.values.length} selected',
            checked: selectAllValue,
            tristate: true,
            checkKey: const Key('setup-select-all'),
            icon: _VolumeBadge(
              icon: Icons.menu_book_rounded,
              color: scheme.onPrimaryContainer,
              background: scheme.primaryContainer,
            ),
            onTap: onToggleAll,
          ),
          for (final volume in ScriptureVolume.values) ...[
            Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
            _VolumeRow(
              title: volume.label,
              subtitle: loaded == null
                  ? '…'
                  : _formatQuestionCount(loaded.forVolume(volume).length),
              checked: selected.contains(volume),
              checkKey: Key('setup-check-${volume.name}'),
              icon: _VolumeBadge(
                icon: _volumeIcon(volume),
                color: _volumeColor(context, volume),
                background: _volumeColor(
                  context,
                  volume,
                ).withValues(alpha: 0.18),
              ),
              onTap: () => onToggle(volume),
            ),
          ],
        ],
      ),
    );
  }
}

IconData _volumeIcon(ScriptureVolume volume) {
  return switch (volume) {
    ScriptureVolume.ot => Icons.article_outlined,
    ScriptureVolume.nt => Icons.wb_sunny_outlined,
    ScriptureVolume.bom => Icons.auto_stories_rounded,
    ScriptureVolume.dc => Icons.menu_book_outlined,
    ScriptureVolume.pgp => Icons.diamond_outlined,
  };
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

Color _volumeColor(BuildContext context, ScriptureVolume volume) {
  return Theme.of(context).extension<StColors>()!.volume[_themeVolume(volume)]!;
}

class _VolumeBadge extends StatelessWidget {
  const _VolumeBadge({
    required this.icon,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: DecoratedBox(
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: Center(child: StIcon(icon, size: 20, color: color)),
      ),
    );
  }
}

class _VolumeRow extends StatelessWidget {
  const _VolumeRow({
    required this.title,
    required this.subtitle,
    required this.checked,
    required this.icon,
    required this.onTap,
    required this.checkKey,
    this.tristate = false,
  });

  final String title;
  final String subtitle;
  final bool? checked;
  final bool tristate;
  final Widget icon;
  final VoidCallback onTap;
  final Key checkKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final large = isLargeText(context);
    final minHeight = minTapTarget(context) < 52 ? 52.0 : minTapTarget(context);
    return Semantics(
      button: true,
      checked: checked == true,
      mixed: checked == null,
      label: '$title, $subtitle',
      child: InkWell(
        onTap: onTap,
        child: ExcludeSemantics(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: StSpace.md,
                vertical: StSpace.sm,
              ),
              child: Row(
                crossAxisAlignment: large
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.center,
                children: [
                  icon,
                  const SizedBox(width: StSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.textTheme.titleMedium),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _CheckMark(key: checkKey, value: checked, tristate: tristate),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckMark extends StatelessWidget {
  const _CheckMark({super.key, required this.value, required this.tristate});

  final bool? value;
  final bool tristate;

  @override
  Widget build(BuildContext context) {
    if (usesMaterialChrome(context)) {
      return IgnorePointer(
        child: Checkbox(
          value: value,
          tristate: tristate || value == null,
          onChanged: (_) {},
        ),
      );
    }
    return _IosCheck(value: value);
  }
}

class _IosCheck extends StatelessWidget {
  const _IosCheck({required this.value});

  final bool? value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final filled = value != false;
    return SizedBox(
      width: 28,
      height: 28,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? scheme.primary : Colors.transparent,
          border: filled ? null : Border.all(color: scheme.outline, width: 1.5),
        ),
        child: filled
            ? Center(
                child: StIcon(
                  value == null ? Icons.remove : Icons.check,
                  size: 16,
                  color: scheme.onPrimary,
                ),
              )
            : null,
      ),
    );
  }
}

class _ClampBanner extends StatelessWidget {
  const _ClampBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return DecoratedBox(
      key: const Key('setup-clamp-banner'),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: const BorderRadius.all(StRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(StSpace.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StIcon(
              Icons.info_outline,
              size: 20,
              color: scheme.onSecondaryContainer,
            ),
            const SizedBox(width: StSpace.sm),
            Expanded(
              child: Text(
                message,
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSecondaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({
    required this.count,
    required this.cap,
    required this.canDecrement,
    required this.canIncrement,
    required this.helper,
    required this.helperIcon,
    required this.onDecrement,
    required this.onIncrement,
    required this.onPreset,
  });

  final int count;
  final int cap;
  final bool canDecrement;
  final bool canIncrement;
  final String helper;
  final bool helperIcon;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final ValueChanged<int> onPreset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final large = isLargeText(context);
    final number = Text(
      '$count',
      key: const Key('setup-count'),
      style: theme.textTheme.displaySmall,
    );
    final label = Text(
      _word(count),
      key: const Key('setup-count-label'),
      style: theme.textTheme.bodyLarge?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(StSpace.md),
        child: Column(
          children: [
            Row(
              children: [
                _StepButton(
                  tooltip: 'Fewer questions',
                  icon: Icons.remove,
                  enabled: canDecrement,
                  value: '$count ${_word(count)}',
                  onPressed: onDecrement,
                ),
                Expanded(
                  child: Semantics(
                    container: true,
                    liveRegion: true,
                    label: '$count ${_word(count)}',
                    excludeSemantics: true,
                    child: large
                        ? Column(children: [number, label])
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              number,
                              const SizedBox(width: StSpace.xs),
                              Flexible(child: label),
                            ],
                          ),
                  ),
                ),
                _StepButton(
                  tooltip: 'More questions',
                  icon: Icons.add,
                  enabled: canIncrement,
                  value: '$count ${_word(count)}',
                  onPressed: onIncrement,
                ),
              ],
            ),
            const SizedBox(height: StSpace.md),
            _PresetRow(count: count, cap: cap, onPreset: onPreset),
            const SizedBox(height: StSpace.sm),
            _HelperLine(message: helper, showIcon: helperIcon),
          ],
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.tooltip,
    required this.icon,
    required this.enabled,
    required this.value,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final bool enabled;

  /// Current length, such as "11 questions", read after each tap.
  final String value;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final target = minTapTarget(context);
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: tooltip,
      value: value,
      onTap: enabled ? onPressed : null,
      excludeSemantics: true,
      child: IconButton(
        tooltip: tooltip,
        onPressed: enabled ? onPressed : null,
        style: IconButton.styleFrom(
          minimumSize: Size.square(target),
          tapTargetSize: MaterialTapTargetSize.padded,
          shape: const CircleBorder(),
          side: BorderSide(
            color: enabled ? scheme.outline : scheme.outlineVariant,
          ),
          foregroundColor: scheme.onSurface,
          disabledForegroundColor: scheme.outline,
        ),
        icon: StIcon(icon),
      ),
    );
  }
}

class _PresetRow extends StatelessWidget {
  const _PresetRow({
    required this.count,
    required this.cap,
    required this.onPreset,
  });

  final int count;
  final int cap;
  final ValueChanged<int> onPreset;

  @override
  Widget build(BuildContext context) {
    final large = isLargeText(context);
    final chips = [
      for (final preset in _presets)
        _PresetChip(
          preset: preset,
          selected: count == preset,
          enabled: preset <= cap,
          onSelected: () => onPreset(preset),
        ),
    ];
    if (!large) {
      return Row(
        children: [
          for (var i = 0; i < chips.length; i++) ...[
            if (i > 0) const SizedBox(width: StSpace.sm),
            Expanded(child: chips[i]),
          ],
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - StSpace.sm) / 2;
        return Wrap(
          spacing: StSpace.sm,
          runSpacing: StSpace.sm,
          children: [
            for (final chip in chips) SizedBox(width: width, child: chip),
          ],
        );
      },
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.preset,
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  final int preset;
  final bool selected;
  final bool enabled;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final target = minTapTarget(context);
    final on = selected && enabled;
    // Material 3 disabled content and outline are onSurface at 38%.
    final disabled = scheme.onSurface.withValues(alpha: 0.38);
    return Semantics(
      container: true,
      button: true,
      selected: on,
      enabled: enabled,
      label: '$preset questions',
      onTap: enabled ? onSelected : null,
      excludeSemantics: true,
      child: Material(
        key: Key('setup-preset-$preset'),
        color: on ? scheme.primaryContainer : scheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(StRadius.sm),
          side: BorderSide(
            color: enabled
                ? (on ? scheme.primary : scheme.outlineVariant)
                : disabled,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onSelected : null,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: target),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: StSpace.xs,
                vertical: StSpace.xs,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (on) ...[
                    StIcon(Icons.check, size: 16, color: scheme.primary),
                    const SizedBox(width: 2),
                  ],
                  Flexible(
                    child: Text(
                      '$preset',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      style: TextStyle(
                        color: enabled
                            ? (on
                                  ? scheme.onPrimaryContainer
                                  : scheme.onSurface)
                            : disabled,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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

class _HelperLine extends StatelessWidget {
  const _HelperLine({required this.message, required this.showIcon});

  final String message;
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.bodyMedium
        ?.copyWith(color: scheme.onSurfaceVariant);
    final text = Text(
      message,
      key: const Key('setup-count-helper'),
      textAlign: TextAlign.center,
      style: style,
    );
    if (!showIcon) return text;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ExcludeSemantics(
          child: StIcon(
            Icons.info_outline,
            size: 16,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: StSpace.xs),
        Flexible(child: text),
      ],
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      key: const Key('setup-start'),
      onPressed: enabled ? onPressed : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (enabled) ...[
            const StIcon(Icons.play_arrow_rounded, size: 20),
            const SizedBox(width: StSpace.xs),
          ],
          Flexible(child: Text(label, textAlign: TextAlign.center)),
        ],
      ),
    );
  }
}
