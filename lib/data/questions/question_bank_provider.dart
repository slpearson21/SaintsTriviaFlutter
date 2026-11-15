import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bundled_question_bank_loader.dart';
import 'question_bank.dart';

/// How long the splash will wait for the bundled bank.
///
/// Five seconds, not three: a 3s cap misfires on slow, older Android phones.
/// Past this, the load is a failure and the content-load error state opens.
const Duration questionBankLoadTimeout = Duration(seconds: 5);

/// Reads the bundled bank. Tests substitute a fake.
typedef QuestionBankLoad = Future<QuestionBank> Function();

final questionBankLoaderProvider = Provider<QuestionBankLoad>(
  (ref) => loadBundledQuestionBank,
);

/// Timeout wrapped around [questionBankLoaderProvider].
///
/// The default is [questionBankLoadTimeout]. Tests shorten it.
final questionBankLoadTimeoutProvider = Provider<Duration>(
  (ref) => questionBankLoadTimeout,
);

/// The bundled question bank, loaded once per [ProviderContainer].
///
/// The splash wait is the production caller that starts this. Home does not
/// watch it. A later read receives the same future. Failure is terminal:
/// Riverpod's default retry would keep the splash up across several
/// attempts, and a bad bank should open the error state instead. Try again
/// invalidates this provider on purpose.
final questionBankProvider = FutureProvider<QuestionBank>((ref) {
  final load = ref.watch(questionBankLoaderProvider);
  final timeout = ref.watch(questionBankLoadTimeoutProvider);
  return load().timeout(timeout);
}, retry: _doNotRetryQuestionBank);

/// Stops the automatic retry. Null means "do not schedule another attempt".
Duration? _doNotRetryQuestionBank(int retryCount, Object error) => null;
