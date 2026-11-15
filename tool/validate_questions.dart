import 'dart:io';

import 'package:saints_trivia_flutter/data/questions/question_assets.dart';
import 'package:saints_trivia_flutter/data/questions/question_bank.dart';
import 'package:saints_trivia_flutter/data/questions/question_bank_exception.dart';
import 'package:saints_trivia_flutter/data/questions/question_bank_loader.dart';
import 'package:saints_trivia_flutter/data/questions/review_status.dart';
import 'package:saints_trivia_flutter/data/questions/scripture_volume.dart';

/// How many questions each volume of [QuestionAssets.v1Directory] must have.
///
/// Sample fixtures are not held to this. With `--require-approved`, only
/// questions whose review status is `approved` count.
const int minimumQuestionsPerVolume = 100;

/// Validates the offline question bank from the repository root.
///
/// Pull-request CI runs this with no flags (structure only). A release
/// workflow should pass `--require-approved` (alias `--release`). That flag
/// rejects any question that is still `draft` and, for the bundled bank,
/// counts only approved questions toward [minimumQuestionsPerVolume]. The
/// app does not use this flag: a release build skips drafts instead.
///
/// This file must not import `package:saints_trivia_flutter/data/questions/questions.dart`.
/// That barrel includes the Flutter asset loader, and `dart run` has no engine.
Future<void> main(List<String> args) async {
  exitCode = await runQuestionBankValidator(args);
}

/// Runs the validator and returns a process exit code.
///
/// `0` when the bank passes, `1` when content is invalid, `64` when the
/// arguments are wrong. [output] and [errorOutput] default to the process
/// stdout and stderr.
Future<int> runQuestionBankValidator(
  List<String> args, {
  StringSink? output,
  StringSink? errorOutput,
}) async {
  final out = output ?? stdout;
  final err = errorOutput ?? stderr;
  const usage = '''
Validate the offline scripture question bank.

Run this from the repository root.

Usage:
  dart run tool/validate_questions.dart [--require-approved|--release] [--bank <directory>]

Options:
  --require-approved, --release
      Reject any question whose reviewStatus is not "approved".
      For assets/questions/v1, also require at least 100 approved
      questions in each volume. Pull-request CI omits this flag.
      The release pipeline should pass it. The app does not: a release
      build skips drafts instead of failing the load.

  --bank <directory>
      Directory of volume JSON files. Defaults to assets/questions/v1.
      The v1 schema rules are always what is checked. The 100-question
      minimum applies only to the bundled assets/questions/v1 bank.

  --help
      Show this message.
''';

  var requireApproved = false;
  var directory = QuestionAssets.v1Directory;

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--help' || arg == '-h') {
      out.writeln(usage.trimRight());
      return 0;
    }
    if (arg == '--require-approved' || arg == '--release') {
      requireApproved = true;
      continue;
    }
    if (arg == '--bank') {
      if (i + 1 >= args.length) {
        err.writeln('Missing directory after --bank.');
        err.writeln(usage.trimRight());
        return 64;
      }
      i += 1;
      directory = args[i];
      continue;
    }
    err.writeln('Unknown argument "$arg".');
    err.writeln(usage.trimRight());
    return 64;
  }

  final assets = QuestionAssets(directory: directory);
  final loader = QuestionBankLoader(
    read: (path) => File(path).readAsString(),
    assets: assets,
  );

  try {
    final bank = await loader.load();
    final violations = <QuestionBankViolation>[
      if (requireApproved) ...unapprovedQuestionViolations(bank, assets),
      if (isBundledQuestionBank(directory))
        ...bundledVolumeMinimumViolations(
          bank,
          approvedOnly: requireApproved,
          directory: directory,
        ),
    ];
    if (violations.isNotEmpty) {
      err.writeln(QuestionBankException(violations));
      return 1;
    }
    final counts = [
      for (final volume in ScriptureVolume.values)
        '${volume.code}=${bank.forVolume(volume).length}',
    ].join(', ');
    final mode = requireApproved ? 'release, approved only' : 'structure only';
    out.writeln(
      'Validated ${bank.length} questions ($counts), '
      'schema v${bank.schemaVersion}, $mode, from $directory.',
    );
    return 0;
  } on QuestionBankException catch (error) {
    err.writeln(error);
    return 1;
  }
}

/// True for the bundled v1 directory, including a trailing slash or `./`.
bool isBundledQuestionBank(String directory) {
  var normalized = directory.trim().replaceAll('\\', '/');
  while (normalized.endsWith('/')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  if (normalized.startsWith('./')) {
    normalized = normalized.substring(2);
  }
  return normalized == QuestionAssets.v1Directory;
}

/// One violation per question that is not `approved`.
List<QuestionBankViolation> unapprovedQuestionViolations(
  QuestionBank bank,
  QuestionAssets assets,
) {
  final violations = <QuestionBankViolation>[];
  for (final volume in ScriptureVolume.values) {
    final questions = bank.forVolume(volume);
    for (var index = 0; index < questions.length; index++) {
      final question = questions[index];
      if (question.reviewStatus == ReviewStatus.approved) {
        continue;
      }
      violations.add(
        QuestionBankViolation(
          kind: QuestionBankViolationKind.notApproved,
          message:
              'Question ${question.id} is "${question.reviewStatus.value}". '
              'The release validator only allows approved questions.',
          assetPath: assets.pathFor(volume),
          questionId: question.id,
          index: index,
          field: 'reviewStatus',
        ),
      );
    }
  }
  return violations;
}

/// Violations for bundled volumes under [minimumQuestionsPerVolume].
///
/// When [approvedOnly] is true, drafts do not count. This is not applied to
/// fixture directories.
List<QuestionBankViolation> bundledVolumeMinimumViolations(
  QuestionBank bank, {
  required bool approvedOnly,
  int minimum = minimumQuestionsPerVolume,
  String directory = QuestionAssets.v1Directory,
}) {
  final assets = QuestionAssets(directory: directory);
  final violations = <QuestionBankViolation>[];
  for (final volume in ScriptureVolume.values) {
    final questions = bank.forVolume(volume);
    final count = approvedOnly
        ? questions
              .where(
                (question) => question.reviewStatus == ReviewStatus.approved,
              )
              .length
        : questions.length;
    if (count >= minimum) {
      continue;
    }
    final counted = approvedOnly ? 'approved questions' : 'questions';
    violations.add(
      QuestionBankViolation(
        kind: QuestionBankViolationKind.tooFewQuestions,
        message:
            '${volume.code} has $count $counted; '
            'the bundled bank needs at least $minimum per volume.',
        assetPath: assets.pathFor(volume),
      ),
    );
  }
  return violations;
}
