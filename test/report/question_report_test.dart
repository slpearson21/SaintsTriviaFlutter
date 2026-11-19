import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saints_trivia_flutter/report/question_report.dart';
import 'package:saints_trivia_flutter/report/report_config.dart';
import 'package:saints_trivia_flutter/report/reported_questions_provider.dart';

QuestionReport _report({
  String prompt = 'D&C 1:38 teaches that it is the same.',
  String note = 'The verse reads "mine own voice."',
  ReportReason reason = ReportReason.typoOrWording,
  String selected = 'Temporary',
}) {
  return QuestionReport(
    questionId: 'dc-0001',
    prompt: prompt,
    correctAnswer: 'The same',
    selectedAnswer: selected,
    reference: 'D&C 1:38',
    reason: reason,
    note: note,
    appVersion: 'v1.0.0',
    platform: 'iOS 18.1',
    bankVersion: 'v1',
    source: 'game',
    createdAtUtc: DateTime.utc(2026, 11, 18, 15, 46),
  );
}

void main() {
  test('subject uses the reason slug and the body uses the label', () {
    final report = _report();
    expect(report.subject, '[Trivia report] dc-0001 – typo-or-wording');
    expect(report.body, contains('Reason: Typo or wording'));
    expect(report.body, contains("Player's answer: Temporary"));
    expect(report.body, contains('Correct answer (app): The same'));
    expect(report.body, contains('Question ID: dc-0001'));
    expect(report.body, contains('Reference: D&C 1:38'));
    expect(report.body, contains('Source: game'));
    expect(report.body, contains('Question bank: v1'));
    expect(report.body, contains('App: Scripture Trivia v1.0.0 · iOS 18.1'));
    expect(report.body, contains('Reported at: 2026-11-18T15:46:00Z'));
    expect(report.body, contains('\r\n'));
    expect(report.body, isNot(contains('\n\n')));
  });

  test(
    'an empty note is an em dash and other reasons have their own slugs',
    () {
      final report = _report(note: '   ', reason: ReportReason.other);
      expect(report.note, isEmpty);
      expect(report.body, contains('Note: —'));
      expect(report.subject, endsWith(' – other'));
      expect(ReportReason.wrongAnswer.slug, 'wrong-answer');
      expect(ReportReason.wrongReference.slug, 'wrong-reference');
    },
  );

  test('mailto uses percent encoding and never a plus for spaces', () {
    final report = _report(prompt: 'A & B’s voice');
    final mailto = report.mailto.toString();
    expect(mailto.startsWith('mailto:$kReportEmail?'), isTrue);
    expect(mailto, isNot(contains('+')));
    expect(mailto, contains('%20'));
    expect(mailto, contains('%26'));
    expect(report.mailto.queryParameters.keys.toList(), ['subject', 'body']);
    final query = report.mailto.query;
    final subject = Uri.decodeComponent(
      query.split('&').first.replaceFirst('subject=', ''),
    );
    final body = Uri.decodeComponent(
      query.split('&').skip(1).join('&').replaceFirst('body=', ''),
    );
    expect(subject, report.subject);
    expect(body, contains('A & B’s voice'));
    expect(body, contains('Note: The verse reads "mine own voice."'));
  });

  test(
    'clipboard keeps the full text when the mailto question is shortened',
    () {
      final prompt = 'Prompt ${'word ' * 400}';
      final note = 'n' * 280;
      final report = _report(prompt: prompt, note: note);
      expect(
        report.mailto.toString().length,
        lessThanOrEqualTo(maxMailtoLength),
      );
      expect(report.clipboardText, contains(prompt));
      expect(report.clipboardText, contains('To: $kReportEmail'));
      expect(report.clipboardText, contains('Subject: ${report.subject}'));
      expect(report.clipboardText, contains(note));
    },
  );

  test('every bundled question plus a full note stays within 1,800 chars', () {
    const files = [
      'assets/questions/v1/old_testament.json',
      'assets/questions/v1/new_testament.json',
      'assets/questions/v1/book_of_mormon.json',
      'assets/questions/v1/doctrine_and_covenants.json',
      'assets/questions/v1/pearl_of_great_price.json',
    ];
    var count = 0;
    for (final path in files) {
      final questions = jsonDecode(File(path).readAsStringSync()) as List;
      for (final raw in questions) {
        final question = raw as Map;
        final options = (question['options'] as List).cast<String>();
        final report = QuestionReport(
          questionId: question['id'] as String,
          prompt: question['prompt'] as String,
          correctAnswer: options[question['answerIndex'] as int],
          selectedAnswer: options.join(' / '),
          reference: question['reference'] as String,
          reason: ReportReason.wrongAnswer,
          note: 'ñ' * 280,
          appVersion: 'v1.0.0',
          platform: 'Android 14',
          bankVersion: 'v1',
          source: 'review',
          createdAtUtc: DateTime.utc(2026, 11, 18),
        );
        expect(
          report.mailto.toString().length,
          lessThanOrEqualTo(maxMailtoLength),
          reason: question['id'],
        );
        expect(report.mailto.toString(), isNot(contains('+')));
        count += 1;
      }
    }
    expect(count, 591);
  });

  test('a note is trimmed on grapheme boundaries', () {
    final report = QuestionReport(
      questionId: 'bom-0001',
      prompt: 'Prompt',
      correctAnswer: 'Alpha',
      selectedAnswer: 'Beta',
      reference: '1 Nephi 1:1',
      reason: ReportReason.other,
      note: '😀' * 300,
      appVersion: 'v1.0.0',
      platform: 'iOS 18.1',
      bankVersion: 'v1',
      source: 'game',
      createdAtUtc: DateTime.utc(2026, 11, 18),
    );
    expect(report.note.characters.length, maxReportNoteLength);
    expect(report.note, '😀' * maxReportNoteLength);
    expect(report.note, isNot(contains('\uFFFD')));
    expect(report.clipboardText, contains('😀' * maxReportNoteLength));
  });

  test('the platform line is the name, with no kernel version', () {
    expect(platformLabel(TargetPlatform.android), 'Android');
    expect(platformLabel(TargetPlatform.iOS), 'iOS');
  });

  test('a realistic note is copied into the mailto body in full', () {
    const files = [
      'assets/questions/v1/old_testament.json',
      'assets/questions/v1/new_testament.json',
      'assets/questions/v1/book_of_mormon.json',
      'assets/questions/v1/doctrine_and_covenants.json',
      'assets/questions/v1/pearl_of_great_price.json',
    ];
    final note = 'n' * 280;
    var count = 0;
    for (final path in files) {
      final questions = jsonDecode(File(path).readAsStringSync()) as List;
      for (final raw in questions) {
        final question = raw as Map;
        final options = (question['options'] as List).cast<String>();
        final report = QuestionReport(
          questionId: question['id'] as String,
          prompt: question['prompt'] as String,
          correctAnswer: options[question['answerIndex'] as int],
          selectedAnswer: options.first,
          reference: question['reference'] as String,
          reason: ReportReason.wrongReference,
          note: note,
          appVersion: 'v1.0.0',
          platform: 'Android',
          bankVersion: 'v1',
          source: 'game',
          createdAtUtc: DateTime.utc(2026, 11, 18),
        );
        final body = Uri.decodeComponent(
          report.mailto.query
              .split('&')
              .skip(1)
              .join('&')
              .replaceFirst('body=', ''),
        );
        expect(body, report.body, reason: question['id']);
        expect(body, contains('Note: $note'));
        count += 1;
      }
    }
    expect(count, 591);
  });

  test('a long prompt is cut to 120 characters plus an ellipsis', () {
    final prompt = 'Q' * 2000;
    final report = _report(prompt: prompt, note: 'Keep this note');

    expect(report.mailto.toString().length, lessThanOrEqualTo(maxMailtoLength));
    final body = _mailtoBody(report);
    expect(body, contains('${'Q' * 120}…'));
    expect(body, isNot(contains('Q' * 121)));
    expect(body, contains('Note: Keep this note'));
    expect(report.clipboardText, contains(prompt));
  });

  test('the last shrink loop shortens the prompt with an empty note', () {
    final prompt = 'Q' * 300;
    final report = QuestionReport(
      questionId: 'q' * 550,
      prompt: prompt,
      correctAnswer: 'The same',
      selectedAnswer: 'picked',
      reference: 'D&C 1:38',
      reason: ReportReason.other,
      note: 'n' * 280,
      appVersion: 'v1.0.0',
      platform: 'p' * 360,
      bankVersion: 'v1',
      source: 's' * 180,
      createdAtUtc: DateTime.utc(2026, 11, 18, 15, 46),
    );

    expect(report.mailto.toString().length, lessThanOrEqualTo(maxMailtoLength));
    final body = _mailtoBody(report);
    final shown = body
        .split('\r\n')
        .firstWhere((line) => line.startsWith('Question: '))
        .replaceFirst('Question: ', '');
    expect(shown.length, lessThan(120));
    expect(prompt.startsWith(shown), isTrue);
    expect(body, contains('Note: —'));
    expect(report.clipboardText, contains(prompt));
    expect(report.clipboardText, contains('n' * 280));
  });

  test('a clipped non-ASCII id stays decodable', () {
    final id = 'é' * 200;
    final report = QuestionReport(
      questionId: id,
      prompt: 'é' * 400,
      correctAnswer: 'The same',
      selectedAnswer: 'picked',
      reference: 'D&C 1:38',
      reason: ReportReason.other,
      note: '',
      appVersion: 'v1.0.0',
      platform: 'Android',
      bankVersion: 'v1',
      source: 'game',
      createdAtUtc: DateTime.utc(2026, 11, 18, 15, 46),
    );

    final mailto = report.mailto.toString();
    expect(mailto.length, lessThanOrEqualTo(maxMailtoLength));
    expect(mailto, contains('&body='));
    expect(report.subject, contains(id));
    final body = _mailtoBody(report);
    final shownId = body
        .split('\r\n')
        .firstWhere((line) => line.startsWith('Question ID: '))
        .replaceFirst('Question ID: ', '');
    expect(shownId, isNotEmpty);
    expect(id.startsWith(shownId), isTrue);
    expect(body, isNot(contains('\uFFFD')));
  });

  test('a question id that fills the subject is left whole', () {
    final id = 'é' * 900;
    final report = QuestionReport(
      questionId: id,
      prompt: 'Prompt',
      correctAnswer: 'The same',
      selectedAnswer: 'picked',
      reference: 'D&C 1:38',
      reason: ReportReason.other,
      note: '',
      appVersion: 'v1.0.0',
      platform: 'Android',
      bankVersion: 'v1',
      source: 'game',
      createdAtUtc: DateTime.utc(2026, 11, 18, 15, 46),
    );

    expect(report.mailto.toString().length, greaterThan(maxMailtoLength));
    expect(report.subject, contains(id));
    final subject = Uri.decodeComponent(
      report.mailto.query.split('&').first.replaceFirst('subject=', ''),
    );
    expect(subject, report.subject);
  });

  test('formatReportUtc zero-pads a UTC time and converts a local one', () {
    expect(
      formatReportUtc(DateTime.utc(2026, 1, 2, 3, 4, 5)),
      '2026-01-02T03:04:05Z',
    );
    final local = DateTime(2026, 1, 2, 3, 4, 5);
    expect(local.isUtc, isFalse);
    final utc = local.toUtc();
    String two(int value) => value.toString().padLeft(2, '0');
    expect(
      formatReportUtc(local),
      '${utc.year.toString().padLeft(4, '0')}-'
      '${two(utc.month)}-${two(utc.day)}'
      'T${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)}Z',
    );
  });

  test('reportPlatformLabel follows the debug platform override', () {
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    const names = {
      TargetPlatform.android: 'Android',
      TargetPlatform.iOS: 'iOS',
      TargetPlatform.macOS: 'macOS',
      TargetPlatform.windows: 'Windows',
      TargetPlatform.linux: 'Linux',
      TargetPlatform.fuchsia: 'Fuchsia',
    };
    for (final entry in names.entries) {
      debugDefaultTargetPlatformOverride = entry.key;
      expect(platformLabel(entry.key), entry.value);
      expect(reportPlatformLabel(), entry.value);
    }
  });

  test('each reason has its note hint', () {
    expect(reportNoteHintNone, 'What should it say?');
    expect(ReportReason.wrongAnswer.noteHint, 'What should the answer be?');
    expect(ReportReason.wrongReference.noteHint, 'Which verse should it be?');
    expect(ReportReason.typoOrWording.noteHint, 'What should it say?');
    expect(ReportReason.other.noteHint, 'Tell us what\u2019s wrong');
  });

  test('copyWith can clear the reason and replace the note', () {
    const draft = ReportDraft(reason: ReportReason.other, note: 'keep');

    final cleared = draft.copyWith(clearReason: true);
    expect(cleared.reason, isNull);
    expect(cleared.note, 'keep');

    final noted = draft.copyWith(note: 'next');
    expect(noted.reason, ReportReason.other);
    expect(noted.note, 'next');

    final both = draft.copyWith(
      reason: ReportReason.wrongAnswer,
      clearReason: true,
      note: 'gone',
    );
    expect(both.reason, isNull);
    expect(both.note, 'gone');
  });

  test('markReported is a no-op the second time', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final reports = container.read(reportedQuestionIdsProvider.notifier);

    reports.markReported('ot-0001');
    final first = container.read(reportedQuestionIdsProvider);
    reports.markReported('ot-0001');
    final second = container.read(reportedQuestionIdsProvider);

    expect(identical(first, second), isTrue);
    expect(second.reportedIds, {'ot-0001'});

    reports.markReported('ot-0002');
    expect(container.read(reportedQuestionIdsProvider).reportedIds, {
      'ot-0001',
      'ot-0002',
    });
  });
}

String _mailtoBody(QuestionReport report) {
  return Uri.decodeComponent(
    report.mailto.query.split('&').skip(1).join('&').replaceFirst('body=', ''),
  );
}
