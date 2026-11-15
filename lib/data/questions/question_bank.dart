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

  /// True when this load produced no playable questions.
  ///
  /// A release build can return an empty bank after skipping drafts. That is
  /// a successful load. Game setup should use [availableVolumes] and
  /// [forVolume], and the quiz can show "no questions for this selection"
  /// when the chosen volumes are empty.
  bool get isEmpty => questions.isEmpty;

  /// Volumes that have at least one question, in OT, NT, BOM, DC, PGP order.
  List<ScriptureVolume> get availableVolumes {
    return List.unmodifiable([
      for (final volume in ScriptureVolume.values)
        if (hasQuestionsFor(volume)) volume,
    ]);
  }

  /// Whether [volume] has a question the game can ask.
  bool hasQuestionsFor(ScriptureVolume volume) {
    for (final question in questions) {
      if (question.volume == volume) {
        return true;
      }
    }
    return false;
  }

  /// Questions for [volume], or an empty list when that volume has none.
  List<TriviaQuestion> forVolume(ScriptureVolume volume) {
    return List.unmodifiable([
      for (final question in questions)
        if (question.volume == volume) question,
    ]);
  }
}
