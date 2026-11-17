/// Why a question bank could not be loaded.
///
/// The quiz UI should catch [QuestionBankException] and show the E1 error
/// state rather than treating these as crashes. [QuestionBankException.userMessage]
/// stays on the exception for logs.
enum QuestionBankViolationKind {
  /// The asset could not be read.
  missingAsset,

  /// The file is not valid JSON.
  malformedJson,

  /// JSON parsed, but it is not a non-empty array of question objects.
  invalidShape,

  /// A required field is absent.
  missingField,

  /// A key is not part of the v1 schema.
  unknownField,

  /// A text field is empty or only whitespace.
  emptyField,

  /// A text field is longer than its limit.
  overLength,

  /// `explanation` contains a line break.
  multilineField,

  /// `options` is a list of a length other than 4.
  optionCount,

  /// Two options match after trimming and case-folding.
  duplicateOption,

  /// `answerIndex` is missing, not an integer, or outside 0–3.
  answerIndex,

  /// An id prefix, volume code, and volume file do not agree.
  idVolumeMismatch,

  /// The same id appears more than once, including across volume files.
  duplicateId,

  /// A value has the wrong JSON type or is not one of the allowed codes.
  invalidValue,

  /// The release validator saw a question that is not `approved`.
  ///
  /// The in-app loader does not emit this. A release build skips those
  /// questions instead of failing.
  notApproved,

  /// The bundled bank has fewer than 100 questions in a volume.
  ///
  /// `tool/validate_questions.dart` emits this for `assets/questions/v1/`
  /// only. With `--require-approved` the count is approved questions. The
  /// in-app loader does not emit this, and fixture banks are not checked.
  tooFewQuestions,
}

/// One schema problem. A load collects every violation it can.
final class QuestionBankViolation {
  const QuestionBankViolation({
    required this.kind,
    required this.message,
    this.assetPath,
    this.questionId,
    this.index,
    this.field,
  });

  final QuestionBankViolationKind kind;
  final String message;

  /// Asset path the problem came from, when it belongs to a file.
  final String? assetPath;

  /// Question id, when the object had a non-empty string id.
  final String? questionId;

  /// Zero-based index of the question in its volume file.
  final int? index;

  /// JSON field name, when the problem is a single field.
  final String? field;

  @override
  String toString() {
    final details = <String>[
      ?assetPath,
      if (index != null) 'index $index',
      if (questionId != null) 'id $questionId',
      if (field != null) 'field $field',
    ];
    final where = details.isEmpty ? '' : ' (${details.join(', ')})';
    return '${kind.name}: $message$where';
  }
}

/// Typed failure for a question bank that cannot be shown.
///
/// Throwing this is the "content failed to load" state. Callers should catch
/// it and show the E1 error state. [userMessage] and [violations] are for logs.
final class QuestionBankException implements Exception {
  QuestionBankException(List<QuestionBankViolation> violations)
    : violations = List.unmodifiable(violations) {
    if (violations.isEmpty) {
      throw ArgumentError.value(
        violations,
        'violations',
        'must describe at least one problem',
      );
    }
  }

  /// Short sentence for logs. The screen shows the E1 copy instead.
  static const String userMessage = 'Content failed to load.';

  final List<QuestionBankViolation> violations;

  @override
  String toString() {
    final lines = violations
        .map((violation) => violation.toString())
        .join('\n');
    return 'QuestionBankException: $userMessage\n$lines';
  }
}
