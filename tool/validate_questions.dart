import 'dart:io';

import 'package:saints_trivia_flutter/data/questions/question_assets.dart';
import 'package:saints_trivia_flutter/data/questions/question_bank_exception.dart';
import 'package:saints_trivia_flutter/data/questions/question_bank_loader.dart';
import 'package:saints_trivia_flutter/data/questions/scripture_volume.dart';

/// Validates the offline question bank from the repository root.
///
/// Pull-request CI runs this with no flags (structure only). A release
/// workflow should pass `--require-approved` (alias `--release`) so a
/// question that is still `draft` fails the release. The current bank is
/// entirely draft pending doctrinal review, so that flag fails closed.
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
      Pull-request CI omits this flag so the draft bank can land.
      The release workflow should pass it. The app loader applies the
      same rule automatically in release mode.

  --bank <directory>
      Directory of volume JSON files. Defaults to assets/questions/v1.
      The v1 schema rules are always what is checked.

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

  final loader = QuestionBankLoader(
    read: (path) => File(path).readAsString(),
    assets: QuestionAssets(directory: directory),
    requireApproved: requireApproved,
  );

  try {
    final bank = await loader.load();
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
