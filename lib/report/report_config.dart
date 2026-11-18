/// Inbox for question reports and the Settings feedback row.
///
/// TODO(STRIV-19): replace the placeholder before a store build.
/// `flutter test` always sees `kReleaseMode == false`, so the release
/// workflow is where this address has to be rejected.
const kReportEmail = 'reports@example.com';

/// Shown under About. Sending a report opens the player's own mail app.
const reportPrivacyLine =
    'Sending a report opens your email app and shares your email address with us.';
