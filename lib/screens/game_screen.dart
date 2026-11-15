import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../layout/question_progress.dart';
import '../layout/screen_body.dart';
import '../layout/st_icon.dart';
import '../layout/text_scale.dart';
import '../routing/routes.dart';
import '../theme/st_theme.dart';
import 'placeholder_scaffold.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  bool _confirming = false;

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
    final target = minTapTarget(context);
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
            minimumSize: Size.square(target),
            tapTargetSize: MaterialTapTargetSize.padded,
          ),
          icon: const StIcon(Icons.close),
        ),
        primary: PrimaryButton(
          label: 'See results',
          onPressed: () => context.push(AppRoutes.results),
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
  final target = minTapTarget(context);
  final buttonStyle = TextButton.styleFrom(
    minimumSize: Size(target, target),
    tapTargetSize: MaterialTapTargetSize.padded,
  );
  final quit = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Quit game?'),
        content: const Text('Your progress in this game will be lost.'),
        actions: [
          TextButton(
            style: buttonStyle,
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep playing'),
          ),
          TextButton(
            style: buttonStyle,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Quit'),
          ),
        ],
      );
    },
  );
  return quit ?? false;
}
