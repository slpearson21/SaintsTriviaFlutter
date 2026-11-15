import 'question_assets.dart';
import 'question_bank.dart';
import 'question_bank_exception.dart';
import 'scripture_volume.dart';
import 'trivia_question.dart';

/// Checks a decoded v1 bank: file shape, per-question schema, and unique ids.
///
/// JSON syntax errors are reported by the loader before this runs. The same
/// rules gate the app and `tool/validate_questions.dart`.
final class QuestionBankValidator {
  const QuestionBankValidator({this.requireApproved = false});

  /// When true, a question that is not `approved` is a not-approved violation.
  /// The loader does not drop that question and keep the rest.
  final bool requireApproved;

  QuestionBankValidation validate({
    required QuestionAssets assets,
    required Map<ScriptureVolume, Object?> decodedByVolume,
  }) {
    final questions = <TriviaQuestion>[];
    final violations = <QuestionBankViolation>[];
    final seenIds = <String, _IdSite>{};

    for (final volume in ScriptureVolume.values) {
      if (!decodedByVolume.containsKey(volume)) {
        continue;
      }
      final path = assets.pathFor(volume);
      final decoded = decodedByVolume[volume];
      if (decoded is! List) {
        violations.add(
          QuestionBankViolation(
            kind: QuestionBankViolationKind.invalidShape,
            message: 'Volume file must be a JSON array of questions.',
            assetPath: path,
          ),
        );
        continue;
      }
      if (decoded.isEmpty) {
        violations.add(
          QuestionBankViolation(
            kind: QuestionBankViolationKind.invalidShape,
            message: 'Volume file must contain at least one question.',
            assetPath: path,
          ),
        );
        continue;
      }

      for (var index = 0; index < decoded.length; index++) {
        final parsed = TriviaQuestion.parse(
          decoded[index],
          requireApproved: requireApproved,
          expectedVolume: volume,
          assetPath: path,
          index: index,
        );
        violations.addAll(parsed.violations);

        final id = parsed.id;
        if (id != null) {
          final previous = seenIds[id];
          if (previous != null) {
            violations.add(
              QuestionBankViolation(
                kind: QuestionBankViolationKind.duplicateId,
                message:
                    'Duplicate id "$id". Also appears in ${previous.path} at index ${previous.index}.',
                assetPath: path,
                questionId: id,
                index: index,
                field: 'id',
              ),
            );
          } else {
            seenIds[id] = _IdSite(path, index);
          }
        }

        final question = parsed.question;
        if (parsed.isValid && question != null) {
          questions.add(question);
        }
      }
    }

    return QuestionBankValidation(
      assets: assets,
      questions: questions,
      violations: violations,
    );
  }
}

/// Questions and schema problems from one validation pass.
final class QuestionBankValidation {
  QuestionBankValidation({
    required this.assets,
    required List<TriviaQuestion> questions,
    required List<QuestionBankViolation> violations,
  }) : questions = List.unmodifiable(questions),
       violations = List.unmodifiable(violations);

  final QuestionAssets assets;
  final List<TriviaQuestion> questions;
  final List<QuestionBankViolation> violations;

  bool get isValid => violations.isEmpty;

  /// A bank, or null when [violations] is not empty.
  ///
  /// Never returns a partial bank. One bad question fails the load.
  QuestionBank? get bank {
    if (!isValid) {
      return null;
    }
    return QuestionBank(
      schemaVersion: assets.schemaVersion,
      questions: questions,
    );
  }
}

final class _IdSite {
  const _IdSite(this.path, this.index);

  final String path;
  final int index;
}
