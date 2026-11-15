import 'dart:convert';

import 'question_assets.dart';
import 'question_bank.dart';
import 'question_bank_exception.dart';
import 'question_bank_validator.dart';
import 'scripture_volume.dart';

/// Loads a v1 question bank from offline text assets.
///
/// [read] returns the file contents for an asset path. The app passes a
/// `rootBundle` reader from `loadBundledQuestionBank`. Tests and
/// `tool/validate_questions.dart` pass a file or memory reader. Nothing in
/// this class opens a network connection.
///
/// Malformed content throws [QuestionBankException]. In release mode the
/// bundled loader sets [requireApproved], and a draft question fails the
/// whole load instead of being skipped.
final class QuestionBankLoader {
  const QuestionBankLoader({
    required this.read,
    this.assets = const QuestionAssets(),
    this.requireApproved = false,
  });

  final Future<String> Function(String path) read;
  final QuestionAssets assets;

  /// When true, every question must be `approved` or the load fails.
  final bool requireApproved;

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

    final validation = QuestionBankValidator(requireApproved: requireApproved)
        .validate(assets: assets, decodedByVolume: decodedByVolume);

    final violations = <QuestionBankViolation>[
      ...readViolations,
      ...validation.violations,
    ];
    if (violations.isNotEmpty) {
      throw QuestionBankException(violations);
    }

    final bank = validation.bank;
    if (bank == null) {
      throw StateError('Question bank validation succeeded without a bank.');
    }
    return bank;
  }
}
