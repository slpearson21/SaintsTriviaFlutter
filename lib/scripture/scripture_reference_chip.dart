import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../layout/st_icon.dart';
import '../services/open_link.dart';
import '../theme/st_theme.dart';
import 'scripture_link.dart';

/// Shown when the platform reports that nothing opened the link.
const couldNotOpenGospelLibraryMessage = "Couldn't open Gospel Library.";

/// The reference under an answer. A parsed reference opens Gospel Library.
/// Anything else stays plain text.
class ScriptureReferenceChip extends ConsumerWidget {
  const ScriptureReferenceChip({
    super.key,
    required this.reference,
    required this.background,
    required this.foreground,
    this.borderRadius = const BorderRadius.all(StRadius.sm),
    this.leading,
  });

  final String reference;
  final Color background;
  final Color foreground;
  final BorderRadius borderRadius;
  final Widget? leading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final link = gospelLibraryUri(reference);
    final labelStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
      color: foreground,
    );
    final face = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (leading != null) ...[
          leading!,
          const SizedBox(width: StSpace.xxs),
        ],
        Flexible(
          child: Text(reference, softWrap: true, style: labelStyle),
        ),
        if (link != null) ...[
          const SizedBox(width: StSpace.xxs),
          StIcon(Icons.open_in_new, size: 18, color: foreground),
        ],
      ],
    );

    if (link == null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: borderRadius,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: StSpace.sm,
            vertical: StSpace.xxs,
          ),
          child: face,
        ),
      );
    }

    return Semantics(
      container: true,
      link: true,
      button: false,
      label: 'Open $reference in Gospel Library',
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : double.infinity;
          return Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: StSpace.minTap,
                minHeight: StSpace.minTap,
                maxWidth: maxWidth,
              ),
              child: Material(
                color: background,
                borderRadius: borderRadius,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _open(context, ref, link),
                  borderRadius: borderRadius,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: StSpace.sm,
                      vertical: StSpace.xs,
                    ),
                    child: face,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref, Uri uri) async {
    final opened = await ref.read(openLinkProvider)(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!context.mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(couldNotOpenGospelLibraryMessage)),
    );
  }
}
