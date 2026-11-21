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

  /// `[LDS Scripture Trivia report] <id> – <reason slug>`.
  String get subject =>
      '[LDS Scripture Trivia report] $questionId – ${reason.slug}';

  /// Full body. Never shortened. The clipboard uses this.
  String get body => _body(prompt, note);

  String get clipboardText =>
      'To: $kReportEmail\r\nSubject: $subject\r\n\r\n$body';

  /// Encoded mailto. At or under 1,800 characters when the subject fits.
  ///
  /// App version, platform, bank version, and source are capped first. The
  /// question and the note shrink next, then the correct answer, the
  /// reference, and the player's answer. Those metadata fields shrink
  /// further if the link is still too long. The subject always keeps the
  /// question id whole. The body's "Question ID:" line can be shortened
  /// by the final body cut, which never splits a character. A subject
  /// that leaves no room for `&body=` is returned on its own.
  /// [body] and [clipboardText] stay full.
  Uri get mailto {
    var version = _bounded(appVersion, maxReportAppVersionLength);
    var platformName = _bounded(platform, maxReportPlatformLength);
    var bank = _bounded(bankVersion, maxReportBankVersionLength);
    var reportSource = _bounded(source, maxReportSourceLength);
    var question = prompt;
    final fullNote = note;
    var uri = _mailto(
      question,
      fullNote,
      version: version,
      platformName: platformName,
      bank: bank,
      reportSource: reportSource,
    );
    if (uri.toString().length <= maxMailtoLength) return uri;
    if (question.characters.length > 120) {
      question = '${question.characters.take(120)}…';
      uri = _mailto(
        question,
        fullNote,
        version: version,
        platformName: platformName,
        bank: bank,
        reportSource: reportSource,
      );
      if (uri.toString().length <= maxMailtoLength) return uri;
    }
    final noteChars = fullNote.characters;
    var low = 0;
    var high = noteChars.length;
    while (low <= high) {
      final mid = (low + high) ~/ 2;
      final candidate = noteChars.take(mid).string;
      final next = _mailto(
        question,
        candidate,
        version: version,
        platformName: platformName,
        bank: bank,
        reportSource: reportSource,
      );
      if (next.toString().length <= maxMailtoLength) {
        uri = next;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    if (uri.toString().length <= maxMailtoLength) return uri;
    while (question.characters.length > 1 &&
        uri.toString().length > maxMailtoLength) {
      question = question.characters.skipLast(1).string;
      uri = _mailto(
        question,
        '',
        version: version,
        platformName: platformName,
        bank: bank,
        reportSource: reportSource,
      );
    }
    if (uri.toString().length <= maxMailtoLength) return uri;
    final answer = _trimTail(
      correctAnswer,
      (value) => _mailto(
        question,
        '',
        answer: value,
        version: version,
        platformName: platformName,
        bank: bank,
        reportSource: reportSource,
      ),
    );
    uri = _mailto(
      question,
      '',
      answer: answer,
      version: version,
      platformName: platformName,
      bank: bank,
      reportSource: reportSource,
    );
    if (uri.toString().length <= maxMailtoLength) return uri;
    final scripture = _trimTail(
      reference,
      (value) => _mailto(
        question,
        '',
        answer: answer,
        scripture: value,
        version: version,
        platformName: platformName,
        bank: bank,
        reportSource: reportSource,
      ),
    );
    uri = _mailto(
      question,
      '',
      answer: answer,
      scripture: scripture,
      version: version,
      platformName: platformName,
      bank: bank,
      reportSource: reportSource,
    );
    if (uri.toString().length <= maxMailtoLength) return uri;
    final selected = _trimTail(
      selectedAnswer,
      (value) => _mailto(
        question,
        '',
        answer: answer,
        scripture: scripture,
        selected: value,
        version: version,
        platformName: platformName,
        bank: bank,
        reportSource: reportSource,
      ),
    );
    uri = _mailto(
      question,
      '',
      answer: answer,
      scripture: scripture,
      selected: selected,
      version: version,
      platformName: platformName,
      bank: bank,
      reportSource: reportSource,
    );
    if (uri.toString().length <= maxMailtoLength) return uri;
    version = _trimTail(
      version,
      (value) => _mailto(
        question,
        '',
        answer: answer,
        scripture: scripture,
        selected: selected,
        version: value,
        platformName: platformName,
        bank: bank,
        reportSource: reportSource,
      ),
    );
    uri = _mailto(
      question,
      '',
      answer: answer,
      scripture: scripture,
      selected: selected,
      version: version,
      platformName: platformName,
      bank: bank,
      reportSource: reportSource,
    );
    if (uri.toString().length <= maxMailtoLength) return uri;
    platformName = _trimTail(
      platformName,
      (value) => _mailto(
        question,
        '',
        answer: answer,
        scripture: scripture,
        selected: selected,
        version: version,
        platformName: value,
        bank: bank,
        reportSource: reportSource,
      ),
    );
    uri = _mailto(
      question,
      '',
      answer: answer,
      scripture: scripture,
      selected: selected,
      version: version,
      platformName: platformName,
      bank: bank,
      reportSource: reportSource,
    );
    if (uri.toString().length <= maxMailtoLength) return uri;
    bank = _trimTail(
      bank,
      (value) => _mailto(
        question,
        '',
        answer: answer,
        scripture: scripture,
        selected: selected,
        version: version,
        platformName: platformName,
        bank: value,
        reportSource: reportSource,
      ),
    );
    uri = _mailto(
      question,
      '',
      answer: answer,
      scripture: scripture,
      selected: selected,
      version: version,
      platformName: platformName,
      bank: bank,
      reportSource: reportSource,
    );
    if (uri.toString().length <= maxMailtoLength) return uri;
    reportSource = _trimTail(
      reportSource,
      (value) => _mailto(
        question,
        '',
        answer: answer,
        scripture: scripture,
        selected: selected,
        version: version,
        platformName: platformName,
        bank: bank,
        reportSource: value,
      ),
    );
    uri = _mailto(
      question,
      '',
      answer: answer,
      scripture: scripture,
      selected: selected,
      version: version,
      platformName: platformName,
      bank: bank,
      reportSource: reportSource,
    );
    if (uri.toString().length <= maxMailtoLength) return uri;
    return _clipMailto(uri.toString());
  }

  /// Keeps [value] when it is already short enough for the mailto.
  String _bounded(String value, int max) {
    if (value.characters.length <= max) return value;
    return value.characters.take(max).string;
  }

  /// Longest grapheme prefix of [value] whose [build] fits.
  String _trimTail(String value, Uri Function(String candidate) build) {
    if (build(value).toString().length <= maxMailtoLength) return value;
    final chars = value.characters;
    var low = 0;
    var high = chars.length;
    var best = '';
    while (low <= high) {
      final mid = (low + high) ~/ 2;
      final candidate = chars.take(mid).string;
      if (build(candidate).toString().length <= maxMailtoLength) {
        best = candidate;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return best;
  }

  String _body(
    String question,
    String noteText, {
    String? answer,
    String? selected,
    String? scripture,
    String? version,
    String? platformName,
    String? bank,
    String? reportSource,
  }) {
    final versionText = version ?? appVersion;
    final platformText = platformName ?? platform;
    final lines = <String>[
      'Add anything else here (optional).',
      '',
      '--- LDS Scripture Trivia report ---',
      'Question ID: $questionId',
      'Question: $question',
      'Correct answer (app): ${answer ?? correctAnswer}',
      "Player's answer: ${selected ?? selectedAnswer}",
      'Reference: ${scripture ?? reference}',
      'Reason: ${reason.label}',
      'Note: ${noteText.isEmpty ? '—' : noteText}',
      'App: LDS Scripture Trivia $versionText · $platformText',
      'Question bank: ${bank ?? bankVersion}',
      'Source: ${reportSource ?? source}',
      'Reported at: ${formatReportUtc(createdAtUtc)}',
      '--- end of report ---',
    ];
    return lines.join('\r\n');
  }

  Uri _mailto(
    String question,
    String noteText, {
    String? answer,
    String? selected,
    String? scripture,
    String? version,
    String? platformName,
    String? bank,
    String? reportSource,
  }) {
    final encodedBody = Uri.encodeComponent(
      _body(
        question,
        noteText,
        answer: answer,
        selected: selected,
        scripture: scripture,
        version: version,
        platformName: platformName,
        bank: bank,
        reportSource: reportSource,
      ),
    );
    final encodedSubject = Uri.encodeComponent(subject);
    return Uri.parse(
      'mailto:$kReportEmail?subject=$encodedSubject&body=$encodedBody',
    );
  }

  /// Cuts the body value without splitting a character or the subject.
  ///
  /// The subject keeps the question id whole. The body's question id can
  /// be shortened. When the subject plus `&body=` does not fit, the link
  /// stops at the subject.
  Uri _clipMailto(String text) {
    const marker = '&body=';
    final markerAt = text.indexOf(marker);
    if (markerAt < 0) return Uri.parse(text);
    final prefixLength = markerAt + marker.length;
    if (prefixLength > maxMailtoLength) {
      return Uri.parse(text.substring(0, markerAt));
    }
    var end = text.length;
    while (end >= prefixLength) {
      if (end > maxMailtoLength) end = maxMailtoLength;
      final safe = _characterBoundary(text, end);
      final cut = safe < prefixLength ? prefixLength : safe;
      final parsed = Uri.parse(text.substring(0, cut));
      final rendered = parsed.toString();
      if (rendered.length <= maxMailtoLength && rendered.contains(marker)) {
        return parsed;
      }
      if (cut <= prefixLength) break;
      end = cut - 1;
    }
    return Uri.parse(text.substring(0, prefixLength));
  }

  /// [end] is exclusive. Backs up out of a partial `%HH` or a split character.
  int _characterBoundary(String text, int end) {
    final limit = end > text.length ? text.length : end;
    if (limit <= 0) return 0;
    return _utf8Boundary(text, _escapeBoundary(text, limit));
  }

  int _escapeBoundary(String text, int cut) {
    if (cut <= 0) return 0;
    if (text[cut - 1] == '%') return cut - 1;
    if (cut >= 2 && text[cut - 2] == '%') return cut - 2;
    return cut;
  }

  /// The byte encoded by the `%HH` ending at [cut], if that is where it ends.
  int? _percentByte(String text, int cut) {
    if (cut < 3 || text[cut - 3] != '%') return null;
    final byte = int.tryParse(text.substring(cut - 2, cut), radix: 16);
    if (byte == null || byte > 0xFF) return null;
    return byte;
  }

  int _utf8Continuations(int lead) {
    if (lead >= 0xC2 && lead <= 0xDF) return 1;
    if (lead >= 0xE0 && lead <= 0xEF) return 2;
    if (lead >= 0xF0 && lead <= 0xF4) return 3;
    return 0;
  }

  /// Backs up when [cut] ends on a UTF-8 continuation (`%80`–`%BF`).
  int _utf8Boundary(String text, int cut) {
    final last = _percentByte(text, cut);
    if (last == null || last < 0x80) return cut;
    if (last <= 0xBF) {
      var pos = cut;
      var seen = 0;
      while (pos >= 3 && seen < 3) {
        final byte = _percentByte(text, pos);
        if (byte == null || byte < 0x80 || byte > 0xBF) break;
        seen++;
        pos -= 3;
      }
      final lead = _percentByte(text, pos);
      final expected = lead == null ? 0 : _utf8Continuations(lead);
      if (expected == seen && expected > 0) return cut;
      if (expected > 0) return pos - 3;
      return pos;
    }
    return cut - 3;
  }

  static String _trimNote(String value) {
    final trimmed = value.trim();
    final chars = trimmed.characters;
    if (chars.length <= maxReportNoteLength) return trimmed;
    return chars.take(maxReportNoteLength).string;
  }
}

/// Target length of an encoded mailto. A subject that leaves no room
/// for `&body=` is returned on its own, without the body.
const maxMailtoLength = 1800;

/// The note field stops at this many characters.
const maxReportNoteLength = 280;

/// App version graphemes kept in the mailto.
const maxReportAppVersionLength = 32;

/// Platform graphemes kept in the mailto.
const maxReportPlatformLength = 32;

/// Question-bank version graphemes kept in the mailto.
const maxReportBankVersionLength = 16;

/// Report source graphemes kept in the mailto.
const maxReportSourceLength = 32;

/// `2026-11-18T15:46:00Z`, with no fractional seconds.
String formatReportUtc(DateTime time) {
  final utc = time.toUtc();
  String two(int value) => value.toString().padLeft(2, '0');
  final year = utc.year.toString().padLeft(4, '0');
  return '$year-${two(utc.month)}-${two(utc.day)}'
      'T${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)}Z';
}

/// Platform name only. Android's `operatingSystemVersion` is a kernel
/// string, so the report does not include it.
String reportPlatformLabel() => platformLabel(defaultTargetPlatform);

/// `iOS`, `Android`, and the other Flutter platform names.
String platformLabel(TargetPlatform platform) {
  return switch (platform) {
    TargetPlatform.iOS => 'iOS',
    TargetPlatform.android => 'Android',
    TargetPlatform.macOS => 'macOS',
    TargetPlatform.windows => 'Windows',
    TargetPlatform.linux => 'Linux',
    TargetPlatform.fuchsia => 'Fuchsia',
  };
}
