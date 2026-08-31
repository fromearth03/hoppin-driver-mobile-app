import 'package:flutter/material.dart';

import '../../data/models/ride.dart';

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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_iconFor(phase), color: Colors.white, size: 24),
            const SizedBox(width: 10),
            Text(
              labelFor(phase),
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w500,
                color: Colors.white,
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
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(36),
        ),
        child: child,
      );
}
