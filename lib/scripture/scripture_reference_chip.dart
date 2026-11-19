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
class ScriptureReferenceChip extends ConsumerStatefulWidget {
  const ScriptureReferenceChip({
    super.key,
    required this.reference,
    required this.background,
    required this.foreground,
    this.borderRadius = const BorderRadius.all(StRadius.sm),
    this.leading,
  }) : providedLink = null,
       hasProvidedLink = false;

  /// [link] is the already-parsed Gospel Library URL, including null when
  /// [reference] does not parse. The chip does not parse again.
  const ScriptureReferenceChip.fromLink({
    super.key,
    required this.reference,
    required Uri? link,
    required this.background,
    required this.foreground,
    this.borderRadius = const BorderRadius.all(StRadius.sm),
    this.leading,
  }) : providedLink = link,
       hasProvidedLink = true;

  final String reference;
  final Color background;
  final Color foreground;
  final BorderRadius borderRadius;
  final Widget? leading;
  final Uri? providedLink;
  final bool hasProvidedLink;

  @override
  ConsumerState<ScriptureReferenceChip> createState() =>
      _ScriptureReferenceChipState();
}

class _ScriptureReferenceChipState
    extends ConsumerState<ScriptureReferenceChip> {
  /// True while a launch is waiting on the platform, so a second tap
  /// does not open Gospel Library again.
  var _opening = false;

  @override
  Widget build(BuildContext context) {
    final reference = widget.reference;
    final link = widget.hasProvidedLink
        ? widget.providedLink
        : gospelLibraryUri(reference);
    final labelStyle = Theme.of(context).textTheme.labelLarge
        ?.copyWith(color: widget.foreground);
    final face = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.leading != null) ...[
          widget.leading!,
          const SizedBox(width: StSpace.xxs),
        ],
        Flexible(child: Text(reference, softWrap: true, style: labelStyle)),
        if (link != null) ...[
          const SizedBox(width: StSpace.xxs),
          StIcon(Icons.open_in_new, size: 18, color: widget.foreground),
        ],
      ],
    );

    if (link == null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: widget.background,
          borderRadius: widget.borderRadius,
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
      onTap: () => _open(link),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: StSpace.minTap,
            minHeight: StSpace.minTap,
          ),
          child: Material(
            color: widget.background,
            borderRadius: widget.borderRadius,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _open(link),
              borderRadius: widget.borderRadius,
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
      ),
    );
  }

  Future<void> _open(Uri uri) async {
    if (_opening) return;
    _opening = true;
    try {
      final opened = await ref.read(openLinkProvider)(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!mounted || opened) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(couldNotOpenGospelLibraryMessage)),
      );
    } finally {
      _opening = false;
    }
  }
}
