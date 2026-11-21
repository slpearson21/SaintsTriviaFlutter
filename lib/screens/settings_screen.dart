import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_info.dart';
import '../layout/home_back_button.dart';
import '../layout/platform_style.dart';
import '../layout/section_label.dart';
import '../layout/st_icon.dart';
import '../layout/text_scale.dart';
import '../persistence/persistence_providers.dart';
import '../progress/home_providers.dart';
import '../report/report_config.dart';
import '../services/open_link.dart';
import '../theme/st_theme.dart';

const scriptureTriviaDisclaimer =
    'LDS Scripture Trivia is a free, unofficial app. It is not an official '
    'product of, or endorsed by, The Church of Jesus Christ of Latter-day Saints.';

/// v1 hides Send feedback. The row stays in source behind this flag, so
/// turning it on is a one-line change.
const bool kShowSendFeedback = false;

/// Same inbox as question reports. [feedbackUri] uses [Uri.encodeComponent]
/// so a space in the subject stays `%20`. `Uri.queryParameters` would
/// write `+`, which iOS Mail shows as a plus.
const feedbackRecipient = kReportEmail;

final feedbackUri = Uri.parse(
  'mailto:$feedbackRecipient?subject=${Uri.encodeComponent('LDS Scripture Trivia feedback')}',
);

/// S12 / S13. Appearance, feedback, gameplay, and on-device data.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final material = usesMaterialChrome();
    final large = isLargeText(context);
    final controller = ref.read(settingsProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        centerTitle: !material,
        toolbarHeight: largeTitleToolbarHeight(context),
        leadingWidth: HomeBackButton.leadingWidth(context),
        leading: const HomeBackButton(),
        title: const Text('Settings', maxLines: 2),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            StSpace.screenH,
            StSpace.md,
            StSpace.screenH,
            StSpace.xl,
          ),
          children: [
            const SectionLabel('Appearance'),
            const SizedBox(height: StSpace.sm),
            large
                ? _ThemeList(
                    mode: settings.themeMode,
                    onChanged: controller.setThemeMode,
                  )
                : _ThemeSegments(
                    mode: settings.themeMode,
                    onChanged: controller.setThemeMode,
                  ),
            const SizedBox(height: StSpace.lg),
            const SectionLabel('Sound & haptics'),
            const SizedBox(height: StSpace.sm),
            _Group(
              children: [
                _ToggleRow(
                  key: const Key('settings-sound'),
                  title: 'Sound effects',
                  value: settings.soundEffects,
                  onChanged: controller.setSoundEffects,
                ),
                _ToggleRow(
                  key: const Key('settings-haptics'),
                  title: 'Haptics',
                  value: settings.haptics,
                  onChanged: controller.setHaptics,
                ),
              ],
            ),
            const SizedBox(height: StSpace.lg),
            const SectionLabel('Gameplay'),
            const SizedBox(height: StSpace.sm),
            _Group(
              children: [
                _ToggleRow(
                  key: const Key('settings-explanations'),
                  title: 'Show explanations',
                  subtitle: 'One-line explanation after each answer.',
                  value: settings.showExplanations,
                  onChanged: controller.setShowExplanations,
                ),
              ],
            ),
            const SizedBox(height: StSpace.lg),
            const SectionLabel('Data'),
            const SizedBox(height: StSpace.sm),
            _ResetCard(onPressed: () => unawaited(_confirmReset(context, ref))),
            const SizedBox(height: StSpace.lg),
            const SectionLabel('About'),
            const SizedBox(height: StSpace.sm),
            _Group(
              children: [
                if (kShowSendFeedback)
                  _LinkRow(
                    key: const Key('settings-feedback'),
                    icon: Icons.mail_outline,
                    title: 'Send feedback',
                    onPressed: () => unawaited(_sendFeedback(context, ref)),
                  ),
                _LinkRow(
                  key: const Key('settings-about'),
                  icon: Icons.info_outline,
                  title: 'About LDS Scripture Trivia',
                  trailing: scriptureTriviaVersionLabel,
                  onPressed: () => unawaited(_showAbout(context)),
                ),
              ],
            ),
            const SizedBox(height: StSpace.lg),
            Text(
              scriptureTriviaDisclaimer,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: StSpace.sm),
            Text(
              reportPrivacyLine,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
  final reset = await showResetStatsDialog(context);
  if (!reset || !context.mounted) return;
  ref.read(homeSnapshotProvider.notifier).resetStats();
}

/// Opens the mail app. A `false` result means nothing handled the mailto.
Future<void> sendAppFeedback(BuildContext context, OpenLink open) async {
  final opened = await open(feedbackUri, mode: LaunchMode.platformDefault);
  if (opened || !context.mounted) return;
  ScaffoldMessenger.of(context)
      .showSnackBar(const SnackBar(content: Text('No mail app was found.')));
}

Future<void> _sendFeedback(BuildContext context, WidgetRef ref) {
  return sendAppFeedback(context, ref.read(openLinkProvider));
}

Future<void> _showAbout(BuildContext context) {
  const title = Text('About LDS Scripture Trivia');
  final message = Text(
    '$scriptureTriviaVersionLabel\n\n$scriptureTriviaDisclaimer\n\n$reportPrivacyLine',
  );
  if (!usesMaterialChrome()) {
    return showDialog<void>(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: title,
          content: message,
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
  return showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: title,
        content: message,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      );
    },
  );
}

/// Confirms a stats reset. Cancel leaves everything in place.
Future<bool> showResetStatsDialog(BuildContext context) async {
  const title = Text('Reset all stats?');
  const message = Text(
    "This permanently clears your games, "
    "accuracy and streaks on this device. "
    "This can't be undone.",
  );
  final reset = await showDialog<bool>(
    context: context,
    builder: (context) {
      if (!usesMaterialChrome()) {
        return CupertinoAlertDialog(
          title: title,
          content: message,
          actions: [
            CupertinoDialogAction(
              key: const Key('reset-cancel'),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              key: const Key('reset-confirm'),
              isDestructiveAction: true,
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Reset'),
            ),
          ],
        );
      }
      final error = Theme.of(context).colorScheme.error;
      return AlertDialog(
        title: title,
        content: message,
        actions: [
          TextButton(
            key: const Key('reset-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('reset-confirm'),
            style: TextButton.styleFrom(foregroundColor: error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      );
    },
  );
  return reset ?? false;
}

class _ThemeSegments extends StatelessWidget {
  const _ThemeSegments({required this.mode, required this.onChanged});

  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final material = usesMaterialChrome();
    final selectedBackground = material
        ? scheme.secondaryContainer
        : scheme.surfaceContainerLowest;
    final selectedForeground = material
        ? scheme.onSecondaryContainer
        : scheme.onSurface;
    return SegmentedButton<ThemeMode>(
      style: SegmentedButton.styleFrom(
        minimumSize: const Size(StSpace.minTap, StSpace.minTap),
        backgroundColor: material ? scheme.surface : scheme.surfaceContainer,
        selectedBackgroundColor: selectedBackground,
        foregroundColor: scheme.onSurface,
        selectedForegroundColor: selectedForeground,
        side: BorderSide(color: scheme.outlineVariant),
        tapTargetSize: MaterialTapTargetSize.padded,
        visualDensity: VisualDensity.standard,
      ),
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(
          value: ThemeMode.system,
          label: Text('System'),
          tooltip: 'System',
        ),
        ButtonSegment(
          value: ThemeMode.light,
          label: Text('Light'),
          tooltip: 'Light',
        ),
        ButtonSegment(
          value: ThemeMode.dark,
          label: Text('Dark'),
          tooltip: 'Dark',
        ),
      ],
      selected: {mode},
      onSelectionChanged: (next) {
        if (next.isEmpty) return;
        onChanged(next.first);
      },
    );
  }
}

class _ThemeList extends StatelessWidget {
  const _ThemeList({required this.mode, required this.onChanged});

  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return _Group(
      children: [
        for (final choice in ThemeMode.values)
          _ThemeChoice(
            key: Key('settings-theme-${choice.name}'),
            label: _themeLabel(choice),
            selected: choice == mode,
            onPressed: () => onChanged(choice),
          ),
      ],
    );
  }
}

String _themeLabel(ThemeMode mode) {
  return switch (mode) {
    ThemeMode.system => 'System',
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
  };
}

class _ThemeChoice extends StatelessWidget {
  const _ThemeChoice({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final target = minTapTarget(context);
    return Semantics(
      selected: selected,
      button: true,
      inMutuallyExclusiveGroup: true,
      child: InkWell(
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: target),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: StSpace.md,
              vertical: StSpace.sm,
            ),
            child: Row(
              children: [
                Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
                if (selected)
                  ExcludeSemantics(
                    child: StIcon(Icons.check, color: scheme.primary),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final divider = Divider(
      height: 1,
      thickness: 1,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
    return Card(
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) divider,
            children[i],
          ],
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final target = minTapTarget(context);
    return MergeSemantics(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: target),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: StSpace.md,
            vertical: StSpace.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.bodyLarge),
                    if (subtitle case final text?)
                      Text(
                        text,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: StSpace.sm),
              Switch.adaptive(
                value: value,
                onChanged: onChanged,
                materialTapTargetSize: MaterialTapTargetSize.padded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResetCard extends StatelessWidget {
  const _ResetCard({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final target = minTapTarget(context);
    return Card(
      child: Semantics(
        button: true,
        child: InkWell(
          key: const Key('settings-reset'),
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: target),
            child: Padding(
              padding: const EdgeInsets.all(StSpace.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reset stats',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.error,
                    ),
                  ),
                  Text(
                    'Clears games, accuracy and streaks on this device',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
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

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    super.key,
    required this.icon,
    required this.title,
    required this.onPressed,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? trailing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final target = minTapTarget(context);
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: target),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: StSpace.md,
              vertical: StSpace.sm,
            ),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: StIcon(icon, size: 22, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(width: StSpace.sm),
                Expanded(child: Text(title, style: theme.textTheme.bodyLarge)),
                if (trailing case final label?) ...[
                  const SizedBox(width: StSpace.sm),
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                ExcludeSemantics(
                  child: StIcon(
                    Icons.chevron_right,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
