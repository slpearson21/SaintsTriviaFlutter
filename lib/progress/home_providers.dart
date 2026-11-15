import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'home_snapshot.dart';

/// Clock Home uses for "Today", "Yesterday", and short dates.
///
/// Tests override this. STRIV-16 can leave it alone.
typedef HomeClock = DateTime Function();

final homeClockProvider = Provider<HomeClock>((ref) => DateTime.now);

/// Seam for the progress snapshot and last-game settings Home displays.
///
/// The value defaults to an in-memory [HomeSnapshot.firstRun]. STRIV-16
/// replaces this body with the shared_preferences record: read it here,
/// and publish [HomeSnapshot.firstRun] again after reset stats clears
/// that record. Home only watches the value, so the persisted
/// implementation does not change Home. This provider does not load the
/// question bank.
final homeSnapshotProvider = Provider<HomeSnapshot>(
  (ref) => const HomeSnapshot.firstRun(),
);
