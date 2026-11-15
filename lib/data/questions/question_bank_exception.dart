/// Why a question bank could not be loaded.
///
/// The quiz UI should catch [QuestionBankException] and show
/// [QuestionBankException.userMessage] rather than treating these as crashes.
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

  /// `answerIndex` is missing, not an integer, or outside 0–3.
  answerIndex,

  /// An id prefix, volume code, and volume file do not agree.
  idVolumeMismatch,

  /// The same id appears more than once, including across volume files.
  duplicateId,

  /// A value has the wrong JSON type or is not one of the allowed codes.
  invalidValue,

  /// Release mode saw a question whose review status is not `approved`.
  notApproved,
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
/// it and show [userMessage]. [violations] is the detail for logs and CI.
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

  /// Sentence the UI can show when the bank cannot be loaded.
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
