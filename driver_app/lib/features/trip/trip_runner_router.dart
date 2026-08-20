import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../earned_moment/earned_moment_router.dart';
import '../rating/rider_rating_sheet.dart';
import 'trip_runner_builder.dart';
import 'trip_runner_state.dart';

/// ALL trip-runner navigation lives in this file (riblet rule, DOCS/05):
/// the riblet's /trip/:id route contribution below, and the completed →
/// earned-moment attach inside [TripRunnerRouterListener]. The id is a
/// path parameter, so the route carries its own state across an F5 — no
/// `state.extra` to guard (the W4 null-extra concern applies to 03-05's
/// /offer route, not here).
final tripRoutes = <RouteBase>[
  GoRoute(
    path: '/trip/:id',
    builder: (_, state) =>
        TripRunnerRiblet(rideId: state.pathParameters['id']!),
  ),
];

/// The riblet's navigation listener, wrapped around the view by
/// [TripRunnerRiblet]: when the trip COMPLETES, the parent attaches the
/// earned-moment sheet exactly once — the sheet never self-inserts
/// (attach/detach rule, DOCS/05).
///
/// 🔴 THE PHASE IS THE TRIGGER. THE FIGURE IS DECORATION.
///
/// This used to gate the attach on the presence of a payout figure. That figure
/// comes from the #7 (`todayStats()`) seam, which answers null on EVERY live
/// request — so on live the sheet never attached, and the completed card (whose
/// only exit was that sheet) stranded the driver on a dead screen after every
/// single trip. A money figure must never decide whether a driver can leave a
/// screen. The trip now completes and exits with or without one; the sheet is
/// not even TOLD the figure — it watches it, as decoration.
///
/// The seam-as-gate lint in `hoppin_shared/test` greps every driver `*router*`
/// file for that gate expression, and a grep cannot tell code from prose — so
/// this comment deliberately does not spell it out. The lint is right to be
/// blunt: the check is not weakened to accommodate a comment.
class TripRunnerRouterListener extends ConsumerWidget {
  const TripRunnerRouterListener({
    required this.rideId,
    required this.child,
    super.key,
  });

  /// The ride this listener watches.
  final String rideId;

  /// The wrapped view subtree.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(tripRunnerInteractorProvider(rideId), (previous, next) {
      // THE EXIT — first, and unconditionally. The driver tapped Done on the
      // completed card; nothing may stand between them and the dashboard.
      if (next.dismissed && !(previous?.dismissed ?? false)) {
        context.go('/');
        return;
      }

      if (next.phase == TripPhase.cancelled &&
          previous?.phase != TripPhase.cancelled) {
        context.go('/');
        return;
      }

      final completed = next.phase == TripPhase.completed;
      final wasCompleted =
          previous != null && previous.phase == TripPhase.completed;
      if (!completed || wasCompleted) return;
      // One-shot (prev-compare guarded): the parent attaches the child.
      // THE PHASE is the trigger and the RIDE is the key. The payout is not
      // passed at all — the sheet watches it, because it is decoration that may
      // land a beat late or never land.
      unawaited(_onCompleted(context, rideId));
    });
    return child;
  }

  /// The completed-trip choreography: the earned-moment sheet, THEN the offer
  /// to rate the rider.
  ///
  /// 🔴 THE RATING RIDES THE ROOT OVERLAY, NEVER THIS SUBTREE. The earned-moment
  /// router collapses the sheet and `context.go('/')`s home the instant the
  /// timeline reaches done — so by the time `attachEarnedMoment` completes, the
  /// runner (and this listener's context) is already tearing down with its
  /// route. The root overlay, captured up front, outlives that: the rating gate
  /// mounts there, motion-gated and skippable, and it NEVER blocks the exit
  /// because the driver is already on the dashboard when it appears.
  Future<void> _onCompleted(BuildContext context, String rideId) async {
    // Captured BEFORE the await — the runner's own context is defunct after the
    // earned-moment sheet sends the driver home.
    // The ROOT overlay, captured BEFORE the await — the runner's own context is
    // defunct after the earned-moment sheet sends the driver home, but the root
    // overlay (above the router) outlives the route change.
    final rootOverlay = Overlay.of(context, rootOverlay: true);
    await attachEarnedMoment(context, rideId: rideId);
    if (!rootOverlay.mounted) return;
    attachRiderRating(rootOverlay, rideId: rideId);
  }
}
