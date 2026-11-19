import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens [uri] on the platform.
///
/// [mode] defaults to the platform default, which is what Settings uses.
/// Scripture links pass [LaunchMode.externalApplication] so iOS does not
/// keep the page in the in-app Safari view, which does not follow the
/// Gospel Library universal link.
typedef OpenLink = Future<bool> Function(Uri uri, {LaunchMode mode});

/// Sends `uri` to the platform. Tests override this.
final openLinkProvider = Provider<OpenLink>((ref) => openLink);

/// Whether the platform has an app that can open [uri].
///
/// Question reports check this before [openLink]. Tests override it to
/// force the mail and no-mail paths.
typedef CanOpenLink = Future<bool> Function(Uri uri);

/// Defaults to [canLaunchUrl]. Widget tests replace this.
final canOpenLinkProvider = Provider<CanOpenLink>((ref) => canLaunchUrl);

Future<bool> openLink(
  Uri uri, {
  LaunchMode mode = LaunchMode.platformDefault,
}) async {
  try {
    return await launchUrl(uri, mode: mode);
  } on Object {
    return false;
  }
}
