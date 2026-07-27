import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import 'offer_takeover_builder.dart';
import 'offer_takeover_state.dart';

/// Card slide-up: strong decel with a 1–2% overshoot settle (driver-ux-
/// motion §5 'Offer entrance') — the end value swings just past rest.
const Curve _entranceCurve = Cubic(0.16, 1.04, 0.3, 1);

/// ALL offer-takeover navigation lives in this file (riblet rule, DOCS/05):
/// the '/offer' route contribution below and the state→navigation listener
/// in [OfferTakeoverRouterListener]. The takeover NEVER self-inserts — the
/// dashboard router attaches it; accept/decline/expiry detach here.
///
/// W4 F5 guard: the offer arrives via `state.extra`, which an F5 mid-offer
/// cannot restore — an extra-less '/offer' redirects home, where the
/// dashboard's attach listener re-pushes the takeover off the still-pending
/// offer within one poll tick.
final offerRoutes = <RouteBase>[
  GoRoute(
    path: '/offer',
    redirect: (context, state) => state.extra is RideOffer ? null : '/',
    pageBuilder: (context, state) {
      final offer = state.extra! as RideOffer;
      final motion = context.hoppin.motion;
      return CustomTransitionPage<void>(
        key: state.pageKey,
        // The dashboard stays live below — this is an overlay, not a page.
        opaque: false,
        barrierDismissible: false,
        transitionDuration: motion.offerEntrance,
        reverseTransitionDuration: motion.quick,
        child: OfferTakeoverRiblet(offer: offer),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final colors = context.hoppin.colors;
          // Scrim beats the card in: fully faded within the first ~third
          // of the entrance (§5: scrim ~100ms of the 350ms slide).
          final scrim = CurvedAnimation(
            parent: animation,
            curve: const Interval(0, 0.3, curve: Curves.easeOut),
          );
          final slide = animation.drive(
            Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                .chain(CurveTween(curve: _entranceCurve)),
          );
          return Stack(
            fit: StackFit.expand,
            children: [
              FadeTransition(
                opacity: scrim,
                child: ColoredBox(color: colors.scrim),
              ),
              SlideTransition(position: slide, child: child),
            ],
          );
        },
      );
    },
  ),
];

/// The riblet's navigation listener, wrapped around the view by
/// [OfferTakeoverRiblet]: accepted replaces the whole stack with the trip
/// runner; dismissed (decline or the quiet expiry recycle) pops the
/// overlay. Both one-shot, prev-compare guarded.
class OfferTakeoverRouterListener extends ConsumerWidget {
  const OfferTakeoverRouterListener({
    required this.offer,
    required this.child,
    super.key,
  });

  /// The offer this listener watches — the interactor's family key.
  final RideOffer offer;

  /// The wrapped view subtree.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(offerTakeoverInteractorProvider(offer), (previous, next) {
      // Accepted → the runner. `go` replaces overlay + dashboard: the trip
      // owns the screen and back can never land on a dead offer.
      if (next.phase == OfferPhase.accepted &&
          previous?.phase != OfferPhase.accepted) {
        final rideId = next.acceptedRideId;
        if (rideId != null) context.go('/trip/$rideId');
        return;
      }
      // 🔴 403 NOT_ELIGIBLE → Documents. The server re-checked eligibility at
      // accept and refused; the ONE place the driver can act is their compliance
      // wallet. `go` replaces overlay + dashboard — this is a compliance event,
      // not a transient error to dismiss back onto. 🔴 We gate on the PHASE,
      // never on a seam value — the seam-as-gate lint greps driver *router*
      // files and a phase branch is exactly what it wants to see.
      if (next.phase == OfferPhase.notEligible &&
          previous?.phase != OfferPhase.notEligible) {
        context.go('/documents');
        return;
      }
      // Dismissed → detach the overlay; '/' is interactive again and the
      // world's re-offer re-attaches through the dashboard router.
      if (next.phase == OfferPhase.dismissed &&
          previous?.phase != OfferPhase.dismissed &&
          context.canPop()) {
        context.pop();
      }
    });
    return child;
  }
}
