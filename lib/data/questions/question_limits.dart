/// Limits from the v1 question schema.
///
/// Lengths are [String.length] (UTF-16 code units). The English bank, including
/// the em dash in Joseph Smith—Matthew, is inside the basic multilingual plane,
/// so that matches a character count.
abstract final class QuestionLimits {
  static const int promptMaxLength = 140;
  static const int explanationMaxLength = 160;
  static const int optionCount = 4;
  static const int minAnswerIndex = 0;
  static const int maxAnswerIndex = 3;
}
