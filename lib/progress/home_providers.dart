import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'home_snapshot.dart';

/// Clock Home uses for "Today", "Yesterday", and short dates.
///
/// Tests override this. STRIV-16 can leave it alone.
typedef HomeClock = DateTime Function();

final homeClockProvider = Provider<HomeClock>((ref) => DateTime.now);

/// Stats snapshot and last-game settings for Home.
///
/// Defaults to [HomeSnapshot.firstRun]. STRIV-16 replaces the body with
/// a shared_preferences read and publishes [HomeSnapshot.firstRun] again
/// after reset stats. Home only watches the value, so that swap does not
/// change Home. This provider does not load the question bank.
final homeSnapshotProvider = Provider<HomeSnapshot>(
  (ref) => const HomeSnapshot.firstRun(),
);
