import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'report_config.dart';

/// Why the player is reporting a question.
enum ReportReason {
  wrongAnswer('Wrong answer', 'wrong-answer'),
  wrongReference('Wrong reference', 'wrong-reference'),
  typoOrWording('Typo or wording', 'typo-or-wording'),
  other('Other', 'other');

  const ReportReason(this.label, this.slug);

  final String label;
  final String slug;

  /// Hint in the note field for this reason.
  String get noteHint {
    return switch (this) {
      ReportReason.wrongAnswer => 'What should the answer be?',
      ReportReason.wrongReference => 'Which verse should it be?',
      ReportReason.typoOrWording => 'What should it say?',
      ReportReason.other => 'Tell us what’s wrong',
    };
  }
}

/// Hint shown before a reason is chosen.
const reportNoteHintNone = 'What should it say?';

/// The mailto a player sends. Built when they tap Continue. Not stored.
final class QuestionReport {
  QuestionReport({
    required this.questionId,
    required this.prompt,
    required this.correctAnswer,
    required this.selectedAnswer,
    required this.reference,
    required this.reason,
    required String note,
    required this.appVersion,
    required this.platform,
    required this.bankVersion,
    required this.source,
    required DateTime createdAtUtc,
  }) : note = _trimNote(note),
       createdAtUtc = createdAtUtc.toUtc();

  final String questionId;
  final String prompt;
  final String correctAnswer;
  final String selectedAnswer;
  final String reference;
  final ReportReason reason;
  final String note;
  final String appVersion;
  final String platform;
  final String bankVersion;
  final String source;
  final DateTime createdAtUtc;

  /// `[Trivia report] <id> – <reason slug>`.
  String get subject => '[Trivia report] $questionId – ${reason.slug}';

  /// Full body. Never shortened. The clipboard uses this.
  String get body => _body(prompt, note);

  String get clipboardText =>
      'To: $kReportEmail\r\nSubject: $subject\r\n\r\n$body';

  /// Encoded mailto, kept at or under 1,800 characters.
  Uri get mailto {
    var question = prompt;
    final fullNote = note;
    var uri = _mailto(question, fullNote);
    if (uri.toString().length <= maxMailtoLength) return uri;
    if (question.length > 120) {
      question = '${question.substring(0, 120)}…';
      uri = _mailto(question, fullNote);
      if (uri.toString().length <= maxMailtoLength) return uri;
    }
    final noteChars = fullNote.characters;
    var low = 0;
    var high = noteChars.length;
    while (low <= high) {
      final mid = (low + high) ~/ 2;
      final candidate = noteChars.take(mid).string;
      final next = _mailto(question, candidate);
      if (next.toString().length <= maxMailtoLength) {
        uri = next;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    if (uri.toString().length <= maxMailtoLength) return uri;
    while (question.length > 1 && uri.toString().length > maxMailtoLength) {
      question = question.substring(0, question.length - 1);
      uri = _mailto(question, '');
    }
    return uri;
  }

  String _body(String question, String noteText) {
    final lines = <String>[
      'Add anything else here (optional).',
      '',
      '--- Scripture Trivia report ---',
      'Question ID: $questionId',
      'Question: $question',
      'Correct answer (app): $correctAnswer',
      "Player's answer: $selectedAnswer",
      'Reference: $reference',
      'Reason: ${reason.label}',
      'Note: ${noteText.isEmpty ? '—' : noteText}',
      'App: Scripture Trivia $appVersion · $platform',
      'Question bank: $bankVersion',
      'Source: $source',
      'Reported at: ${formatReportUtc(createdAtUtc)}',
      '--- end of report ---',
    ];
    return lines.join('\r\n');
  }

  Uri _mailto(String question, String noteText) {
    final encodedBody = Uri.encodeComponent(_body(question, noteText));
    final encodedSubject = Uri.encodeComponent(subject);
    return Uri.parse(
      'mailto:$kReportEmail?subject=$encodedSubject&body=$encodedBody',
    );
  }

  static String _trimNote(String value) {
    final trimmed = value.trim();
    final chars = trimmed.characters;
    if (chars.length <= maxReportNoteLength) return trimmed;
    return chars.take(maxReportNoteLength).string;
  }
}

/// Encoded mailto links stay at or under this length.
const maxMailtoLength = 1800;

/// The note field stops at this many characters.
const maxReportNoteLength = 280;

/// `2026-11-18T15:46:00Z`, with no fractional seconds.
String formatReportUtc(DateTime time) {
  final utc = time.toUtc();
  String two(int value) => value.toString().padLeft(2, '0');
  final year = utc.year.toString().padLeft(4, '0');
  return '$year-${two(utc.month)}-${two(utc.day)}'
      'T${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)}Z';
}

/// `iOS 18.1` style label from the current platform.
String reportPlatformLabel() {
  return formatReportPlatform(
    defaultTargetPlatform,
    Platform.operatingSystemVersion,
  );
}

/// Builds the platform line. iOS reports `Version 18.1 (Build …)`, so the
/// leading "Version " is dropped.
String formatReportPlatform(
  TargetPlatform platform,
  String operatingSystemVersion,
) {
  final name = switch (platform) {
    TargetPlatform.iOS => 'iOS',
    TargetPlatform.android => 'Android',
    TargetPlatform.macOS => 'macOS',
    TargetPlatform.windows => 'Windows',
    TargetPlatform.linux => 'Linux',
    TargetPlatform.fuchsia => 'Fuchsia',
  };
  final version = operatingSystemVersion.trim().replaceFirst(
    RegExp(r'^Version\s+', caseSensitive: false),
    '',
  );
  if (version.toLowerCase().startsWith(name.toLowerCase())) return version;
  return '$name $version';
}
