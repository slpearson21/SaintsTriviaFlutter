import 'scripture_volume.dart';
import 'trivia_question.dart';

/// Immutable snapshot of every question the loader accepted.
final class QuestionBank {
  QuestionBank({
    required this.schemaVersion,
    required List<TriviaQuestion> questions,
  }) : questions = List.unmodifiable(questions);

  /// Schema version of the files this bank was read from. v1 is `1`.
  final int schemaVersion;

  /// Questions in volume order (OT, NT, BOM, DC, PGP), preserving file order
  /// inside each volume.
  final List<TriviaQuestion> questions;

  int get length => questions.length;

  List<TriviaQuestion> forVolume(ScriptureVolume volume) {
    return List.unmodifiable([
      for (final question in questions)
        if (question.volume == volume) question,
    ]);
  }
}
