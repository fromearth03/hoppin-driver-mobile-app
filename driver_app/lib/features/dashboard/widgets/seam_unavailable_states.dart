import 'package:flutter/material.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

/// Wave-0 designed unavailable-states for the DRIVER capability seams.
///
/// Every SEAMED feature ships the widget its consumer renders when the seam
/// answers `null` — a designed, token-driven degraded state, NEVER a blank
/// over `null`, and never a zero passed off as a real figure. These are the
/// fallback widgets `kSeamRegistry` names for the two driver seams that were
/// shipping UNDISCLOSED until Wave 0.
///
/// They are typography-led [HopEmptyState]s — no ad-hoc colours, paddings or
/// pixel values; the design system owns the look. When the live endpoints
/// ship (#7 driver telemetry; #6 rider identity on the offer payload) the
/// consuming views promote off these rungs to the live path with no change to
/// the surrounding anatomy.

/// Driver day-stats unavailable-state (seam #7).
///
/// The live backend serves no driver-telemetry read
/// ([DriverRepository.todayStats] answers `null`), so the dashboard's earnings
/// tile has no earnings, no trip count and no online clock to render.
///
/// THE FRAMING MATTERS. Presence is authoritative from `POST /drivers/me/online`
/// — a driver seeing this rung IS online and IS being dispatched offers. Only
/// the *stats display* is unavailable. This copy must never imply the driver is
/// offline, that dispatch is down, or that anything is broken: it names the one
/// missing thing (telemetry) and confirms everything else is working.
class DriverStatsUnavailable extends StatelessWidget {
  /// Creates the #7 driver day-stats degrade rung.
  const DriverStatsUnavailable({super.key});

  @override
  Widget build(BuildContext context) {
    return const HopEmptyState(
      compact: true,
      headline: "Today's stats unavailable",
      supporting:
          "You're online and taking rides — your earnings and trip count "
          'will appear here once trip telemetry is switched on.',
    );
  }
}

/// Trip rider-context unavailable-state (seam #6).
///
/// The offer payload carries no rider identity
/// ([DriverRepository.tripRiderContext] answers `null`), so the takeover's
/// rider row has no name, photo or rating to show. The job itself is fully
/// intact — the payout, the pickup and the accept are all real — so this rung
/// stays compact and quiet: it occupies the rider slot honestly rather than
/// letting it silently collapse.
class RiderContextUnavailable extends StatelessWidget {
  /// Creates the #6 rider-context degrade rung.
  const RiderContextUnavailable({super.key});

  @override
  Widget build(BuildContext context) {
    return const HopEmptyState(
      compact: true,
      headline: 'Rider details unavailable',
      supporting:
          "Pickup and payout are confirmed — the rider's name and rating "
          'will show here once the ride service shares them.',
    );
  }
}
