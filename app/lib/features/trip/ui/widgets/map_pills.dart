import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../data/models/ride.dart';
import 'waiting_timer.dart';

/// The floating pill naming what the driver is doing right now.
///
/// Sits over the map rather than in an app bar: the map is the screen, and a
/// bar would cost a strip of road the driver is trying to read.
class TripStatusPill extends StatelessWidget {
  final TripPhase phase;

  const TripStatusPill({super.key, required this.phase});

  static String labelFor(TripPhase phase) => switch (phase) {
        TripPhase.headingToPickup => 'Heading to Pickup',
        TripPhase.waiting => 'Waiting for Passenger',
        TripPhase.inTrip => 'Heading to Dropoff',
        TripPhase.completed => 'Trip Complete',
        TripPhase.cancelled => 'Trip Cancelled',
      };

  static IconData _iconFor(TripPhase phase) => switch (phase) {
        TripPhase.headingToPickup => Icons.turn_right,
        TripPhase.waiting => Icons.hourglass_top,
        TripPhase.inTrip => Icons.navigation,
        TripPhase.completed => Icons.check_circle_outline,
        TripPhase.cancelled => Icons.cancel_outlined,
      };

  @override
  Widget build(BuildContext context) => _Pill(
        // The design draws this nearly edge to edge, not hugging its text.
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_iconFor(phase), color: Colors.white, size: 24),
            const SizedBox(width: 10),
            // "Waiting for Passenger" at 21pt plus the icon still exceeds a
            // narrow artboard, so the label yields rather than overflowing.
            Flexible(
              child: Text(
                labelFor(phase),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );
}

/// Time and distance to whatever the driver is heading for.
///
/// Rendered only when the server actually supplies them — an ETA the app
/// invented is worse than no ETA, because the driver plans around it.
class TripEtaPill extends StatelessWidget {
  final int? etaSeconds;
  final double? miles;

  const TripEtaPill({super.key, this.etaSeconds, this.miles});

  bool get hasAnything => etaSeconds != null || miles != null;

  @override
  Widget build(BuildContext context) {
    if (!hasAnything) return const SizedBox.shrink();
    final parts = <String>[
      if (etaSeconds != null) '${(etaSeconds! / 60).ceil()} min',
      if (miles != null) '${miles!.toStringAsFixed(1)} miles',
    ];
    return _Pill(
      child: Text(
        parts.join('  |  '),
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// The translucent dark lozenge both pills share.
class _Pill extends StatelessWidget {
  final Widget child;

  const _Pill({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(36),
        ),
        child: child,
      );
}

/// The wide "Destination — <address>" plate the Start Ride design floats just
/// above the sheet, so the driver can read where they are taking the rider
/// without opening anything.
///
/// The design's turn-by-turn instruction pill ("Take left after 1.5 mi") is
/// deliberately absent. `internal/handler/nav_steps.go` defines the step type
/// but nothing calls it, and every OSRM request the service makes sets
/// `steps=false`, so there is no manoeuvre to render. Inventing one would send
/// a driver down the wrong road.
class TripDestinationPlate extends StatelessWidget {
  final String? label;

  const TripDestinationPlate({super.key, this.label});

  @override
  Widget build(BuildContext context) {
    // `geo.dropoff.label` is nullable on the payload. A plate reading
    // "Destination —" with nothing after it is worse than no plate.
    if (label == null || label!.trim().isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Destination',
              style: AppText.caption.copyWith(color: Colors.white70)),
          const SizedBox(height: 2),
          Text(
            label!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// The dark card the Cancel Ride design floats over the map while the driver
/// is waiting: how long they have been there, and the countdown that matters —
/// how long is left to cancel without a charge.
///
/// [freeCancelRemaining] is real, not decorative. Driver-actor cancellation
/// reasons carry `free_cancel_seconds`, and `gracedPenalty` waives the fee
/// entirely while `time.Since(accepted_at)` is inside that window. Once it
/// runs out the driver is charged, so the number is the difference between a
/// free cancellation and a penalty.
class WaitingCancelCard extends StatelessWidget {
  final DateTime? arrivedAt;
  final int? freeCancelRemaining;

  const WaitingCancelCard({
    super.key,
    this.arrivedAt,
    this.freeCancelRemaining,
  });

  @override
  Widget build(BuildContext context) {
    if (arrivedAt == null) return const SizedBox.shrink();

    return Ticking(
      builder: (context) {
        final waited =
            DateTime.now().toUtc().difference(arrivedAt!.toUtc()).inSeconds;

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "You've been waiting for ${clockOf(waited)}",
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "If the passenger doesn't show up soon, you can cancel the ride",
                style: TextStyle(fontSize: 15, color: Colors.white),
              ),
              if (freeCancelRemaining != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text('Time left to cancel without impact',
                            style: AppText.body),
                      ),
                      Text(
                        clockOf(freeCancelRemaining!),
                        style: AppText.title.copyWith(
                          fontSize: 21,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
