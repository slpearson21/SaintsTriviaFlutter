import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../data/questions/question_bank.dart';
import '../data/questions/question_bank_provider.dart';
import '../game/game_engine.dart';
import '../game/game_providers.dart';
import '../routing/routes.dart';
import 'home_snapshot.dart';

/// Opens setup with [settings] attached as go_router `extra`.
///
/// Home's Play again, and Results' New game, land on setup. That is the
/// screen-inventory path. Starting the dealt game — Results' Play again,
/// or a restored `/game` — goes through the game route. That route reads
/// [LastGameSettings] from `extra` only when `extra` is one, and otherwise
/// uses the last settings on the home snapshot.
void openPlayAgain(BuildContext context, LastGameSettings settings) {
  context.go(AppRoutes.setup, extra: settings);
}

/// Settings to prefill setup, or to deal the same game again.
///
/// [GameSession.requestedCount] is what the player asked for, before the
/// cap. A stored 0 falls back to the dealt length so [LastGameSettings]
/// still has a question count.
LastGameSettings lastSettingsFor(GameSession session) {
  final requested = session.requestedCount;
  final count = requested > 0 ? requested : session.questionCount;
  return LastGameSettings(volumes: session.volumes, questionCount: count);
}

/// Deals a new session, then opens `/game`.
///
/// The deal runs before navigation. A finished game does not match the
/// game route, so opening `/game` first would deal again and could flash
/// the game that just ended. Starting first leaves an in-progress session
/// with these settings, which that route keeps instead of dealing twice.
/// When the bank is already loaded this is synchronous, which puts the
/// new session in place before the route changes. A bank that cannot be
/// read leaves the finished session where it is.
Future<void> dealAndPlayAgain(
  WidgetRef ref,
  BuildContext context,
  GameSession session,
) async {
  final QuestionBank bank;
  final ready = ref.read(questionBankProvider).asData?.value;
  if (ready != null) {
    bank = ready;
  } else {
    try {
      bank = await ref.read(questionBankProvider.future);
    } on Object {
      return;
    }
    if (!context.mounted) return;
  }
  // The route extra and the deal use the same count. A stored 0 falls
  // back to the dealt length here; passing that 0 into start would miss
  // the game route's settings match and deal a second game.
  final settings = lastSettingsFor(session);
  ref
      .read(gameControllerProvider.notifier)
      .start(
        bank: bank,
        volumes: settings.volumes,
        requestedCount: settings.questionCount,
      );
  if (!context.mounted) return;
  context.go(AppRoutes.game, extra: settings);
}
