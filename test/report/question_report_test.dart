import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saints_trivia_flutter/report/question_report.dart';
import 'package:saints_trivia_flutter/report/report_config.dart';

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
    expect(
      report.subject,
      '[Trivia report] dc-0001 – typo-or-wording',
    );
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

  test('an empty note is an em dash and other reasons have their own slugs', () {
    final report = _report(note: '   ', reason: ReportReason.other);
    expect(report.note, isEmpty);
    expect(report.body, contains('Note: —'));
    expect(report.subject, endsWith(' – other'));
    expect(
      ReportReason.wrongAnswer.slug,
      'wrong-answer',
    );
    expect(ReportReason.wrongReference.slug, 'wrong-reference');
  });

  test('mailto uses percent encoding and never a plus for spaces', () {
    final report = _report(prompt: 'A & B’s voice');
    final mailto = report.mailto.toString();
    expect(mailto.startsWith('mailto:$kReportEmail?'), isTrue);
    expect(mailto, isNot(contains('+')));
    expect(mailto, contains('%20'));
    expect(mailto, contains('%26'));
    expect(mailto, isNot(contains('lang=')));
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

  test('clipboard keeps the full text when the mailto question is shortened', () {
    final prompt = 'Prompt ${'word ' * 400}';
    final note = 'n' * 280;
    final report = _report(prompt: prompt, note: note);
    expect(report.mailto.toString().length, lessThanOrEqualTo(maxMailtoLength));
    expect(report.clipboardText, contains(prompt));
    expect(report.clipboardText, contains('To: $kReportEmail'));
    expect(report.clipboardText, contains('Subject: ${report.subject}'));
    expect(report.clipboardText, contains(note));
  });

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

  test('a release build rejects the example.com placeholder', () {
    expect(kReleaseMode && kReportEmail.contains('example.com'), isFalse);
  });
}
