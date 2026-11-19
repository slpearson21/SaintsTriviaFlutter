import 'question_bank_exception.dart';
import 'question_limits.dart';
import 'review_status.dart';
import 'scripture_volume.dart';

/// One multiple-choice scripture question.
///
/// Instances are immutable. Build them with [TriviaQuestion.fromJson] or
/// [TriviaQuestion.parse] so malformed content becomes a
/// [QuestionBankException] instead of a later crash.
final class TriviaQuestion {
  TriviaQuestion({
    required this.id,
    required this.volume,
    required this.reference,
    required this.prompt,
    required List<String> options,
    required this.answerIndex,
    required this.explanation,
    required this.reviewStatus,
  }) : options = List.unmodifiable(List<String>.of(options)) {
    assert(
      options.length == QuestionLimits.optionCount,
      'options must contain exactly ${QuestionLimits.optionCount} choices',
    );
    assert(
      answerIndex >= QuestionLimits.minAnswerIndex &&
          answerIndex <= QuestionLimits.maxAnswerIndex,
      'answerIndex must be from 0 to 3',
    );
  }

  final String id;
  final ScriptureVolume volume;
  final String reference;
  final String prompt;
  final List<String> options;
  final int answerIndex;
  final String explanation;
  final ReviewStatus reviewStatus;

  /// The choice at [answerIndex].
  String get answer => options[answerIndex];

  /// Parses one JSON object.
  ///
  /// Throws [QuestionBankException] when the object breaks the schema.
  /// Duplicate ids are a bank-level rule and are checked by the question
  /// bank validator, not here.
  ///
  /// `requireApproved` stays false for every caller today. STRIV-19's release
  /// review gate may pass true.
  factory TriviaQuestion.fromJson(
    Object? json, {
    bool requireApproved = false,
    ScriptureVolume? expectedVolume,
    String? assetPath,
    int? index,
  }) {
    final parsed = TriviaQuestion.parse(
      json,
      requireApproved: requireApproved,
      expectedVolume: expectedVolume,
      assetPath: assetPath,
      index: index,
    );
    if (!parsed.isValid) {
      throw QuestionBankException(parsed.violations);
    }
    return parsed.question!;
  }

  /// Parses one JSON object and reports every field problem it can find.
  ///
  /// `requireApproved` stays false for every caller today. STRIV-19's release
  /// review gate may pass true.
  static ParsedTriviaQuestion parse(
    Object? json, {
    bool requireApproved = false,
    ScriptureVolume? expectedVolume,
    String? assetPath,
    int? index,
  }) {
    return _parseTriviaQuestion(
      json,
      requireApproved: requireApproved,
      expectedVolume: expectedVolume,
      assetPath: assetPath,
      index: index,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is TriviaQuestion &&
        other.id == id &&
        other.volume == volume &&
        other.reference == reference &&
        other.prompt == prompt &&
        _sameStrings(other.options, options) &&
        other.answerIndex == answerIndex &&
        other.explanation == explanation &&
        other.reviewStatus == reviewStatus;
  }

  @override
  int get hashCode => Object.hash(
    id,
    volume,
    reference,
    prompt,
    Object.hashAll(options),
    answerIndex,
    explanation,
    reviewStatus,
  );

  @override
  String toString() => 'TriviaQuestion($id, ${volume.code}, $reference)';
}

/// Result of parsing a single question object.
final class ParsedTriviaQuestion {
  const ParsedTriviaQuestion({
    required this.violations,
    this.question,
    this.id,
  });

  final List<QuestionBankViolation> violations;
  final TriviaQuestion? question;

  /// Non-empty string id, even when other fields are invalid.
  ///
  /// The bank validator uses this to detect duplicate ids on broken objects.
  final String? id;

  bool get isValid => question != null && violations.isEmpty;
}

bool _sameStrings(List<String> left, List<String> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) {
      return false;
    }
  }
  return true;
}

const Set<String> _questionFields = {
  'id',
  'volume',
  'reference',
  'prompt',
  'options',
  'answerIndex',
  'explanation',
  'reviewStatus',
};

ParsedTriviaQuestion _parseTriviaQuestion(
  Object? json, {
  required bool requireApproved,
  required ScriptureVolume? expectedVolume,
  required String? assetPath,
  required int? index,
}) {
  final violations = <QuestionBankViolation>[];
  String? trackId;

  void add(
    QuestionBankViolationKind kind,
    String message, {
    String? field,
    String? questionId,
  }) {
    violations.add(
      QuestionBankViolation(
        kind: kind,
        message: message,
        assetPath: assetPath,
        index: index,
        field: field,
        questionId: questionId ?? trackId,
      ),
    );
  }

  final map = _stringKeyMap(json);
  if (map == null) {
    add(
      QuestionBankViolationKind.invalidShape,
      'A question must be a JSON object.',
    );
    return ParsedTriviaQuestion(violations: List.unmodifiable(violations));
  }

  final unknownKeys =
      map.keys.where((key) => !_questionFields.contains(key)).toList()..sort();
  for (final key in unknownKeys) {
    add(
      QuestionBankViolationKind.unknownField,
      'Unknown field "$key".',
      field: key,
    );
  }

  final id = _readText(map, 'id', add);
  if (id != null) {
    trackId = id;
    if (ScriptureVolume.volumeForId(id) == null) {
      add(
        QuestionBankViolationKind.invalidValue,
        'Id "$id" must look like ot-0001, nt-0001, bom-0001, dc-0001, or pgp-0001.',
        field: 'id',
        questionId: id,
      );
    }
  }

  // Stamp the id onto problems found before it was known (unknown keys).
  if (trackId != null) {
    for (var i = 0; i < violations.length; i++) {
      final violation = violations[i];
      if (violation.questionId == null) {
        violations[i] = QuestionBankViolation(
          kind: violation.kind,
          message: violation.message,
          assetPath: violation.assetPath,
          questionId: trackId,
          index: violation.index,
          field: violation.field,
        );
      }
    }
  }

  final volume = _readVolume(map, add);
  final reference = _readText(map, 'reference', add);
  final prompt = _readText(
    map,
    'prompt',
    add,
    maxLength: QuestionLimits.promptMaxLength,
  );
  final explanation = _readText(
    map,
    'explanation',
    add,
    maxLength: QuestionLimits.explanationMaxLength,
    oneLine: true,
  );
  final options = _readOptions(map, add);
  final answerIndex = _readAnswerIndex(map, add);
  final reviewStatus = _readReviewStatus(
    map,
    add,
    requireApproved: requireApproved,
    questionId: trackId,
  );

  _checkIdVolumeAgreement(
    id: id,
    volume: volume,
    expectedVolume: expectedVolume,
    assetPath: assetPath,
    add: add,
  );

  if (violations.isNotEmpty ||
      id == null ||
      volume == null ||
      reference == null ||
      prompt == null ||
      explanation == null ||
      options == null ||
      answerIndex == null ||
      reviewStatus == null) {
    return ParsedTriviaQuestion(
      violations: List.unmodifiable(violations),
      id: trackId,
    );
  }

  return ParsedTriviaQuestion(
    violations: const [],
    id: id,
    question: TriviaQuestion(
      id: id,
      volume: volume,
      reference: reference,
      prompt: prompt,
      options: options,
      answerIndex: answerIndex,
      explanation: explanation,
      reviewStatus: reviewStatus,
    ),
  );
}

Map<String, Object?>? _stringKeyMap(Object? json) {
  if (json is! Map) {
    return null;
  }
  final map = <String, Object?>{};
  for (final key in json.keys) {
    if (key is! String) {
      return null;
    }
    map[key] = json[key];
  }
  return map;
}

typedef _AddViolation = void Function(
  QuestionBankViolationKind kind,
  String message, {
  String? field,
  String? questionId,
});

String? _readText(
  Map<String, Object?> json,
  String field,
  _AddViolation add, {
  int? maxLength,
  bool oneLine = false,
}) {
  if (!json.containsKey(field)) {
    add(
      QuestionBankViolationKind.missingField,
      'Missing field "$field".',
      field: field,
    );
    return null;
  }
  final value = json[field];
  if (value is! String) {
    add(
      QuestionBankViolationKind.invalidValue,
      'Field "$field" must be a string.',
      field: field,
    );
    return null;
  }
  if (value.trim().isEmpty) {
    add(
      QuestionBankViolationKind.emptyField,
      'Field "$field" must not be empty.',
      field: field,
    );
    return null;
  }
  var ok = true;
  if (oneLine && (value.contains('\n') || value.contains('\r'))) {
    add(
      QuestionBankViolationKind.multilineField,
      'Field "$field" must be a single line.',
      field: field,
    );
    ok = false;
  }
  if (maxLength != null && value.length > maxLength) {
    add(
      QuestionBankViolationKind.overLength,
      'Field "$field" is ${value.length} characters; the maximum is $maxLength.',
      field: field,
    );
    ok = false;
  }
  return ok ? value : null;
}

ScriptureVolume? _readVolume(Map<String, Object?> json, _AddViolation add) {
  final code = _readText(json, 'volume', add);
  if (code == null) {
    return null;
  }
  final volume = ScriptureVolume.tryParse(code);
  if (volume == null) {
    add(
      QuestionBankViolationKind.invalidValue,
      'Volume "$code" must be OT, NT, BOM, DC, or PGP.',
      field: 'volume',
    );
    return null;
  }
  return volume;
}

List<String>? _readOptions(Map<String, Object?> json, _AddViolation add) {
  if (!json.containsKey('options')) {
    add(
      QuestionBankViolationKind.missingField,
      'Missing field "options".',
      field: 'options',
    );
    return null;
  }
  final value = json['options'];
  if (value is! List) {
    add(
      QuestionBankViolationKind.invalidShape,
      'Field "options" must be a list of ${QuestionLimits.optionCount} strings.',
      field: 'options',
    );
    return null;
  }
  if (value.length != QuestionLimits.optionCount) {
    add(
      QuestionBankViolationKind.optionCount,
      'Field "options" must contain exactly ${QuestionLimits.optionCount} '
      'choices; found ${value.length}.',
      field: 'options',
    );
    return null;
  }

  final options = <String>[];
  var ok = true;
  for (var i = 0; i < value.length; i++) {
    final option = value[i];
    if (option is! String) {
      add(
        QuestionBankViolationKind.invalidValue,
        'Option ${i + 1} must be a string.',
        field: 'options',
      );
      ok = false;
      continue;
    }
    if (option.trim().isEmpty) {
      add(
        QuestionBankViolationKind.emptyField,
        'Option ${i + 1} must not be empty.',
        field: 'options',
      );
      ok = false;
      continue;
    }
    options.add(option);
  }
  if (!ok) {
    return null;
  }

  final seen = <String>{};
  for (final option in options) {
    final folded = option.trim().toLowerCase();
    if (!seen.add(folded)) {
      add(
        QuestionBankViolationKind.duplicateOption,
        'Options must be distinct after trimming and case-folding. '
        '"$option" repeats.',
        field: 'options',
      );
      return null;
    }
  }
  return options;
}

int? _readAnswerIndex(Map<String, Object?> json, _AddViolation add) {
  if (!json.containsKey('answerIndex')) {
    add(
      QuestionBankViolationKind.missingField,
      'Missing field "answerIndex".',
      field: 'answerIndex',
    );
    return null;
  }
  final value = json['answerIndex'];
  if (value is! int ||
      value < QuestionLimits.minAnswerIndex ||
      value > QuestionLimits.maxAnswerIndex) {
    add(
      QuestionBankViolationKind.answerIndex,
      'answerIndex must be an integer from 0 to 3.',
      field: 'answerIndex',
    );
    return null;
  }
  return value;
}

ReviewStatus? _readReviewStatus(
  Map<String, Object?> json,
  _AddViolation add, {
  required bool requireApproved,
  required String? questionId,
}) {
  if (!json.containsKey('reviewStatus')) {
    add(
      QuestionBankViolationKind.missingField,
      'Missing field "reviewStatus".',
      field: 'reviewStatus',
    );
    return null;
  }
  final value = json['reviewStatus'];
  if (value is! String) {
    add(
      QuestionBankViolationKind.invalidValue,
      'Field "reviewStatus" must be a string.',
      field: 'reviewStatus',
    );
    return null;
  }
  final status = ReviewStatus.tryParse(value);
  if (status == null) {
    add(
      QuestionBankViolationKind.invalidValue,
      'reviewStatus "$value" must be "draft" or "approved".',
      field: 'reviewStatus',
    );
    return null;
  }
  // Nothing passes true today. Kept because STRIV-19's release review
  // gate may need it.
  if (requireApproved && status != ReviewStatus.approved) {
    final label = questionId == null ? 'A question' : 'Question $questionId';
    add(
      QuestionBankViolationKind.notApproved,
      '$label is "$value". The release validator only allows approved questions.',
      field: 'reviewStatus',
      questionId: questionId,
    );
    return null;
  }
  return status;
}

void _checkIdVolumeAgreement({
  required String? id,
  required ScriptureVolume? volume,
  required ScriptureVolume? expectedVolume,
  required String? assetPath,
  required _AddViolation add,
}) {
  final idVolume = id == null ? null : ScriptureVolume.volumeForId(id);
  final location = assetPath ?? 'the volume file';
  if (idVolume != null && volume != null && idVolume != volume) {
    add(
      QuestionBankViolationKind.idVolumeMismatch,
      'Id "$id" has prefix "${idVolume.idPrefix}" but volume is ${volume.code}.',
      field: 'id',
    );
  } else if (idVolume != null &&
      volume == null &&
      expectedVolume != null &&
      idVolume != expectedVolume) {
    add(
      QuestionBankViolationKind.idVolumeMismatch,
      'Id "$id" belongs to ${idVolume.code} but $location is the '
      '${expectedVolume.code} file.',
      field: 'id',
    );
  }
  if (volume != null && expectedVolume != null && volume != expectedVolume) {
    add(
      QuestionBankViolationKind.idVolumeMismatch,
      'Volume is ${volume.code} but $location is the ${expectedVolume.code} file.',
      field: 'volume',
    );
  }
}
