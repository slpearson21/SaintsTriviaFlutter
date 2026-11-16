import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../data/questions/question_bank.dart';
import '../data/questions/question_bank_provider.dart';
import '../game/game_engine.dart';
import '../game/game_providers.dart';
import '../layout/question_progress.dart';
import '../layout/screen_body.dart';
import '../layout/st_icon.dart';
import '../progress/home_snapshot.dart';
import '../routing/routes.dart';
import '../theme/st_theme.dart';
import 'placeholder_scaffold.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key, this.settings});

  /// Resolved by the game route. Null only if the route is built without
  /// going through that redirect.
  final LastGameSettings? settings;

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  bool _confirming = false;
  ProviderSubscription<AsyncValue<QuestionBank>>? _bankSubscription;

  @override
  void initState() {
    super.initState();
    // The splash starts the bank load. A restore can mount this screen
    // while that future is still running. Listen only when the load has
    // already started, so this screen deals when it arrives and does not
    // open a second load of its own.
    if (ref.read(questionBankProvider.exists)) {
      _bankSubscription = ref.listenManual(questionBankProvider, (
        previous,
        next,
      ) {
        if (!next.hasValue) return;
        _dealIfNeeded();
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _dealIfNeeded());
  }

  @override
  void dispose() {
    _bankSubscription?.close();
    super.dispose();
  }

  /// Deals only when the current session is not already this screen's game.
  ///
  /// Setup calls [GameController.start] before it opens `/game`, so the first
  /// frame here is the new deal. Dealing again would shuffle a second game
  /// and, if it happened a frame later, flash the finished one.
  void _dealIfNeeded() {
    if (!mounted) return;
    final settings = widget.settings;
    if (settings == null) return;
    final current = ref.read(gameControllerProvider);
    if (current != null && _sessionMatches(current, settings)) {
      _redirectIfEmpty(current);
      return;
    }
    // Reading the provider when it does not exist starts the 5s load.
    // The splash is what starts it. This screen only deals a bank that
    // is already loading or already loaded.
    if (!ref.read(questionBankProvider.exists)) return;
    final bank = ref.read(questionBankProvider).asData?.value;
    if (bank == null) return;
    ref
        .read(gameControllerProvider.notifier)
        .start(
          bank: bank,
          volumes: settings.volumes,
          requestedCount: settings.questionCount,
        );
    final dealt = ref.read(gameControllerProvider);
    if (dealt != null) _redirectIfEmpty(dealt);
  }

  /// A restore can deal zero questions. Send that back to setup so the
  /// question screen never shows a 0/0 game.
  void _redirectIfEmpty(GameSession session) {
    if (session.questions.isNotEmpty || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final current = ref.read(gameControllerProvider);
      if (current == null || current.questions.isNotEmpty) return;
      context.go(AppRoutes.setup);
    });
  }

  Future<void> _requestQuit() async {
    if (_confirming || !mounted) {
      return;
    }
    _confirming = true;
    final quit = await showQuitGameDialog(context);
    _confirming = false;
    if (!mounted) {
      return;
    }
    if (quit) {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(gameControllerProvider);
    final settings = widget.settings;
    final matches =
        session != null &&
        settings != null &&
        _sessionMatches(session, settings);
    // A finished game stays in the controller until the next deal. Hide it
    // until this route's settings are the ones on screen. An empty deal is
    // hidden too, while the redirect back to setup runs.
    final hideStale = session != null && settings != null && !matches;
    final hideEmpty = session != null && matches && session.questions.isEmpty;
    if (hideStale || hideEmpty) {
      return const SizedBox.shrink();
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        unawaited(_requestQuit());
      },
      child: PlaceholderScaffold(
        title: 'Question',
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Close',
          onPressed: _requestQuit,
          style: IconButton.styleFrom(
            minimumSize: const Size.square(StSpace.minTap),
            tapTargetSize: MaterialTapTargetSize.padded,
          ),
          icon: const StIcon(Icons.close),
        ),
        primary: PrimaryButton(
          label: 'See results',
          onPressed: () => context.go(AppRoutes.results),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const QuestionProgress(current: 7, total: 10),
            const SizedBox(height: StSpace.md),
            Text(
              'Question and answers will go here.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool> showQuitGameDialog(BuildContext context) async {
  final quit = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Quit game?'),
        content: const Text('Your progress in this game will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep playing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Quit'),
          ),
        ],
      );
    },
  );
  return quit ?? false;
}

/// True when [session] was dealt for [settings], in any volume order.
///
/// [GameSession.requestedCount] is the count passed to [GameController.start],
/// which setup and this screen both set from [LastGameSettings.questionCount].
bool _sessionMatches(GameSession session, LastGameSettings settings) {
  if (session.requestedCount != settings.questionCount) return false;
  if (session.volumes.length != settings.volumes.length) return false;
  final dealt = session.volumes.toSet();
  for (final volume in settings.volumes) {
    if (!dealt.contains(volume)) return false;
  }
  return true;
}
