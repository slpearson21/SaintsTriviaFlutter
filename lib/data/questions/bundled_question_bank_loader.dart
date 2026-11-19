import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'question_assets.dart';
import 'question_bank.dart';
import 'question_bank_loader.dart';

/// Whether this load should omit questions that are not approved.
///
/// Release builds skip them. Debug and profile builds keep drafts, so the
/// full bank is available while doctrinal review is still open and while
/// profiling. Pass [skipUnapproved] to override that.
bool skipUnapprovedQuestions({bool? skipUnapproved}) {
  return skipUnapproved ?? kReleaseMode;
}

/// Reads the bundled question bank offline and returns it.
///
/// Uses [rootBundle] and does not use the network. A schema problem throws
/// `QuestionBankException`; the app shows the E1 error state, and
/// `QuestionBankException.userMessage` is the log line. Release
/// builds omit questions that are not approved. An empty bank, or an empty
/// volume, is a successful load: use [QuestionBank.availableVolumes] and
/// [QuestionBank.forVolume] for the "no questions for this selection" state.
Future<QuestionBank> loadBundledQuestionBank({
  bool? skipUnapproved,
  QuestionAssets assets = QuestionAssets.v1,
}) {
  return QuestionBankLoader(
    read: readBundledQuestionAsset,
    assets: assets,
    skipUnapproved: skipUnapprovedQuestions(skipUnapproved: skipUnapproved),
  ).load();
}

/// Reads one bundled asset, converting a missing-asset [FlutterError] into
/// an [Exception] the loader can report as a typed content failure.
Future<String> readBundledQuestionAsset(String path) async {
  try {
    return await rootBundle.loadString(path);
  } on FlutterError catch (error) {
    throw QuestionBankAssetException(path, error);
  }
}

/// [rootBundle] could not read a question asset.
final class QuestionBankAssetException implements Exception {
  QuestionBankAssetException(this.path, this.cause);

  final String path;
  final Object cause;

  @override
  String toString() => 'Could not read asset $path: $cause';
}
