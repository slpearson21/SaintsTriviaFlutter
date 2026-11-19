import 'dart:convert';

import 'question_assets.dart';
import 'question_bank.dart';
import 'question_bank_exception.dart';
import 'question_bank_validator.dart';
import 'review_status.dart';
import 'scripture_volume.dart';

/// Loads a v1 question bank from offline text assets.
///
/// [read] returns the file contents for an asset path. The app passes a
/// `rootBundle` reader from `loadBundledQuestionBank`. Tests and
/// `tool/validate_questions.dart` pass a file or memory reader. Nothing in
/// this class opens a network connection.
///
/// Malformed content throws [QuestionBankException]. When [skipUnapproved]
/// is true, questions that are not `approved` are left out of the bank.
/// Skipping every question in a volume, or in the whole bank, still returns
/// a [QuestionBank]. It does not throw.
final class QuestionBankLoader {
  const QuestionBankLoader({
    required this.read,
    this.assets = QuestionAssets.v1,
    this.skipUnapproved = false,
  });

  final Future<String> Function(String path) read;
  final QuestionAssets assets;

  /// When true, structurally valid questions that are not `approved` are
  /// omitted. Schema errors still fail the load.
  final bool skipUnapproved;

  Future<QuestionBank> load() async {
    final decodedByVolume = <ScriptureVolume, Object?>{};
    final readViolations = <QuestionBankViolation>[];

    for (final volume in ScriptureVolume.values) {
      final path = assets.pathFor(volume);
      final String raw;
      try {
        raw = await read(path);
      } on Exception catch (error) {
        readViolations.add(
          QuestionBankViolation(
            kind: QuestionBankViolationKind.missingAsset,
            message: 'Could not read $path: $error',
            assetPath: path,
          ),
        );
        continue;
      }

      try {
        decodedByVolume[volume] = jsonDecode(raw);
      } on FormatException catch (error) {
        readViolations.add(
          QuestionBankViolation(
            kind: QuestionBankViolationKind.malformedJson,
            message: 'Malformed JSON in $path: ${error.message}',
            assetPath: path,
          ),
        );
      }
    }

    final validation = const QuestionBankValidator().validate(
      assets: assets,
      decodedByVolume: decodedByVolume,
    );

    final violations = <QuestionBankViolation>[
      ...readViolations,
      ...validation.violations,
    ];
    if (violations.isNotEmpty) {
      throw QuestionBankException(violations);
    }

    final questions = skipUnapproved
        ? [
            for (final question in validation.questions)
              if (question.reviewStatus == ReviewStatus.approved) question,
          ]
        : validation.questions;
    return QuestionBank(
      schemaVersion: assets.schemaVersion,
      questions: questions,
    );
  }
}
