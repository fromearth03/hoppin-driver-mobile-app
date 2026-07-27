import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'dashboard_builder.dart';

/// ALL dashboard navigation lives in this file (riblet rule, DOCS/05):
/// the riblet's route contribution below, and the state→navigation
/// listeners inside [DashboardRouterListener]. No `context.go/push/pop`
/// for dashboard concerns exists anywhere else.
final dashboardRoutes = <RouteBase>[
  GoRoute(path: '/', builder: (_, _) => const DashboardRiblet()),
];

/// The riblet's navigation listener, wrapped around the view by
/// [DashboardRiblet]. Its build registers the `ref.listen` blocks that
/// translate dashboard state into navigation:
///
/// - the trip-resume redirect (03-04),
/// - the offer-attach block (03-05): `pendingOffer` → the takeover
///   overlay; accept/decline/expiry detach it in the takeover's own
///   router — the takeover never self-inserts (DOCS/05).
class DashboardRouterListener extends ConsumerWidget {
  const DashboardRouterListener({required this.child, super.key});

  /// The wrapped view subtree.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(dashboardInteractorProvider, (previous, next) {
      // Both blocks only ever act while the driver sits at '/' — an open
      // takeover, a running trip, or the login screen is never hijacked.
      if (GoRouter.of(context).state.matchedLocation != '/') return;

      // Trip-resume redirect (03-04): an active ride surfacing in
      // telemetry pulls the driver INTO the runner. This is the F5-resume
      // path (boot lands on '/' with the world restored mid-trip); the
      // post-accept path is the takeover router's `go`.
      final rideId = next.activeRideId;
      if (rideId != null && rideId != previous?.activeRideId) {
        context.go('/trip/$rideId');
        return;
      }

      // Offer-attach (03-05): a NEW pending offer (fresh offerId — the
      // compare re-attaches re-offers and never double-pushes the same
      // offer) attaches the full-screen takeover over the dashboard.
      // This same block re-pushes after an F5 mid-offer: the extra-less
      // '/offer' redirected home, and the still-pending offer surfaces
      // here within one poll tick.
      final offer = next.pendingOffer;
      if (offer != null && offer.offerId != previous?.pendingOffer?.offerId) {
        context.push('/offer', extra: offer);
      }
    });
    return child;
  }
}
