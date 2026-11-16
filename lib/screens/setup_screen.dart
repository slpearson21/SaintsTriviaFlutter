import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../data/questions/scripture_volume.dart';
import '../layout/screen_body.dart';
import '../progress/home_snapshot.dart';
import '../routing/routes.dart';
import 'placeholder_scaffold.dart';

/// Stand-in until the volume picker chooses a selection. Ten questions
/// from every volume is the setup screen's default length.
const _placeholderSettings = LastGameSettings(
  volumes: [
    ScriptureVolume.ot,
    ScriptureVolume.nt,
    ScriptureVolume.bom,
    ScriptureVolume.dc,
    ScriptureVolume.pgp,
  ],
  questionCount: 10,
);

class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderScaffold(
      title: 'Game setup',
      primary: PrimaryButton(
        label: 'Start game',
        onPressed: () =>
            context.go(AppRoutes.game, extra: _placeholderSettings),
      ),
      body: Text(
        'Volume picker and question count will go here.',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    );
  }
}
