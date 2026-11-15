/// Offline scripture question bank: model, loader, and schema checks.
///
/// The app reads `assets/questions/v1/` through [loadBundledQuestionBank].
/// `tool/validate_questions.dart` runs the same checks. That script must
/// import the pure loader files directly. This library also exports the
/// Flutter asset reader, so a plain Dart VM script cannot import it.
library;

export 'bundled_question_bank_loader.dart'
    show
        QuestionBankAssetException,
        loadBundledQuestionBank,
        questionBankRequiresApproval,
        readBundledQuestionAsset;
export 'question_assets.dart' show QuestionAssets;
export 'question_bank.dart' show QuestionBank;
export 'question_bank_exception.dart'
    show
        QuestionBankException,
        QuestionBankViolation,
        QuestionBankViolationKind;
export 'question_bank_loader.dart' show QuestionBankLoader;
export 'question_bank_validator.dart'
    show QuestionBankValidation, QuestionBankValidator;
export 'question_limits.dart' show QuestionLimits;
export 'review_status.dart' show ReviewStatus;
export 'scripture_volume.dart' show ScriptureVolume;
export 'trivia_question.dart' show ParsedTriviaQuestion, TriviaQuestion;
