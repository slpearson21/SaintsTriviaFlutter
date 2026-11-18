import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saints_trivia_flutter/data/questions/questions.dart';

import '../../../tool/validate_questions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('sample fixtures', () {
    test('loads five questions from each volume', () async {
      final bank = await loadDirectory('test/fixtures/questions/v1');

      expect(bank.schemaVersion, 1);
      expect(bank.length, 25);
      for (final volume in ScriptureVolume.values) {
        expect(bank.forVolume(volume), hasLength(5));
      }

      final first = bank.questions.first;
      expect(first.id, 'ot-0001');
      expect(first.volume, ScriptureVolume.ot);
      expect(first.reference, 'Genesis 1:1');
      expect(
        first.prompt,
        'According to the first verse of the Bible, what did God create in the beginning?',
      );
      expect(first.options, [
        'The Garden of Eden',
        'The heaven and the earth',
        'Man and woman',
        'The sun and the moon',
      ]);
      expect(first.answerIndex, 1);
      expect(first.answer, 'The heaven and the earth');
      expect(
        first.explanation,
        'Genesis opens with God creating the heaven and the earth.',
      );
      expect(first.reviewStatus, ReviewStatus.draft);
      expect(() => first.options[0] = 'changed', throwsUnsupportedError);
      expect(() => bank.questions.add(first), throwsUnsupportedError);
    });

    test('are the first five questions of each bundled volume', () async {
      final samples = await loadDirectory('test/fixtures/questions/v1');
      final full = await loadDirectory('assets/questions/v1');

      for (final volume in ScriptureVolume.values) {
        expect(
          samples.forVolume(volume),
          full.forVolume(volume).take(5).toList(),
        );
      }
    });

    test('keeps a caller from mutating the options passed to the model', () {
      final options = ['One', 'Two', 'Three', 'Four'];
      final question = TriviaQuestion(
        id: 'ot-0099',
        volume: ScriptureVolume.ot,
        reference: 'Genesis 1:1',
        prompt: 'Who created the heaven and the earth?',
        options: options,
        answerIndex: 0,
        explanation: 'God created the heaven and the earth.',
        reviewStatus: ReviewStatus.draft,
      );

      options[0] = 'changed';

      expect(question.options, ['One', 'Two', 'Three', 'Four']);
    });
  });

  group('bundled bank', () {
    const counts = {
      ScriptureVolume.ot: 128,
      ScriptureVolume.nt: 124,
      ScriptureVolume.bom: 112,
      ScriptureVolume.dc: 109,
      ScriptureVolume.pgp: 118,
    };

    test('rootBundle loads all 591 draft questions in volume order', () async {
      final fromFiles = await loadDirectory(QuestionAssets.v1Directory);
      final bundled = await loadBundledQuestionBank();

      expect(bundled.schemaVersion, 1);
      expect(bundled.length, 591);
      expect(bundled.questions, fromFiles.questions);
      expect(bundled.questions.map((question) => question.volume).toList(), [
        for (final volume in ScriptureVolume.values)
          for (var i = 0; i < counts[volume]!; i++) volume,
      ]);
      for (final volume in ScriptureVolume.values) {
        final questions = bundled.forVolume(volume);
        expect(questions, hasLength(counts[volume]));
        expect(questions.map((question) => question.id).toList(), [
          for (var number = 1; number <= counts[volume]!; number++)
            '${volume.idPrefix}-${number.toString().padLeft(4, '0')}',
        ]);
      }
      expect(
        bundled.questions.map((question) => question.reviewStatus).toSet(),
        {ReviewStatus.draft},
      );

      final matthew = bundled.questions.firstWhere(
        (question) => question.id == 'pgp-0059',
      );
      expect(matthew.reference, 'Joseph Smith—Matthew 1:4');
      expect(
        matthew.prompt.length,
        lessThanOrEqualTo(QuestionLimits.promptMaxLength),
      );
      expect(
        matthew.explanation.length,
        lessThanOrEqualTo(QuestionLimits.explanationMaxLength),
      );
    });

    test('skipping unapproved questions drops the draft bank', () async {
      final bank = await loadBundledQuestionBank(skipUnapproved: true);

      expect(bank.schemaVersion, 1);
      expect(bank.isEmpty, isTrue);
      expect(bank.availableVolumes, isEmpty);
      for (final volume in ScriptureVolume.values) {
        expect(bank.hasQuestionsFor(volume), isFalse);
        expect(bank.forVolume(volume), isEmpty);
      }
    });

    test(
      'release builds skip unapproved questions; debug and profile do not',
      () {
        expect(skipUnapprovedQuestions(), kReleaseMode);
        expect(skipUnapprovedQuestions(skipUnapproved: true), isTrue);
        expect(skipUnapprovedQuestions(skipUnapproved: false), isFalse);
      },
    );

    test('a missing asset is a typed error', () async {
      final error = await expectLoadFailure(
        loadBundledQuestionBank(
          assets: const QuestionAssets(directory: 'assets/questions/missing'),
        ),
      );

      expect(error.violations, hasLength(ScriptureVolume.values.length));
      expect(
        error.violations.every(
          (violation) =>
              violation.kind == QuestionBankViolationKind.missingAsset,
        ),
        isTrue,
      );
    });
  });

  group('fromJson', () {
    test('reads one valid object', () {
      final question = TriviaQuestion.fromJson(
        validQuestion(ScriptureVolume.nt),
      );

      expect(question.id, 'nt-0001');
      expect(question.volume, ScriptureVolume.nt);
      expect(question.reviewStatus, ReviewStatus.draft);
    });

    test('throws a typed error for a malformed object', () {
      expect(
        () => TriviaQuestion.fromJson({'id': 'ot-0001'}),
        throwsA(
          isA<QuestionBankException>().having(
            (error) => error.toString(),
            'toString',
            contains(QuestionBankException.userMessage),
          ),
        ),
      );
    });
  });

  group('validator rules', () {
    test('a synthetic five-volume bank loads', () async {
      final bank = await loadVolumes();

      expect(bank.length, ScriptureVolume.values.length);
      expect(bank.questions.map((question) => question.id).toList(), [
        for (final volume in ScriptureVolume.values) idFor(volume),
      ]);
    });

    test(
      'development mode loads draft and approved questions together',
      () async {
        final bank = await loadVolumes(
          replace: {
            ScriptureVolume.pgp: [
              validQuestion(ScriptureVolume.pgp, reviewStatus: 'approved'),
            ],
          },
        );

        expect(
          bank.forVolume(ScriptureVolume.pgp).single.reviewStatus,
          ReviewStatus.approved,
        );
      },
    );

    test('malformed JSON is a typed error', () async {
      final error = await failureRaw(ScriptureVolume.ot, '{ "questions": ');

      expect(
        error.violations.single.kind,
        QuestionBankViolationKind.malformedJson,
      );
      expect(error.toString(), contains(QuestionBankException.userMessage));
    });

    test('a JSON object is not a volume file', () async {
      final error = await failureRaw(ScriptureVolume.nt, '{}');

      expect(
        error.violations.single.kind,
        QuestionBankViolationKind.invalidShape,
      );
    });

    test('an empty volume file is rejected', () async {
      final error = await failureRaw(ScriptureVolume.bom, '[]');

      expect(
        error.violations.single.kind,
        QuestionBankViolationKind.invalidShape,
      );
      expect(
        error.violations.single.assetPath,
        endsWith('book_of_mormon.json'),
      );
    });

    test('a question must be an object', () async {
      final error = await failureOn(ScriptureVolume.dc, ['not a question']);

      expect(
        error.violations.single.kind,
        QuestionBankViolationKind.invalidShape,
      );
      expect(error.violations.single.index, 0);
    });

    test('duplicate ids in one volume are rejected', () async {
      final error = await failureOn(ScriptureVolume.ot, [
        validQuestion(ScriptureVolume.ot),
        validQuestion(ScriptureVolume.ot, number: 2)
          ..['id'] = idFor(ScriptureVolume.ot),
      ]);

      expect(
        error.violations.single.kind,
        QuestionBankViolationKind.duplicateId,
      );
      expect(error.violations.single.questionId, 'ot-0001');
      expect(error.violations.single.index, 1);
    });

    test('duplicate ids across volumes are rejected', () async {
      final intruder = validQuestion(ScriptureVolume.nt)
        ..['id'] = idFor(ScriptureVolume.ot)
        ..['volume'] = 'OT';
      final error = await failureOn(ScriptureVolume.nt, [intruder]);

      expect(
        error.violations.map((violation) => violation.kind),
        contains(QuestionBankViolationKind.duplicateId),
      );
      expect(
        error.violations
            .where(
              (violation) =>
                  violation.kind == QuestionBankViolationKind.duplicateId,
            )
            .single
            .questionId,
        'ot-0001',
      );
    });

    test(
      'rejects options that match after trimming and case-folding',
      () async {
        final byCase = await failureOn(ScriptureVolume.ot, [
          validQuestion(ScriptureVolume.ot)
            ..['options'] = ['Eden', 'eden', 'Ur', 'Nod'],
        ]);
        final bySpace = await failureOn(ScriptureVolume.ot, [
          validQuestion(ScriptureVolume.ot)
            ..['options'] = ['Eden', ' Eden ', 'Ur', 'Nod'],
        ]);

        expect(
          byCase.violations.single.kind,
          QuestionBankViolationKind.duplicateOption,
        );
        expect(byCase.violations.single.field, 'options');
        expect(
          bySpace.violations.single.kind,
          QuestionBankViolationKind.duplicateOption,
        );
      },
    );

    test('rejects three options and five options', () async {
      final tooFew = validQuestion(ScriptureVolume.ot)
        ..['options'] = ['One', 'Two', 'Three'];
      final tooMany = validQuestion(ScriptureVolume.nt)
        ..['options'] = ['One', 'Two', 'Three', 'Four', 'Five'];

      final few = await failureOn(ScriptureVolume.ot, [tooFew]);
      final many = await failureOn(ScriptureVolume.nt, [tooMany]);

      expect(few.violations.single.kind, QuestionBankViolationKind.optionCount);
      expect(few.violations.single.field, 'options');
      expect(
        many.violations.single.kind,
        QuestionBankViolationKind.optionCount,
      );
    });

    test('rejects an out-of-range answerIndex', () async {
      for (final index in [-1, 4]) {
        final error = await failureOn(ScriptureVolume.ot, [
          validQuestion(ScriptureVolume.ot)..['answerIndex'] = index,
        ]);
        expect(
          error.violations.single.kind,
          QuestionBankViolationKind.answerIndex,
        );
        expect(error.violations.single.field, 'answerIndex');
      }
    });

    test('rejects an answerIndex that is not an integer', () async {
      final asDouble = await failureRaw(
        ScriptureVolume.ot,
        jsonEncode([validQuestion(ScriptureVolume.ot)])
            .replaceFirst('"answerIndex":0', '"answerIndex":1.5'),
      );
      final asBool = await failureRaw(
        ScriptureVolume.ot,
        jsonEncode([validQuestion(ScriptureVolume.ot)])
            .replaceFirst('"answerIndex":0', '"answerIndex":true'),
      );
      final asString = await failureOn(ScriptureVolume.ot, [
        validQuestion(ScriptureVolume.ot)..['answerIndex'] = '0',
      ]);

      expect(
        asDouble.violations.single.kind,
        QuestionBankViolationKind.answerIndex,
      );
      expect(
        asBool.violations.single.kind,
        QuestionBankViolationKind.answerIndex,
      );
      expect(
        asString.violations.single.kind,
        QuestionBankViolationKind.answerIndex,
      );
    });

    test('rejects an id prefix that does not match the volume', () async {
      final error = await failureOn(ScriptureVolume.ot, [
        validQuestion(ScriptureVolume.ot)..['id'] = 'nt-0099',
      ]);

      expect(
        error.violations.single.kind,
        QuestionBankViolationKind.idVolumeMismatch,
      );
      expect(error.violations.single.field, 'id');
      expect(error.violations.single.questionId, 'nt-0099');
    });

    test('rejects a volume that does not match its file', () async {
      final error = await failureOn(ScriptureVolume.ot, [
        validQuestion(ScriptureVolume.nt, number: 99),
      ]);

      expect(
        error.violations.single.kind,
        QuestionBankViolationKind.idVolumeMismatch,
      );
      expect(error.violations.single.field, 'volume');
      expect(error.violations.single.questionId, 'nt-0099');
    });

    test('rejects an id that is not prefix-and-four-digits', () async {
      final shortId = await failureOn(ScriptureVolume.ot, [
        validQuestion(ScriptureVolume.ot)..['id'] = 'ot-1',
      ]);
      final longId = await failureOn(ScriptureVolume.ot, [
        validQuestion(ScriptureVolume.ot)..['id'] = 'ot-00001',
      ]);

      expect(
        shortId.violations.single.kind,
        QuestionBankViolationKind.invalidValue,
      );
      expect(shortId.violations.single.field, 'id');
      expect(
        longId.violations.single.kind,
        QuestionBankViolationKind.invalidValue,
      );
      expect(longId.violations.single.field, 'id');
    });

    test('rejects empty and whitespace-only fields', () async {
      final cases = <String, Map<String, Object?>>{
        'id': validQuestion(ScriptureVolume.ot)..['id'] = '',
        'reference': validQuestion(ScriptureVolume.ot)..['reference'] = '   ',
        'prompt': validQuestion(ScriptureVolume.ot)..['prompt'] = '',
        'explanation': validQuestion(ScriptureVolume.ot)
          ..['explanation'] = '\n',
        'options': validQuestion(ScriptureVolume.ot)
          ..['options'] = ['One', ' ', 'Three', 'Four'],
      };

      for (final entry in cases.entries) {
        final error = await failureOn(ScriptureVolume.ot, [entry.value]);
        expect(
          error.violations.single.kind,
          QuestionBankViolationKind.emptyField,
          reason: entry.key,
        );
        expect(error.violations.single.field, entry.key, reason: entry.key);
      }
    });

    test('rejects prompts and explanations over the length cap', () async {
      final prompt = await failureOn(ScriptureVolume.ot, [
        validQuestion(ScriptureVolume.ot)
          ..['prompt'] = 'p' * (QuestionLimits.promptMaxLength + 1),
      ]);
      final explanation = await failureOn(ScriptureVolume.ot, [
        validQuestion(ScriptureVolume.ot)
          ..['explanation'] = 'e' * (QuestionLimits.explanationMaxLength + 1),
      ]);

      expect(
        prompt.violations.single.kind,
        QuestionBankViolationKind.overLength,
      );
      expect(prompt.violations.single.field, 'prompt');
      expect(
        explanation.violations.single.kind,
        QuestionBankViolationKind.overLength,
      );
      expect(explanation.violations.single.field, 'explanation');
    });

    test(
      'accepts a prompt and explanation at exactly the length cap',
      () async {
        final bank = await loadVolumes(
          replace: {
            ScriptureVolume.ot: [
              validQuestion(ScriptureVolume.ot)
                ..['prompt'] = 'p' * QuestionLimits.promptMaxLength
                ..['explanation'] = 'e' * QuestionLimits.explanationMaxLength,
            ],
          },
        );

        final question = bank.forVolume(ScriptureVolume.ot).single;
        expect(question.prompt.length, QuestionLimits.promptMaxLength);
        expect(
          question.explanation.length,
          QuestionLimits.explanationMaxLength,
        );
      },
    );

    test(
      'rejects a multi-line explanation and allows a newline in the prompt',
      () async {
        final explanation = await failureOn(ScriptureVolume.ot, [
          validQuestion(ScriptureVolume.ot)
            ..['explanation'] = 'Line one.\nLine two.',
        ]);
        final bank = await loadVolumes(
          replace: {
            ScriptureVolume.ot: [
              validQuestion(ScriptureVolume.ot)
                ..['prompt'] = 'Line one.\nLine two?',
            ],
          },
        );

        expect(
          explanation.violations.single.kind,
          QuestionBankViolationKind.multilineField,
        );
        expect(explanation.violations.single.field, 'explanation');
        expect(
          bank.forVolume(ScriptureVolume.ot).single.prompt,
          contains('\n'),
        );
      },
    );

    test(
      'rejects a missing field, an unknown field, and a bad status',
      () async {
        final missing = Map<String, Object?>.of(
          validQuestion(ScriptureVolume.ot),
        )..remove('prompt');
        final unknown = validQuestion(ScriptureVolume.ot)
          ..['difficulty'] = 'easy';
        final status = validQuestion(ScriptureVolume.ot)
          ..['reviewStatus'] = 'published';

        final missingError = await failureOn(ScriptureVolume.ot, [missing]);
        final unknownError = await failureOn(ScriptureVolume.ot, [unknown]);
        final statusError = await failureOn(ScriptureVolume.ot, [status]);

        expect(
          missingError.violations.single.kind,
          QuestionBankViolationKind.missingField,
        );
        expect(missingError.violations.single.field, 'prompt');
        expect(
          unknownError.violations.single.kind,
          QuestionBankViolationKind.unknownField,
        );
        expect(unknownError.violations.single.field, 'difficulty');
        expect(
          statusError.violations.single.kind,
          QuestionBankViolationKind.invalidValue,
        );
        expect(statusError.violations.single.field, 'reviewStatus');
      },
    );

    test('skipping drafts leaves an empty bank instead of throwing', () async {
      final bank = await loadVolumes(skipUnapproved: true);

      expect(bank.isEmpty, isTrue);
      expect(bank.availableVolumes, isEmpty);
      expect(bank.forVolume(ScriptureVolume.ot), isEmpty);
      expect(bank.hasQuestionsFor(ScriptureVolume.nt), isFalse);
    });

    test(
      'skipping drafts keeps approved questions and the volumes that have them',
      () async {
        final bank = await loadVolumes(
          replace: {
            for (final volume in ScriptureVolume.values)
              volume: switch (volume) {
                ScriptureVolume.bom => [
                  validQuestion(volume, reviewStatus: 'approved'),
                  validQuestion(volume, number: 2),
                ],
                ScriptureVolume.pgp => [
                  validQuestion(volume, number: 3, reviewStatus: 'approved'),
                ],
                _ => [validQuestion(volume)],
              },
          },
          skipUnapproved: true,
        );

        expect(bank.length, 2);
        expect(bank.availableVolumes, [
          ScriptureVolume.bom,
          ScriptureVolume.pgp,
        ]);
        expect(bank.hasQuestionsFor(ScriptureVolume.ot), isFalse);
        expect(bank.forVolume(ScriptureVolume.dc), isEmpty);
        expect(
          bank.forVolume(ScriptureVolume.bom).single.reviewStatus,
          ReviewStatus.approved,
        );
        expect(bank.forVolume(ScriptureVolume.pgp).single.id, 'pgp-0003');
      },
    );

    test('skipping drafts still fails the load on a schema error', () async {
      final error = await loadFailure(
        loaderFor(
          replace: {
            ScriptureVolume.ot: [
              validQuestion(ScriptureVolume.ot)..['answerIndex'] = 9,
            ],
          },
          skipUnapproved: true,
        ),
      );

      expect(
        error.violations.single.kind,
        QuestionBankViolationKind.answerIndex,
      );
      expect(error.toString(), contains(QuestionBankException.userMessage));
    });

    test(
      'a fully approved bank is unchanged when drafts are skipped',
      () async {
        final bank = await loadVolumes(
          replace: {
            for (final volume in ScriptureVolume.values)
              volume: [validQuestion(volume, reviewStatus: 'approved')],
          },
          skipUnapproved: true,
        );

        expect(bank.length, ScriptureVolume.values.length);
        expect(bank.availableVolumes, ScriptureVolume.values);
        expect(
          bank.questions.every(
            (question) => question.reviewStatus == ReviewStatus.approved,
          ),
          isTrue,
        );
      },
    );

    test(
      'an unreadable file is a typed error and does not hide other files',
      () async {
        final error = await loadFailure(
          QuestionBankLoader(
            read: (path) async {
              if (path.endsWith('old_testament.json')) {
                throw FileSystemException('missing', path);
              }
              return jsonEncode([
                validQuestion(
                  ScriptureVolume.values.firstWhere(
                    (volume) => path.endsWith(volume.fileName),
                  ),
                ),
              ]);
            },
          ),
        );

        expect(
          error.violations.single.kind,
          QuestionBankViolationKind.missingAsset,
        );
        expect(
          error.violations.single.assetPath,
          endsWith('old_testament.json'),
        );
      },
    );
  });

  group('malformed fixture file', () {
    test('the on-disk malformed file fails as a typed error', () async {
      const assets = QuestionAssets(
        directory: 'test/fixtures/questions/v1',
      );
      final files = <String, String>{};
      for (final volume in ScriptureVolume.values) {
        final path = assets.pathFor(volume);
        files[path] = await File(path).readAsString();
      }
      const malformedPath = 'test/fixtures/questions/malformed.json';
      files[assets.pathFor(ScriptureVolume.ot)] = await File(malformedPath)
          .readAsString();

      final error = await loadFailure(
        QuestionBankLoader(read: (path) async => files[path]!, assets: assets),
      );

      expect(error, isA<QuestionBankException>());
      expect(
        error.violations.single.kind,
        QuestionBankViolationKind.malformedJson,
      );
      expect(error.violations.single.assetPath, endsWith('old_testament.json'));
      expect(error.toString(), contains('Content failed to load.'));
    });
  });

  group('validator command', () {
    test('accepts the real bank without the release flag', () async {
      final output = StringBuffer();
      final errorOutput = StringBuffer();

      expect(
        await runQuestionBankValidator(
          const [],
          output: output,
          errorOutput: errorOutput,
        ),
        0,
      );
      expect(errorOutput.toString(), isEmpty);
      expect(
        output.toString(),
        contains(
          'Validated 591 questions (OT=128, NT=124, BOM=112, DC=109, PGP=118), '
          'schema v1, structure only, from assets/questions/v1.',
        ),
      );
    });

    test('require-approved and release reject the draft bank', () async {
      final required = StringBuffer();
      final release = StringBuffer();

      expect(
        await runQuestionBankValidator(
          const ['--require-approved'],
          output: StringBuffer(),
          errorOutput: required,
        ),
        1,
      );
      expect(
        await runQuestionBankValidator(
          const ['--release'],
          output: StringBuffer(),
          errorOutput: release,
        ),
        1,
      );
      expect(required.toString(), contains('notApproved'));
      expect(required.toString(), contains('ot-0001'));
      expect(required.toString(), contains('tooFewQuestions'));
      expect(release.toString(), contains('pgp-0118'));
      expect(release.toString(), contains('tooFewQuestions'));
    });

    test('fixtures are not held to the bundled 100-question minimum', () async {
      final errors = StringBuffer();

      expect(
        await runQuestionBankValidator(
          const ['--require-approved', '--bank', 'test/fixtures/questions/v1'],
          output: StringBuffer(),
          errorOutput: errors,
        ),
        1,
      );
      expect(errors.toString(), contains('notApproved'));
      expect(errors.toString(), isNot(contains('tooFewQuestions')));
    });

    test(
      'the 100-question minimum counts approved questions only when required',
      () {
        expect(minimumQuestionsPerVolume, 100);
        expect(isBundledQuestionBank('assets/questions/v1'), isTrue);
        expect(isBundledQuestionBank('assets/questions/v1/'), isTrue);
        expect(isBundledQuestionBank('./assets/questions/v1'), isTrue);
        expect(isBundledQuestionBank('test/fixtures/questions/v1'), isFalse);

        final small = QuestionBank(
          schemaVersion: 1,
          questions: [
            for (final volume in ScriptureVolume.values)
              TriviaQuestion.fromJson(validQuestion(volume)),
          ],
        );
        final belowMinimum = bundledVolumeMinimumViolations(
          small,
          approvedOnly: false,
        );
        expect(belowMinimum, hasLength(ScriptureVolume.values.length));
        expect(belowMinimum.map((violation) => violation.kind).toSet(), {
          QuestionBankViolationKind.tooFewQuestions,
        });

        final approved = QuestionBank(
          schemaVersion: 1,
          questions: [
            for (final volume in ScriptureVolume.values)
              for (
                var number = 1;
                number <= minimumQuestionsPerVolume;
                number++
              )
                TriviaQuestion.fromJson(
                  validQuestion(
                    volume,
                    number: number,
                    reviewStatus: 'approved',
                  ),
                ),
          ],
        );
        expect(
          bundledVolumeMinimumViolations(approved, approvedOnly: false),
          isEmpty,
        );
        expect(
          bundledVolumeMinimumViolations(approved, approvedOnly: true),
          isEmpty,
        );

        final drafts = QuestionBank(
          schemaVersion: 1,
          questions: [
            for (final volume in ScriptureVolume.values)
              for (
                var number = 1;
                number <= minimumQuestionsPerVolume;
                number++
              )
                TriviaQuestion.fromJson(validQuestion(volume, number: number)),
          ],
        );
        expect(
          bundledVolumeMinimumViolations(drafts, approvedOnly: false),
          isEmpty,
        );
        expect(
          bundledVolumeMinimumViolations(drafts, approvedOnly: true),
          hasLength(ScriptureVolume.values.length),
        );
      },
    );

    test('can validate the sample fixture directory', () async {
      final output = StringBuffer();

      expect(
        await runQuestionBankValidator(
          const ['--bank', 'test/fixtures/questions/v1'],
          output: output,
          errorOutput: StringBuffer(),
        ),
        0,
      );
      expect(output.toString(), contains('Validated 25 questions'));
      expect(output.toString(), contains('structure only'));
    });

    test('reports usage errors', () async {
      final help = StringBuffer();
      final missing = StringBuffer();
      final unknown = StringBuffer();

      expect(
        await runQuestionBankValidator(
          const ['--help'],
          output: help,
          errorOutput: StringBuffer(),
        ),
        0,
      );
      expect(help.toString(), contains('--require-approved'));
      expect(
        await runQuestionBankValidator(
          const ['--bank'],
          output: StringBuffer(),
          errorOutput: missing,
        ),
        64,
      );
      expect(missing.toString(), contains('Missing directory'));
      expect(
        await runQuestionBankValidator(
          const ['--nope'],
          output: StringBuffer(),
          errorOutput: unknown,
        ),
        64,
      );
      expect(unknown.toString(), contains('Unknown argument'));
    });
  });
}

Future<QuestionBank> loadDirectory(String directory) {
  return QuestionBankLoader(
    read: (path) => File(path).readAsString(),
    assets: QuestionAssets(directory: directory),
  ).load();
}

QuestionBankLoader loaderFor({
  Map<ScriptureVolume, List<Object?>> replace = const {},
  bool skipUnapproved = false,
  QuestionAssets assets = const QuestionAssets(directory: 'mem'),
}) {
  final files = <String, String>{
    for (final volume in ScriptureVolume.values)
      assets.pathFor(volume): jsonEncode(
        replace[volume] ?? [validQuestion(volume)],
      ),
  };
  return QuestionBankLoader(
    read: (path) async => files[path]!,
    assets: assets,
    skipUnapproved: skipUnapproved,
  );
}

Future<QuestionBank> loadVolumes({
  Map<ScriptureVolume, List<Object?>> replace = const {},
  bool skipUnapproved = false,
}) {
  return loaderFor(replace: replace, skipUnapproved: skipUnapproved).load();
}

Future<QuestionBankException> failureOn(
  ScriptureVolume volume,
  List<Object?> questions,
) {
  return loadFailure(loaderFor(replace: {volume: questions}));
}

Future<QuestionBankException> failureRaw(ScriptureVolume volume, String json) {
  const assets = QuestionAssets(directory: 'mem');
  final files = <String, String>{
    for (final candidate in ScriptureVolume.values)
      assets.pathFor(candidate): jsonEncode([validQuestion(candidate)]),
  };
  files[assets.pathFor(volume)] = json;
  return loadFailure(
    QuestionBankLoader(read: (path) async => files[path]!, assets: assets),
  );
}

Future<QuestionBankException> loadFailure(QuestionBankLoader loader) {
  return expectLoadFailure(loader.load());
}

Future<QuestionBankException> expectLoadFailure(
  Future<QuestionBank> future,
) async {
  try {
    await future;
  } on QuestionBankException catch (error) {
    return error;
  }
  throw StateError('expected QuestionBankException, but the bank loaded');
}

Map<String, Object?> validQuestion(
  ScriptureVolume volume, {
  int number = 1,
  String reviewStatus = 'draft',
}) {
  return {
    'id': idFor(volume, number: number),
    'volume': volume.code,
    'reference': '${volume.label} 1:$number',
    'prompt': 'Sample prompt ${volume.code}-$number',
    'options': ['One', 'Two', 'Three', 'Four'],
    'answerIndex': 0,
    'explanation': 'Sample explanation ${volume.code}-$number.',
    'reviewStatus': reviewStatus,
  };
}

String idFor(ScriptureVolume volume, {int number = 1}) {
  return '${volume.idPrefix}-${number.toString().padLeft(4, '0')}';
}
