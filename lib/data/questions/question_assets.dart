import 'scripture_volume.dart';

/// Where a schema version of the question bank lives.
///
/// v1 files are JSON arrays of questions, copied unchanged from the source
/// bank. The version is the directory (`assets/questions/v1`), not a field
/// inside the array.
final class QuestionAssets {
  const QuestionAssets({
    this.schemaVersion = currentSchemaVersion,
    this.directory = v1Directory,
  });

  static const int currentSchemaVersion = 1;
  static const String v1Directory = 'assets/questions/v1';

  /// The bank bundled with the app.
  static const QuestionAssets v1 = QuestionAssets();

  final int schemaVersion;
  final String directory;

  String pathFor(ScriptureVolume volume) {
    final root = directory.endsWith('/')
        ? directory.substring(0, directory.length - 1)
        : directory;
    return '$root/${volume.fileName}';
  }
}
