import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'question_report.dart';

/// Clock for the "Reported at" line on a question report.
///
/// Tests override this. Defaults to [DateTime.now].
typedef ReportClock = DateTime Function();

final reportClockProvider = Provider<ReportClock>((ref) => DateTime.now);

/// Reason and note typed for one question, kept until the next deal.
final class ReportDraft {
  const ReportDraft({this.reason, this.note = ''});

  final ReportReason? reason;
  final String note;

  ReportDraft copyWith({
    ReportReason? reason,
    String? note,
    bool clearReason = false,
  }) {
    return ReportDraft(
      reason: clearReason ? null : (reason ?? this.reason),
      note: note ?? this.note,
    );
  }
}

/// In-memory reports for the current deal. A new game clears it.
final class ReportMemory {
  const ReportMemory({
    this.reportedIds = const <String>{},
    this.drafts = const <String, ReportDraft>{},
  });

  final Set<String> reportedIds;
  final Map<String, ReportDraft> drafts;

  bool isReported(String questionId) => reportedIds.contains(questionId);

  ReportDraft? draftFor(String questionId) => drafts[questionId];
}

/// Session-scoped reported ids and drafts. Not written to disk.
final reportedQuestionIdsProvider =
    NotifierProvider<ReportedQuestions, ReportMemory>(ReportedQuestions.new);

class ReportedQuestions extends Notifier<ReportMemory> {
  @override
  ReportMemory build() => const ReportMemory();

  void clear() {
    state = const ReportMemory();
  }

  void markReported(String questionId) {
    if (state.reportedIds.contains(questionId)) return;
    state = ReportMemory(
      reportedIds: {...state.reportedIds, questionId},
      drafts: state.drafts,
    );
  }

  void saveDraft(
    String questionId, {
    ReportReason? reason,
    String? note,
    bool clearReason = false,
  }) {
    final current = state.drafts[questionId] ?? const ReportDraft();
    final next = current.copyWith(
      reason: reason,
      note: note,
      clearReason: clearReason,
    );
    state = ReportMemory(
      reportedIds: state.reportedIds,
      drafts: {...state.drafts, questionId: next},
    );
  }
}
