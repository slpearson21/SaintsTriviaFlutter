import 'dart:convert';
import 'dart:io';
import 'dart:math';

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
          reason: question['id'] as String,
        );
        expect(report.mailto.toString(), isNot(contains('+')));
        count += 1;
      }
    }
    expect(count, _bundledQuestionCount());
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
        expect(body, report.body, reason: question['id'] as String);
        expect(body, contains('Note: $note'));
        count += 1;
      }
    }
    expect(count, _bundledQuestionCount());
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

  test('a subject over the cap drops the body', () {
    final id = 'é' * 900;
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

    final subjectOnly = Uri.parse(
      'mailto:$kReportEmail?subject=${Uri.encodeComponent(report.subject)}',
    ).toString();
    final mailto = report.mailto.toString();
    expect(mailto, subjectOnly);
    expect(mailto, isNot(contains('&body=')));
    expect(mailto.length, greaterThan(maxMailtoLength));
    expect(Uri.decodeComponent(mailto.split('subject=').last), report.subject);
  });

  test('a subject that ends on the cap keeps an empty body', () {
    final id = 'x' * 1715;
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

    final mailto = report.mailto.toString();
    final subject = Uri.decodeComponent(
      mailto.split('?').last.split('&').first.replaceFirst('subject=', ''),
    );
    expect(mailto.length, maxMailtoLength);
    expect(mailto, endsWith('&body='));
    expect(subject, report.subject);
    expect(subject, contains(id));
  });

  test('a subject with no room for the body marker drops it', () {
    final ids = ['x' * 1716, 'é' * 286, '😀' * 143, '—' * 191];
    for (final id in ids) {
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

      final mailto = report.mailto.toString();
      expect(mailto.length, lessThanOrEqualTo(maxMailtoLength), reason: id);
      expect(mailto, isNot(contains('&body=')), reason: id);
      expect(
        Uri.decodeComponent(mailto.split('subject=').last),
        report.subject,
        reason: id,
      );
    }
  });

  test('formatReportUtc zero-pads a UTC time and converts a local one', () {
    expect(
      formatReportUtc(DateTime.utc(2026, 1, 2, 3, 4, 5)),
      '2026-01-02T03:04:05Z',
    );
    final local = DateTime.utc(2026, 1, 2, 3, 4, 5).toLocal();
    expect(local.isUtc, isFalse);
    expect(formatReportUtc(local), '2026-01-02T03:04:05Z');
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

  test('step 1 caps metadata graphemes before the link is built', () {
    final report = _sized(
      version: 'é' * 40,
      platform: '字' * 40,
      bank: 'b' * 20,
      source: '😀' * 40,
      prompt: 'Prompt stays',
      note: 'Note stays',
      answer: 'Answer stays',
      selected: 'Selected stays',
      reference: 'Ref stays',
    );
    final decoded = _mailtoBody(report);
    final app = _mailtoField(decoded, 'App: ');
    final version = app
        .replaceFirst('App: Scripture Trivia ', '')
        .split(' · ')
        .first;
    final platform = app.split(' · ').last;

    expect(report.mailto.toString().length, lessThanOrEqualTo(maxMailtoLength));
    expect(version.characters.length, maxReportAppVersionLength);
    expect(version, 'é' * maxReportAppVersionLength);
    expect(platform.characters.length, maxReportPlatformLength);
    expect(platform, '字' * maxReportPlatformLength);
    expect(
      _mailtoField(decoded, 'Question bank: '),
      'Question bank: ${'b' * maxReportBankVersionLength}',
    );
    expect(
      _mailtoField(decoded, 'Source: '),
      'Source: ${'😀' * maxReportSourceLength}',
    );
    expect(_mailtoField(decoded, 'Question: '), 'Question: Prompt stays');
    expect(_mailtoField(decoded, 'Note: '), 'Note: Note stays');
    expect(
      _mailtoField(decoded, 'Correct answer (app): '),
      'Correct answer (app): Answer stays',
    );
    expect(
      _mailtoField(decoded, "Player's answer: "),
      "Player's answer: Selected stays",
    );
    expect(_mailtoField(decoded, 'Reference: '), 'Reference: Ref stays');
    expect(decoded, contains('--- end of report ---'));
    expect(report.body, contains('é' * 40));
    expect(report.body, contains('字' * 40));
    expect(report.body, contains('b' * 20));
    expect(report.body, contains('😀' * 40));
    expect(report.clipboardText, contains(report.body));
  });

  test('step 2 returns a link at or under 1,800 unchanged', () {
    final report = _sized(prompt: 'Q' * 121, note: 'note');
    final decoded = _mailtoBody(report);

    expect(report.mailto.toString().length, lessThanOrEqualTo(maxMailtoLength));
    expect(decoded, report.body);
    expect(_mailtoField(decoded, 'Question: '), 'Question: ${'Q' * 121}');
    expect(decoded, isNot(contains('…')));
    expect(_mailtoField(decoded, 'Note: '), 'Note: note');
    expect(report.clipboardText, contains(report.body));
  });

  test('step 3 shortens a long prompt to 120 graphemes plus an ellipsis', () {
    final prompt = 'Q' * 2000;
    final report = _sized(prompt: prompt, note: 'Keep this note');
    final decoded = _mailtoBody(report);

    expect(report.mailto.toString().length, lessThanOrEqualTo(maxMailtoLength));
    expect(_mailtoField(decoded, 'Question: '), 'Question: ${'Q' * 120}…');
    expect(_mailtoField(decoded, 'Note: '), 'Note: Keep this note');
    expect(
      _mailtoField(decoded, 'Correct answer (app): '),
      'Correct answer (app): A',
    );
    expect(_mailtoField(decoded, "Player's answer: "), "Player's answer: S");
    expect(_mailtoField(decoded, 'Reference: '), 'Reference: R');
    expect(decoded, contains('--- end of report ---'));
    expect(report.body, contains(prompt));
    expect(report.clipboardText, contains(prompt));
    expect(report.clipboardText, contains('Keep this note'));
  });

  test('step 4 keeps the longest note prefix that fits', () {
    final note = 'n' * 280;
    final report = _sized(
      prompt: 'P' * 80,
      note: note,
      answer: 'A' * 900,
      selected: 'Selected stays',
      reference: 'Ref stays',
    );
    final decoded = _mailtoBody(report);
    final shown = _mailtoField(decoded, 'Note: ').replaceFirst('Note: ', '');

    expect(report.mailto.toString().length, lessThanOrEqualTo(maxMailtoLength));
    expect(shown, 'n' * 262);
    expect(note.startsWith(shown), isTrue);
    expect(_mailtoField(decoded, 'Question: '), 'Question: ${'P' * 80}');
    expect(
      _mailtoField(decoded, 'Correct answer (app): '),
      'Correct answer (app): ${'A' * 900}',
    );
    expect(
      _mailtoField(decoded, "Player's answer: "),
      "Player's answer: Selected stays",
    );
    expect(_mailtoField(decoded, 'Reference: '), 'Reference: Ref stays');
    expect(decoded, contains('--- end of report ---'));
    expect(report.body, contains(note));
    expect(report.body, contains('A' * 900));
    expect(report.clipboardText, contains(report.body));
  });

  test('step 5 trims the prompt tail and clears the note', () {
    final prompt = 'P' * 80;
    final report = _sized(
      prompt: prompt,
      note: 'n' * 280,
      answer: 'A' * 1175,
      selected: 'Selected stays',
      reference: 'Ref stays',
    );
    final decoded = _mailtoBody(report);
    final shown = _mailtoField(
      decoded,
      'Question: ',
    ).replaceFirst('Question: ', '');

    expect(report.mailto.toString().length, lessThanOrEqualTo(maxMailtoLength));
    expect(shown, 'P' * 58);
    expect(prompt.startsWith(shown), isTrue);
    expect(shown.characters.length, greaterThan(1));
    expect(_mailtoField(decoded, 'Note: '), 'Note: —');
    expect(
      _mailtoField(decoded, 'Correct answer (app): '),
      'Correct answer (app): ${'A' * 1175}',
    );
    expect(
      _mailtoField(decoded, "Player's answer: "),
      "Player's answer: Selected stays",
    );
    expect(_mailtoField(decoded, 'Reference: '), 'Reference: Ref stays');
    expect(decoded, contains('--- end of report ---'));
    expect(report.body, contains(prompt));
    expect(report.body, contains('n' * 280));
    expect(report.clipboardText, contains(report.body));
  });

  test('step 6 trims the correct answer and leaves the reference', () {
    final answer = 'A' * 1250;
    final report = _sized(
      prompt: 'P',
      answer: answer,
      selected: 'Selected stays',
      reference: 'Ref stays',
    );
    final decoded = _mailtoBody(report);
    final shown = _mailtoField(
      decoded,
      'Correct answer (app): ',
    ).replaceFirst('Correct answer (app): ', '');

    expect(report.mailto.toString().length, lessThanOrEqualTo(maxMailtoLength));
    expect(shown, 'A' * 1232);
    expect(answer.startsWith(shown), isTrue);
    expect(_mailtoField(decoded, 'Question: '), 'Question: P');
    expect(_mailtoField(decoded, 'Note: '), 'Note: —');
    expect(_mailtoField(decoded, 'Reference: '), 'Reference: Ref stays');
    expect(
      _mailtoField(decoded, "Player's answer: "),
      "Player's answer: Selected stays",
    );
    expect(decoded, contains('--- end of report ---'));
    expect(report.body, contains(answer));
    expect(report.clipboardText, contains(report.body));
  });

  test('step 7 trims the reference and leaves the player answer', () {
    final reference = 'R' * 1250;
    final report = _sized(
      prompt: 'P',
      answer: '',
      selected: 'Selected stays',
      reference: reference,
    );
    final decoded = _mailtoBody(report);
    final shown = _mailtoField(
      decoded,
      'Reference: ',
    ).replaceFirst('Reference: ', '');

    expect(report.mailto.toString().length, lessThanOrEqualTo(maxMailtoLength));
    expect(shown.length, lessThan(reference.length));
    expect(shown.isNotEmpty, isTrue);
    expect(reference.startsWith(shown), isTrue);
    expect(_mailtoField(decoded, 'Question: '), 'Question: P');
    expect(_mailtoField(decoded, 'Note: '), 'Note: —');
    expect(
      _mailtoField(decoded, 'Correct answer (app): '),
      'Correct answer (app): ',
    );
    expect(
      _mailtoField(decoded, "Player's answer: "),
      "Player's answer: Selected stays",
    );
    expect(_mailtoField(decoded, 'App: '), 'App: Scripture Trivia v · p');
    expect(decoded, contains('--- end of report ---'));
    expect(report.body, contains(reference));
    expect(report.clipboardText, contains(report.body));
  });

  test('step 8 trims the player answer and leaves the metadata', () {
    final selected = 'S' * 1175;
    final report = _sized(
      prompt: 'P',
      answer: '',
      selected: selected,
      reference: '',
      version: 'v' * 32,
      platform: 'p' * 32,
      bank: 'b' * 16,
      source: 's' * 32,
    );
    final decoded = _mailtoBody(report);
    final shown = _mailtoField(
      decoded,
      "Player's answer: ",
    ).replaceFirst("Player's answer: ", '');

    expect(report.mailto.toString().length, lessThanOrEqualTo(maxMailtoLength));
    expect(shown.length, lessThan(selected.length));
    expect(shown.isNotEmpty, isTrue);
    expect(selected.startsWith(shown), isTrue);
    expect(_mailtoField(decoded, 'Reference: '), 'Reference: ');
    expect(
      _mailtoField(decoded, 'Correct answer (app): '),
      'Correct answer (app): ',
    );
    expect(
      _mailtoField(decoded, 'App: '),
      'App: Scripture Trivia ${'v' * 32} · ${'p' * 32}',
    );
    expect(
      _mailtoField(decoded, 'Question bank: '),
      'Question bank: ${'b' * 16}',
    );
    expect(_mailtoField(decoded, 'Source: '), 'Source: ${'s' * 32}');
    expect(decoded, contains('--- end of report ---'));
    expect(report.body, contains(selected));
    expect(report.clipboardText, contains(report.body));
  });

  test('step 9 trims app version and leaves the later metadata capped', () {
    final id = 'i' * 580;
    final report = _sized(
      id: id,
      prompt: 'P',
      answer: '',
      selected: '',
      reference: '',
      version: 'v' * 40,
      platform: 'p' * 40,
      bank: 'b' * 20,
      source: 's' * 40,
    );
    final mailto = report.mailto.toString();
    final decoded = _mailtoBody(report);
    final app = _mailtoField(decoded, 'App: ');
    final version = app
        .replaceFirst('App: Scripture Trivia ', '')
        .split(' · ')
        .first;
    final platform = app.split(' · ').last;

    expect(mailto.length, lessThanOrEqualTo(maxMailtoLength));
    expect(mailto, contains('&body='));
    expect(version, 'v' * 25);
    expect(platform, 'p' * maxReportPlatformLength);
    expect(
      _mailtoField(decoded, 'Question bank: '),
      'Question bank: ${'b' * maxReportBankVersionLength}',
    );
    expect(
      _mailtoField(decoded, 'Source: '),
      'Source: ${'s' * maxReportSourceLength}',
    );
    expect(_mailtoField(decoded, 'Question: '), 'Question: P');
    expect(decoded, contains('Question ID: $id'));
    expect(decoded, contains('--- end of report ---'));
    expect(report.body, contains('v' * 40));
    expect(report.body, contains('p' * 40));
    expect(report.clipboardText, contains(report.body));
  });

  test('step 9 trims platform after the app version is gone', () {
    final id = 'i' * 600;
    final report = _sized(
      id: id,
      prompt: 'P',
      answer: '',
      selected: '',
      reference: '',
      version: 'v' * 40,
      platform: 'p' * 40,
      bank: 'b' * 20,
      source: 's' * 40,
    );
    final mailto = report.mailto.toString();
    final decoded = _mailtoBody(report);
    final app = _mailtoField(decoded, 'App: ');
    final version = app
        .replaceFirst('App: Scripture Trivia ', '')
        .split(' · ')
        .first;
    final platform = app.split(' · ').last;

    expect(mailto.length, lessThanOrEqualTo(maxMailtoLength));
    expect(mailto, contains('&body='));
    expect(version, isEmpty);
    expect(platform, 'p' * 17);
    expect(
      _mailtoField(decoded, 'Question bank: '),
      'Question bank: ${'b' * maxReportBankVersionLength}',
    );
    expect(
      _mailtoField(decoded, 'Source: '),
      'Source: ${'s' * maxReportSourceLength}',
    );
    expect(_mailtoField(decoded, 'Question: '), 'Question: P');
    expect(decoded, contains('Question ID: $id'));
    expect(decoded, contains('--- end of report ---'));
    expect(report.body, contains('v' * 40));
    expect(report.body, contains('p' * 40));
    expect(report.clipboardText, contains(report.body));
  });

  test('step 9 trims the bank version after the platform is gone', () {
    final id = 'i' * 616;
    final report = _sized(
      id: id,
      prompt: 'P',
      answer: '',
      selected: '',
      reference: '',
      version: 'v' * 40,
      platform: 'p' * 40,
      bank: 'b' * 20,
      source: 's' * 40,
    );
    final mailto = report.mailto.toString();
    final decoded = _mailtoBody(report);
    final app = _mailtoField(decoded, 'App: ');
    final version = app
        .replaceFirst('App: Scripture Trivia ', '')
        .split(' · ')
        .first;
    final platform = app.split(' · ').last;

    expect(mailto.length, lessThanOrEqualTo(maxMailtoLength));
    expect(mailto, contains('&body='));
    expect(version, isEmpty);
    expect(platform, isEmpty);
    expect(_mailtoField(decoded, 'Question bank: '), 'Question bank: b');
    expect(
      _mailtoField(decoded, 'Source: '),
      'Source: ${'s' * maxReportSourceLength}',
    );
    expect(_mailtoField(decoded, 'Question: '), 'Question: P');
    expect(decoded, contains('Question ID: $id'));
    expect(decoded, contains('--- end of report ---'));
    expect(report.body, contains('b' * 20));
    expect(report.body, contains('s' * 40));
    expect(report.clipboardText, contains(report.body));
  });

  test('step 9 trims the source after the bank version is gone', () {
    final id = 'i' * 624;
    final report = _sized(
      id: id,
      prompt: 'P',
      answer: '',
      selected: '',
      reference: '',
      version: 'v' * 40,
      platform: 'p' * 40,
      bank: 'b' * 20,
      source: 's' * 40,
    );
    final mailto = report.mailto.toString();
    final decoded = _mailtoBody(report);
    final app = _mailtoField(decoded, 'App: ');
    final version = app
        .replaceFirst('App: Scripture Trivia ', '')
        .split(' · ')
        .first;
    final platform = app.split(' · ').last;

    expect(mailto.length, lessThanOrEqualTo(maxMailtoLength));
    expect(mailto, contains('&body='));
    expect(version, isEmpty);
    expect(platform, isEmpty);
    expect(_mailtoField(decoded, 'Question bank: '), 'Question bank: ');
    expect(_mailtoField(decoded, 'Source: '), 'Source: ${'s' * 17}');
    expect(_mailtoField(decoded, 'Question: '), 'Question: P');
    expect(decoded, contains('Question ID: $id'));
    expect(decoded, contains('--- end of report ---'));
    expect(report.body, contains('s' * 40));
    expect(report.clipboardText, contains(report.body));
  });

  test('step 10 clips the body on a character boundary', () {
    final id = 'é' * 130;
    final prompt = '😀' * 8;
    final report = _sized(
      id: id,
      prompt: prompt,
      answer: 'A' * 400,
      selected: 'S' * 400,
      reference: 'R' * 400,
      version: 'v' * 32,
      platform: 'p' * 32,
      bank: 'b' * 16,
      source: '字' * 32,
    );
    final mailto = report.mailto.toString();
    final markerAt = mailto.indexOf('&body=');
    final encodedBody = mailto.substring(markerAt + '&body='.length);
    final subject = Uri.decodeComponent(
      mailto.split('?').last.split('&').first.replaceFirst('subject=', ''),
    );
    final decoded = utf8.decode(_percentBytes(encodedBody));

    expect(markerAt + '&body='.length, lessThanOrEqualTo(maxMailtoLength));
    expect(mailto.length, 1798);
    expect(mailto.length, lessThan(maxMailtoLength));
    expect(encodedBody, endsWith('%F0%9F%98%80%0D'));
    expect(encodedBody, isNot(matches(RegExp(r'%[0-9A-Fa-f]{0,1}$'))));
    expect(subject, report.subject);
    expect(subject, contains(id));
    expect(decoded, contains('Question ID: $id'));
    expect(decoded, endsWith('😀\r'));
    expect(decoded, isNot(contains('\uFFFD')));
    expect(decoded, isNot(contains('--- end of report ---')));
    expect(report.body, contains(prompt));
    expect(report.body, contains(id));
    expect(report.body, contains('A' * 400));
    expect(report.body, contains('字' * 32));
    expect(report.clipboardText, contains(report.body));
  });

  test('seeded reports stay inside the cap when the subject fits', () {
    final random = Random(20261119);
    const glyphs = ['a', 'é', '字', '😀', 'Q', '&', ' '];
    var fitted = 0;
    var subjectTooLong = 0;

    String field(int max) {
      final count = random.nextInt(max + 1);
      return [
        for (var i = 0; i < count; i++) glyphs[random.nextInt(glyphs.length)],
      ].join();
    }

    for (var sample = 0; sample < 40; sample++) {
      final report = _sized(
        id: sample == 39 ? 'é' * 400 : field(sample.isEven ? 80 : 360),
        prompt: field(240),
        answer: field(180),
        selected: field(180),
        reference: field(120),
        note: field(200),
        version: field(48),
        platform: field(48),
        bank: field(24),
        source: field(48),
      );
      expect(report.body, contains(report.prompt));
      expect(report.body, contains(report.questionId));
      expect(report.clipboardText, contains(report.body));
      expect(report.clipboardText, contains(report.correctAnswer));
      expect(report.clipboardText, contains(report.reference));

      final subjectLink = Uri.parse(
        'mailto:$kReportEmail?subject=${Uri.encodeComponent(report.subject)}',
      ).toString();
      final mailto = report.mailto.toString();
      if (subjectLink.length > maxMailtoLength) {
        subjectTooLong++;
        expect(mailto, subjectLink);
        expect(mailto, isNot(contains('&body=')));
        continue;
      }
      fitted++;
      expect(mailto.length, lessThanOrEqualTo(maxMailtoLength));
      final subject = Uri.decodeComponent(
        mailto.split('?').last.split('&').first.replaceFirst('subject=', ''),
      );
      expect(subject, report.subject);
      final markerAt = mailto.indexOf('&body=');
      if (markerAt < 0) {
        expect(mailto, subjectLink);
        continue;
      }
      final encodedBody = mailto.substring(markerAt + '&body='.length);
      // The clip keeps an empty `&body=` when that marker lands on 1,800,
      // because the subject-only cut uses `>`.
      if (encodedBody.isEmpty) {
        expect(mailto.length, maxMailtoLength);
        continue;
      }
      final decoded = utf8.decode(_percentBytes(encodedBody));
      expect(decoded, isNot(contains('\uFFFD')));
      expect(encodedBody, isNot(matches(RegExp(r'%[0-9A-Fa-f]{0,1}$'))));
    }

    expect(fitted, greaterThan(0));
    expect(subjectTooLong, greaterThan(0));
  });

  test('markReported is a no-op the second time', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final reports = container.read(reportedQuestionIdsProvider.notifier)
      ..markReported('ot-0001');
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

QuestionReport _sized({
  String id = 'q',
  String prompt = 'Q',
  String answer = 'A',
  String selected = 'S',
  String reference = 'R',
  String note = '',
  String version = 'v',
  String platform = 'p',
  String bank = 'b',
  String source = 's',
}) {
  return QuestionReport(
    questionId: id,
    prompt: prompt,
    correctAnswer: answer,
    selectedAnswer: selected,
    reference: reference,
    reason: ReportReason.other,
    note: note,
    appVersion: version,
    platform: platform,
    bankVersion: bank,
    source: source,
    createdAtUtc: DateTime.utc(2026, 11, 18, 15, 46),
  );
}

String _mailtoField(String body, String prefix) {
  return body.split('\r\n').firstWhere((line) => line.startsWith(prefix));
}

List<int> _percentBytes(String value) {
  final bytes = <int>[];
  for (var i = 0; i < value.length; i++) {
    final unit = value[i];
    if (unit == '%') {
      bytes.add(int.parse(value.substring(i + 1, i + 3), radix: 16));
      i += 2;
    } else {
      bytes.add(unit.codeUnitAt(0));
    }
  }
  return bytes;
}

int _bundledQuestionCount() {
  const files = [
    'assets/questions/v1/old_testament.json',
    'assets/questions/v1/new_testament.json',
    'assets/questions/v1/book_of_mormon.json',
    'assets/questions/v1/doctrine_and_covenants.json',
    'assets/questions/v1/pearl_of_great_price.json',
  ];
  var count = 0;
  for (final path in files) {
    count += (jsonDecode(File(path).readAsStringSync()) as List).length;
  }
  return count;
}
