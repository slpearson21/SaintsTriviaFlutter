import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../data/questions/question_bank_provider.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _dealIfBankReady());
  }

  /// Deals from the bank the splash already loaded.
  ///
  /// Reading [questionBankProvider] only when it [exists] keeps this screen
  /// from starting a second load. Home never reads the bank either.
  void _dealIfBankReady() {
    if (!mounted) return;
    final settings = widget.settings;
    if (settings == null) return;
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
