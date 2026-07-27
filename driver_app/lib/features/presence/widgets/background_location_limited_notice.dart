import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import '../presence_builder.dart';

/// The designed reduced-state for seam **#85** — Android background location
/// (`SeamKind.device`).
///
/// 🔴 THIS IS THE HONESTY RULE APPLIED TO A DEVICE CAPABILITY, AND IT IS THE
/// HARDEST ONE IN THE MILESTONE TO GET RIGHT, because the driver in this state
/// **is not broken**. They granted location. They tapped GO. The server has them
/// in the pool. Offers arrive. Everything the app shows them is working.
///
/// And the moment they lock their phone — which every driver does, constantly —
/// Android stops delivering fixes, the 20-second heartbeat starves, and the
/// admin drops them from the dispatch pool five minutes later. They sit in a
/// layby for an hour watching a green ONLINE badge, earning nothing, and blaming
/// us. That is the whole failure, and the app is the only thing that can see it
/// coming.
///
/// **A confident ONLINE badge over a driver whose location dies at the lock
/// screen is the same class of lie as a fabricated payment card.** It tells them
/// they are earning when they are not. So this rung:
///
///  1. states the CONSEQUENCE first, in the driver's own terms — *keep the app
///     open* — not "background location permission is not granted", which is a
///     sentence about Android, not about their evening's takings;
///  2. is precise about what still WORKS (they are dispatchable right now — they
///     must not be scared into thinking they cannot drive);
///  3. gives a REAL forward exit. On Android 11+ the OS will not show a dialog
///     for "Allow all the time" AT ALL — the only route is the Settings app, so
///     that is where the action goes.
///
/// It is a `notice`, not an `error`: this driver is working. An error banner
/// would be its own small dishonesty in the other direction.
class BackgroundLocationLimitedNotice extends ConsumerWidget {
  /// Creates the #85 background-location reduced-coverage rung.
  const BackgroundLocationLimitedNotice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return HopBanner.notice(
      message: 'Keep this app open to stay online. Hoppin can only read your '
          "location while the app is on screen, so if you lock your phone or "
          'switch apps, dispatch stops seeing you after about 5 minutes and '
          "you'll stop getting offers. Set location to "
          '"Allow all the time" to drive with the screen off.',
      actionLabel: 'Fix in settings',
      onAction: () async {
        await ref
            .read(presenceInteractorProvider.notifier)
            .requestBackgroundCoverage();
      },
    );
  }
}
