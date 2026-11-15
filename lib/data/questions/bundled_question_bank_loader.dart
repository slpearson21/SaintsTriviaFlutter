import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'question_assets.dart';
import 'question_bank_loader.dart';

/// Whether this load should reject questions that are not approved.
///
/// Release builds require approval. Debug and profile builds do not, so the
/// draft bank can be used while doctrinal review is still open. Pass
/// [requireApproved] to override that.
bool questionBankRequiresApproval({bool? requireApproved}) {
  return requireApproved ?? kReleaseMode;
}

/// Offline loader for the question JSON bundled in the app.
///
/// Uses [rootBundle] and does not use the network. Catch
/// `QuestionBankException` and show `QuestionBankException.userMessage`.
QuestionBankLoader loadBundledQuestionBank({
  bool? requireApproved,
  QuestionAssets assets = const QuestionAssets(),
}) {
  return QuestionBankLoader(
    read: readBundledQuestionAsset,
    assets: assets,
    requireApproved: questionBankRequiresApproval(
      requireApproved: requireApproved,
    ),
  );
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
