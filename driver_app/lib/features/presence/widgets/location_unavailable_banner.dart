import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import '../../location/location_providers.dart';

/// The designed unavailable-state for seam **#84** — OS location permission
/// (`SeamKind.device`).
///
/// This is the seam discipline applied to a DEVICE capability rather than a
/// backend one. There is no endpoint to ask for and no gap to relay: the
/// heartbeat endpoint exists and works. What is unavailable is the DEVICE's
/// consent to give us a fix — and the consequence is identical to a backend
/// hole, so the rung is identical too.
///
/// 🔴 WHAT IS AT STAKE. `POST /drivers/me/location` is what KEEPS a driver in
/// the dispatch pool: the admin marks them Offline after 5 minutes with no
/// ping. With OS location denied there is no fix, therefore no ping, therefore
/// the driver is NOT DISPATCHABLE — and the app must never show a confident
/// ONLINE state over a driver nobody can reach. That is not a cosmetic lie: it
/// is a driver sitting in their car for an hour believing they are working.
///
/// So this banner does three things, and all three are load-bearing:
///   1. it says the app is NOT receiving trips (the consequence, in plain
///      English — not "location error", which tells a driver nothing they can
///      act on),
///   2. it names the cause (the phone's location permission), and
///   3. it gives a REAL forward exit — the OS settings page. A disclosure that
///      strands the user is only half-honest.
class LocationUnavailableBanner extends ConsumerWidget {
  /// Creates the #84 device-location degrade rung.
  const LocationUnavailableBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return HopBanner.error(
      message: "You're not receiving trips. Hoppin can't read your location, "
          'so we cannot tell dispatch where you are. Turn on location for '
          'Hoppin to start getting offers.',
      actionLabel: 'Open settings',
      onAction: () async {
        await ref.read(driverLocationServiceProvider).openSettings();
      },
    );
  }
}
