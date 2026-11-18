import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../layout/section_label.dart';
import '../layout/st_icon.dart';
import '../layout/text_scale.dart';
import '../app_info.dart';
import '../services/open_link.dart';
import '../theme/st_theme.dart';
import 'question_report.dart';
import 'report_config.dart';
import 'reported_questions_provider.dart';

/// The question a report is about, with the answer text rather than an index.
final class ReportTarget {
  const ReportTarget({
    required this.questionId,
    required this.prompt,
    required this.correctAnswer,
    required this.selectedAnswer,
    required this.reference,
    required this.source,
  });

  final String questionId;
  final String prompt;
  final String correctAnswer;
  final String selectedAnswer;
  final String reference;

  /// `game` or `review`.
  final String source;
}

const reportFlagTooltip = 'Report a problem with this question';
const reportThanksLine = 'Thanks. If you sent the email, we’ll take a look.';
const reportAnnouncement =
    'Marked as reported. If you sent the email, we’ll take a look.';
const reportSheetTitle = 'Report a problem';
const reportContinueLabel = 'Continue in email';
const reportChooseReasonHint = 'Choose a reason first';
const reportExpectation =
    'Opens your mail app with the details filled in. You can check it before you send.';
const reportNoMailTitle = 'No mail app found';
const reportNoMailBody = 'We copied your report. Paste it into an email to:';
const reportAddressCopied = 'Address copied';
const reportReportedHint = 'Opens the report again';

/// Flag at the end of a reference row. Idle until this question is reported.
class ReportFlag extends ConsumerStatefulWidget {
  const ReportFlag({super.key, required this.target});

  final ReportTarget target;

  @override
  ConsumerState<ReportFlag> createState() => _ReportFlagState();
}

class _ReportFlagState extends ConsumerState<ReportFlag> {
  final _focusNode = FocusNode();
  AppLifecycleListener? _listener;
  Timer? _announceTimer;

  @override
  void dispose() {
    _announceTimer?.cancel();
    _listener?.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    final opened = await showReportSheet(context, ref, target: widget.target);
    if (!mounted) return;
    _focusNode.requestFocus();
    if (opened == true) {
      _announceWhenBack();
      return;
    }
    if (opened == false) await showNoMailDialog(context);
  }

  void _announceWhenBack() {
    var announced = false;
    void announce() {
      if (announced) return;
      announced = true;
      _announceTimer?.cancel();
      _listener?.dispose();
      _listener = null;
      if (!mounted) return;
      unawaited(
        SemanticsService.sendAnnouncement(
          View.of(context),
          reportAnnouncement,
          Directionality.of(context),
        ),
      );
    }

    _listener?.dispose();
    var paused = false;
    _listener = AppLifecycleListener(
      onPause: () => paused = true,
      onInactive: () => paused = true,
      onResume: () {
        if (paused) announce();
      },
    );
    _announceTimer?.cancel();
    _announceTimer = Timer(const Duration(seconds: 2), () {
      if (paused) return;
      announce();
    });
  }

  @override
  Widget build(BuildContext context) {
    final reported = ref.watch(
      reportedQuestionIdsProvider.select(
        (memory) => memory.isReported(widget.target.questionId),
      ),
    );
    final reduced = _reducedMotion(context);
    final scheme = Theme.of(context).colorScheme;
    return AnimatedSwitcher(
      duration: reduced ? Duration.zero : StMotion.fast,
      child: reported
          ? Semantics(
              key: const ValueKey('reported'),
              button: true,
              label: 'Reported',
              hint: reportReportedHint,
              excludeSemantics: true,
              onTap: _open,
              child: TextButton.icon(
                focusNode: _focusNode,
                onPressed: _open,
                style: TextButton.styleFrom(
                  foregroundColor: scheme.primary,
                  minimumSize: const Size(StSpace.minTap, StSpace.minTap),
                  tapTargetSize: MaterialTapTargetSize.padded,
                  textStyle: Theme.of(context).textTheme.labelLarge,
                ),
                icon: StIcon(Icons.flag, size: 18, color: scheme.primary),
                label: const Text('Reported'),
              ),
            )
          : IconButton(
              key: const ValueKey('idle'),
              focusNode: _focusNode,
              tooltip: reportFlagTooltip,
              onPressed: _open,
              style: IconButton.styleFrom(
                minimumSize: const Size.square(StSpace.minTap),
                tapTargetSize: MaterialTapTargetSize.padded,
              ),
              icon: StIcon(
                Icons.outlined_flag,
                size: 22,
                color: scheme.onSurfaceVariant,
              ),
            ),
    );
  }
}

bool _reducedMotion(BuildContext context) {
  final media = MediaQuery.of(context);
  return media.disableAnimations || media.reduceMotion;
}

bool _reportUsesCupertino() {
  return switch (defaultTargetPlatform) {
    TargetPlatform.iOS || TargetPlatform.macOS => true,
    TargetPlatform.android ||
    TargetPlatform.fuchsia ||
    TargetPlatform.linux ||
    TargetPlatform.windows => false,
  };
}

/// Opens the report sheet. Returns when it closes.
Future<bool?> showReportSheet(
  BuildContext context,
  WidgetRef ref, {
  required ReportTarget target,
}) {
  final media = MediaQuery.of(context);
  final reduced = media.disableAnimations || media.reduceMotion;
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    sheetAnimationStyle: reduced ? AnimationStyle.noAnimation : null,
    builder: (context) {
      return ReportSheet(target: target);
    },
  );
}

class ReportSheet extends ConsumerStatefulWidget {
  const ReportSheet({super.key, required this.target});

  final ReportTarget target;

  @override
  ConsumerState<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<ReportSheet> {
  final _scroll = ScrollController();
  final _note = TextEditingController();
  ReportReason? _reason;
  var _scrolled = false;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    final draft = ref
        .read(reportedQuestionIdsProvider)
        .draftFor(widget.target.questionId);
    _reason = draft?.reason;
    _note.text = draft?.note ?? '';
    _scroll.addListener(() {
      final next = _scroll.hasClients && _scroll.offset > 0;
      if (next != _scrolled && mounted) setState(() => _scrolled = next);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _note.dispose();
    super.dispose();
  }

  void _saveDraft() {
    ref
        .read(reportedQuestionIdsProvider.notifier)
        .saveDraft(
          widget.target.questionId,
          reason: _reason,
          note: _note.text,
          clearReason: _reason == null,
        );
  }

  void _select(ReportReason reason) {
    setState(() => _reason = reason);
    _saveDraft();
  }

  Future<void> _continue() async {
    final reason = _reason;
    if (_busy || reason == null) return;
    _busy = true;
    _saveDraft();
    final report = QuestionReport(
      questionId: widget.target.questionId,
      prompt: widget.target.prompt,
      correctAnswer: widget.target.correctAnswer,
      selectedAnswer: widget.target.selectedAnswer,
      reference: widget.target.reference,
      reason: reason,
      note: _note.text,
      appVersion: scriptureTriviaVersionLabel,
      platform: reportPlatformLabel(),
      bankVersion: 'v1',
      source: widget.target.source,
      createdAtUtc: DateTime.now().toUtc(),
    );
    final uri = report.mailto;
    var opened = false;
    try {
      final canOpen = await ref.read(canOpenLinkProvider)(uri);
      opened =
          canOpen &&
          await ref.read(openLinkProvider)(
            uri,
            mode: LaunchMode.externalApplication,
          );
    } on Object {
      opened = false;
    }
    if (!opened) {
      await Clipboard.setData(ClipboardData(text: report.clipboardText));
    }
    if (!mounted) return;
    ref
        .read(reportedQuestionIdsProvider.notifier)
        .markReported(widget.target.questionId);
    Navigator.of(context).pop(opened);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final large = isLargeText(context);
    final cupertino = _reportUsesCupertino();
    final hint = _reason?.noteHint ?? reportNoteHintNone;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.92;
    return ConstrainedBox(
      key: const Key('report-sheet'),
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Material(
        color: scheme.surfaceContainerLowest,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(
                  StSpace.screenH,
                  0,
                  StSpace.screenH,
                  StSpace.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Focus(
                      autofocus: true,
                      child: Semantics(
                        header: true,
                        child: Text(
                          reportSheetTitle,
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                    ),
                    const SizedBox(height: StSpace.xxs),
                    Text(
                      widget.target.prompt,
                      maxLines: large ? 3 : 2,
                      overflow: TextOverflow.ellipsis,
                      semanticsLabel: widget.target.prompt,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: StSpace.md),
                    const SectionLabel("What’s wrong?"),
                    const SizedBox(height: StSpace.sm),
                    if (cupertino)
                      _IosReasons(selected: _reason, onSelected: _select)
                    else
                      _AndroidReasons(selected: _reason, onSelected: _select),
                    const SizedBox(height: StSpace.md),
                    TextField(
                      key: const Key('report-note'),
                      controller: _note,
                      minLines: 3,
                      maxLines: 5,
                      maxLength: maxReportNoteLength,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: 'Note (optional)',
                        hintText: hint,
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(StRadius.md),
                        ),
                      ),
                      onChanged: (value) {
                        ref
                            .read(reportedQuestionIdsProvider.notifier)
                            .saveDraft(widget.target.questionId, note: value);
                      },
                    ),
                    const SizedBox(height: StSpace.sm),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.mail_outline,
                          size: 18,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: StSpace.xs),
                        Expanded(
                          child: Text(
                            reportExpectation,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 13,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (_scrolled) Divider(height: 1, color: scheme.outlineVariant),
            Padding(
              padding: EdgeInsets.fromLTRB(
                StSpace.screenH,
                StSpace.xs,
                StSpace.screenH,
                StSpace.md + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    key: const Key('report-continue'),
                    button: true,
                    enabled: _reason != null && !_busy,
                    label: reportContinueLabel,
                    hint: _reason == null ? reportChooseReasonHint : null,
                    excludeSemantics: true,
                    onTap: _reason == null || _busy ? null : _continue,
                    child: FilledButton.icon(
                      onPressed: _reason == null || _busy ? null : _continue,
                      style: FilledButton.styleFrom(
                        minimumSize: Size.fromHeight(
                          cupertino ? 52 : StSpace.minTap,
                        ),
                      ),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text(reportContinueLabel),
                    ),
                  ),
                  TextButton(
                    key: const Key('report-cancel'),
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      minimumSize: const Size.fromHeight(StSpace.minTap),
                    ),
                    child: const Text('Cancel'),
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

class _IosReasons extends StatelessWidget {
  const _IosReasons({required this.selected, required this.onSelected});

  final ReportReason? selected;
  final ValueChanged<ReportReason> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(StRadius.lg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          for (var i = 0; i < ReportReason.values.length; i++) ...[
            if (i > 0) Divider(height: 1, color: scheme.outlineVariant),
            _ReasonRow(
              reason: ReportReason.values[i],
              selected: selected == ReportReason.values[i],
              showCheck: true,
              onSelected: onSelected,
            ),
          ],
        ],
      ),
    );
  }
}

class _AndroidReasons extends StatelessWidget {
  const _AndroidReasons({required this.selected, required this.onSelected});

  final ReportReason? selected;
  final ValueChanged<ReportReason> onSelected;

  @override
  Widget build(BuildContext context) {
    return RadioGroup<ReportReason>(
      groupValue: selected,
      onChanged: (value) {
        if (value != null) onSelected(value);
      },
      child: Column(
        children: [
          for (final reason in ReportReason.values)
            RadioListTile<ReportReason>(
              key: Key('report-reason-${reason.name}'),
              value: reason,
              title: Text(
                reason.label,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: selected == reason
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
              contentPadding: EdgeInsets.zero,
              visualDensity: VisualDensity.standard,
            ),
        ],
      ),
    );
  }
}

class _ReasonRow extends StatelessWidget {
  const _ReasonRow({
    required this.reason,
    required this.selected,
    required this.showCheck,
    required this.onSelected,
  });

  final ReportReason reason;
  final bool selected;
  final bool showCheck;
  final ValueChanged<ReportReason> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      inMutuallyExclusiveGroup: true,
      checked: selected,
      label: reason.label,
      excludeSemantics: true,
      onTap: () => onSelected(reason),
      child: InkWell(
        key: Key('report-reason-${reason.name}'),
        onTap: () => onSelected(reason),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: StSpace.md),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    reason.label,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                if (showCheck && selected)
                  Icon(Icons.check, color: scheme.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown when the mail app does not open. The report is already on the clipboard.
Future<void> showNoMailDialog(BuildContext context) {
  if (_reportUsesCupertino()) {
    return showCupertinoDialog<void>(
      context: context,
      builder: (context) => const _IosNoMailDialog(),
    );
  }
  return showDialog<void>(
    context: context,
    builder: (context) => const _AndroidNoMailDialog(),
  );
}

class _IosNoMailDialog extends StatelessWidget {
  const _IosNoMailDialog();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CupertinoAlertDialog(
      key: const Key('report-no-mail-dialog'),
      title: const Text(reportNoMailTitle),
      content: Column(
        children: [
          const SizedBox(height: StSpace.xs),
          const Text(reportNoMailBody),
          const SizedBox(height: StSpace.sm),
          DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: const BorderRadius.all(StRadius.sm),
            ),
            child: const Padding(
              padding: EdgeInsets.all(StSpace.sm),
              child: SelectableText(kReportEmail),
            ),
          ),
        ],
      ),
      actions: [
        CupertinoDialogAction(
          key: const Key('report-copy-address'),
          onPressed: () => _copyAddress(context),
          child: const Text('Copy address'),
        ),
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

class _AndroidNoMailDialog extends StatelessWidget {
  const _AndroidNoMailDialog();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      key: const Key('report-no-mail-dialog'),
      icon: const Icon(Icons.mail_outline),
      title: const Text(reportNoMailTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(reportNoMailBody),
          const SizedBox(height: StSpace.sm),
          DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: const BorderRadius.all(StRadius.sm),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(StSpace.sm),
                    child: SelectableText(kReportEmail),
                  ),
                ),
                IconButton(
                  key: const Key('report-copy-address'),
                  tooltip: 'Copy address',
                  onPressed: () => _copyAddress(context),
                  icon: const Icon(Icons.copy),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

Future<void> _copyAddress(BuildContext context) async {
  await Clipboard.setData(const ClipboardData(text: kReportEmail));
  if (!context.mounted) return;
  unawaited(
    SemanticsService.sendAnnouncement(
      View.of(context),
      reportAddressCopied,
      Directionality.of(context),
    ),
  );
}
