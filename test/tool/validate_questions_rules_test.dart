import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:saints_trivia_flutter/data/questions/question_assets.dart';
import 'package:saints_trivia_flutter/data/questions/question_bank_exception.dart';
import 'package:saints_trivia_flutter/data/questions/question_bank_loader.dart';
import 'package:saints_trivia_flutter/data/questions/scripture_volume.dart';
import 'package:saints_trivia_flutter/scripture/scripture_link.dart';

import '../../tool/validate_questions.dart';

void main() {
  test('every Gospel Library book has a chapter count', () {
    expect(
      gospelLibraryBooks.map((book) => book.slug).toSet(),
      scriptureChapterCounts.keys.toSet(),
    );
    expect(scriptureChapterCounts.values, everyElement(greaterThan(0)));
  });

  test('the bundled bank still passes the content rules', () async {
    final output = StringBuffer();
    final errors = StringBuffer();

    expect(
      await runQuestionBankValidator(
        const [],
        output: output,
        errorOutput: errors,
      ),
      0,
    );
    expect(errors.toString(), isEmpty);
    expect(
      output.toString(),
      contains('Validated ${_bundledQuestionCount()} questions'),
    );
  });

  test('a clean sample bank has no content violations', () async {
    final directory = await _writeBank();

    expect(await _violations(directory), isEmpty);
    expect(
      await runQuestionBankValidator(
        ['--bank', directory],
        output: StringBuffer(),
        errorOutput: StringBuffer(),
      ),
      0,
    );
  });

  test('the command reports a content-rule failure', () async {
    final directory = await _writeBank(
      replace: {
        ScriptureVolume.ot: [
          _question(ScriptureVolume.ot, prompt: ' Leading space'),
        ],
      },
    );
    final errors = StringBuffer();

    expect(
      await runQuestionBankValidator(
        ['--bank', directory],
        output: StringBuffer(),
        errorOutput: errors,
      ),
      1,
    );
    expect(errors.toString(), contains('invalidValue'));
    expect(errors.toString(), contains('leading or trailing whitespace'));
    expect(errors.toString(), contains('ot-0001'));
  });

  test('leading or trailing whitespace is rejected', () async {
    final directory = await _writeBank(
      replace: {
        ScriptureVolume.ot: [_question(ScriptureVolume.ot, prompt: 'Hello ')],
        ScriptureVolume.nt: [
          _question(ScriptureVolume.nt, explanation: ' Because.'),
        ],
        ScriptureVolume.bom: [
          _question(ScriptureVolume.bom, reference: '1 Nephi 1:1 '),
        ],
        ScriptureVolume.dc: [
          _question(
            ScriptureVolume.dc,
            options: const ['One', 'Two', 'Three', ' Four'],
          ),
        ],
      },
    );

    final violations = await _violations(directory);
    expect(violations, hasLength(4));
    expect(violations.map((violation) => violation.questionId), [
      'ot-0001',
      'nt-0001',
      'bom-0001',
      'dc-0001',
    ]);
    expect(violations.map((violation) => violation.field), [
      'prompt',
      'explanation',
      'reference',
      'options',
    ]);
    expect(violations.map((violation) => violation.kind).toSet(), {
      QuestionBankViolationKind.invalidValue,
    });
    expect(violations[3].message, contains('Option 4'));
  });

  test('a prompt line break is rejected', () async {
    final directory = await _writeBank(
      replace: {
        ScriptureVolume.ot: [
          _question(ScriptureVolume.ot, prompt: 'First line\nsecond line'),
        ],
      },
    );

    final violations = await _violations(directory);
    expect(violations, hasLength(1));
    expect(violations.single.field, 'prompt');
    expect(violations.single.message, contains('single line'));
    expect(violations.single.index, 0);
  });

  test('prompts that match after folding are duplicates', () async {
    final directory = await _writeBank(
      replace: {
        ScriptureVolume.ot: [
          _question(ScriptureVolume.ot, prompt: 'Who built the ark?'),
        ],
        ScriptureVolume.nt: [
          _question(ScriptureVolume.nt, prompt: 'who  built   the ark?'),
        ],
      },
    );

    final violations = await _violations(directory);
    expect(violations, hasLength(1));
    expect(violations.single.questionId, 'nt-0001');
    expect(violations.single.field, 'prompt');
    expect(violations.single.message, contains('ot-0001'));
  });

  test('a reference must parse and match the volume', () async {
    final directory = await _writeBank(
      replace: {
        ScriptureVolume.ot: [
          _question(ScriptureVolume.ot, reference: 'Not scripture'),
        ],
        ScriptureVolume.nt: [
          _question(ScriptureVolume.nt, reference: 'Genesis 1:1'),
        ],
      },
    );

    final violations = await _violations(directory);
    expect(violations, hasLength(2));
    expect(violations[0].questionId, 'ot-0001');
    expect(violations[0].message, contains('does not parse'));
    expect(violations[1].questionId, 'nt-0001');
    expect(violations[1].message, contains('not NT'));
  });

  test('chapter numbers have to fall inside the book', () async {
    final directory = await _writeBank(
      replace: {
        ScriptureVolume.ot: [
          _question(ScriptureVolume.ot, reference: 'Genesis 50:1'),
          _question(
            ScriptureVolume.ot,
            number: 2,
            reference: 'Genesis 51:1',
            prompt: 'Past the last chapter',
          ),
        ],
        ScriptureVolume.dc: [
          _question(ScriptureVolume.dc, reference: 'D&C 138:1'),
          _question(
            ScriptureVolume.dc,
            number: 2,
            reference: 'OD 3',
            prompt: 'There is no third declaration',
          ),
        ],
        ScriptureVolume.pgp: [
          _question(ScriptureVolume.pgp, reference: 'Moses 8:1'),
        ],
      },
    );

    final violations = await _violations(directory);
    expect(violations.map((violation) => violation.questionId), [
      'ot-0002',
      'dc-0002',
    ]);
    expect(violations[0].message, contains('chapter 51'));
    expect(violations[0].message, contains('50 chapters'));
    expect(violations[1].message, contains('chapter 3'));
    expect(
      violations.every((violation) => violation.field == 'reference'),
      isTrue,
    );
  });

  test('a verse past the generic 176 cap is rejected', () async {
    final directory = await _writeBank(
      replace: {
        ScriptureVolume.ot: [
          _question(ScriptureVolume.ot, reference: 'Psalms 119:176'),
          _question(
            ScriptureVolume.ot,
            number: 2,
            reference: 'Genesis 1:177',
            prompt: 'Past the generic 176 cap',
          ),
          _question(
            ScriptureVolume.ot,
            number: 3,
            reference: 'Genesis 51:200',
            prompt: 'The chapter is already out of range',
          ),
        ],
      },
    );

    final violations = await _violations(directory);
    expect(violations.map((violation) => violation.questionId), [
      'ot-0002',
      'ot-0003',
    ]);
    expect(violations[0].message, contains('verse 177'));
    expect(
      violations[0].message,
      contains('generic $longestChapterVerseCount-verse cap (Psalm 119)'),
    );
    expect(violations[1].message, contains('chapter 51'));
    expect(violations[1].message, isNot(contains('verse')));
  });
}

Map<String, Object?> _question(
  ScriptureVolume volume, {
  int number = 1,
  String? reference,
  String? prompt,
  String? explanation,
  List<String>? options,
}) {
  return {
    'id': '${volume.idPrefix}-${number.toString().padLeft(4, '0')}',
    'volume': volume.code,
    'reference': reference ?? _reference(volume),
    'prompt': prompt ?? 'Prompt ${volume.code} $number',
    'options': options ?? const ['One', 'Two', 'Three', 'Four'],
    'answerIndex': 0,
    'explanation': explanation ?? 'Because ${volume.code} $number.',
    'reviewStatus': 'draft',
  };
}

String _reference(ScriptureVolume volume) {
  return switch (volume) {
    ScriptureVolume.ot => 'Genesis 1:1',
    ScriptureVolume.nt => 'Matthew 1:1',
    ScriptureVolume.bom => '1 Nephi 1:1',
    ScriptureVolume.dc => 'D&C 1:1',
    ScriptureVolume.pgp => 'Moses 1:1',
  };
}

Future<String> _writeBank({
  Map<ScriptureVolume, List<Map<String, Object?>>> replace = const {},
}) async {
  final root = await Directory.systemTemp.createTemp('st-bank-');
  addTearDown(() async {
    if (root.existsSync()) await root.delete(recursive: true);
  });
  final assets = QuestionAssets(directory: root.path);
  for (final volume in ScriptureVolume.values) {
    final questions = replace[volume] ?? [_question(volume)];
    await File(assets.pathFor(volume)).writeAsString(jsonEncode(questions));
  }
  return root.path;
}

int _bundledQuestionCount() {
  final assets = QuestionAssets();
  var count = 0;
  for (final volume in ScriptureVolume.values) {
    final questions =
        jsonDecode(File(assets.pathFor(volume)).readAsStringSync()) as List;
    count += questions.length;
  }
  return count;
}

Future<List<QuestionBankViolation>> _violations(String directory) async {
  final assets = QuestionAssets(directory: directory);
  final bank = await QuestionBankLoader(
    read: (path) => File(path).readAsString(),
    assets: assets,
  ).load();
  return questionContentViolations(bank, assets);
}
