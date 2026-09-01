import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app_router.dart';
import '../../../core/api/error_codes.dart';
import '../../support/data/support_repository.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_loading.dart';
import '../data/models/ride.dart';
import '../data/models/ride_stop.dart';
import '../logic/trip_controller.dart';
import 'widgets/cancel_sheet.dart';
import 'widgets/emergency_sheet.dart';
import 'widgets/map_pills.dart';
import 'widgets/rider_card.dart';
import 'widgets/stops_card.dart';
import 'widgets/trip_map.dart';
import 'widgets/trip_summary.dart';
import 'widgets/waiting_timer.dart';

/// One screen for the whole job. The phase comes from the server's status,
/// so the bottom action bar is a function of the ride rather than of local
/// navigation — a ride cancelled elsewhere resolves here on the next read.
class TripScreen extends ConsumerWidget {
  final String rideId;

  const TripScreen({super.key, required this.rideId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(tripControllerProvider(rideId));
    final controller = ref.read(tripControllerProvider(rideId).notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: async.when(
        loading: () => const AppLoading(),
        error: (e, _) => Center(child: Text('$e', style: AppText.body)),
        data: (state) {
          final ride = state.ride;
          if (ride == null) {
            return AppErrorState(
                error: state.error!, onRetry: controller.refresh);
          }

          // A completed trip replaces the map entirely: the driver's question
          // is no longer "where am I going" but "what did I earn".
          if (ride.phase == TripPhase.completed) {
            return TripSummary(
              ride: ride,
              onDone: () => context.go(Routes.home),
            );
          }

          // The map is the screen. The sheet sits over it rather than
          // beside it, so the driver keeps as much road as possible.
          //
          // The design's multi-stop route — A, a mid point and C, each with
          // its own mileage — is the StopsCard below, which draws itself only
          // when the ride actually has stops.
          return Stack(
            children: [
              Positioned.fill(
                child: TripMap(
                  geo: ride.geo,
                  target: _mapTarget(ride, state.stops),
                ),
              ),
              SafeArea(
                // On web the map is a browser layer under Flutter's — without
                // an interceptor, drags on these pills fall through and pan
                // the map. Physical shield, exactly as it looks.
                child: PointerInterceptor(
                child: Column(
                  children: [
                    // A poll that keeps failing leaves the driver looking at
                    // a ride that may already have been cancelled underneath
                    // them. Stale data is the right fallback; silence is not.
                    if (state.error != null) _staleBanner(),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TripStatusPill(phase: ride.phase),
                    ),
                    const SizedBox(height: 10),
                    // The turn-by-turn banner the design stacks directly
                    // under the status pill. Empty on a finished trip and
                    // whenever OSRM had nothing, so it costs no height then.
                    TripNavBanner(steps: ride.geo.steps),
                    if (ride.geo.steps.isNotEmpty) const SizedBox(height: 10),
                    TripEtaPill(etaSeconds: ride.pickupEtaSeconds),
                  ],
                ),
                ),
              ),
              // Cancelling is a real action mid-job, but it is not the one
              // the driver came for. It takes the map's right edge — where
              // the design puts its recentre and zoom controls — rather than
              // the header, so the status pill and the nav banner both keep
              // the full width the design gives them.
              if (!ride.isFinished)
                SafeArea(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: PointerInterceptor(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Every phase: a driver in trouble must never hunt
                          // for help. Red, first in the stack.
                          _mapButton(
                            icon: Icons.sos,
                            tooltip: 'Emergency',
                            color: AppColors.negative,
                            onPressed: () => EmergencySheet.show(context,
                                rideId: ride.id),
                          ),
                          const SizedBox(height: 10),
                          // Cancelling is a pre-trip act: wrong pickup, or a
                          // passenger who never showed. Once the ride starts
                          // there is a passenger in the car and the button
                          // goes away.
                          if (ride.phase != TripPhase.inTrip)
                            _mapButton(
                              icon: Icons.close,
                              tooltip: 'Cancel ride',
                              onPressed: () => _cancel(context, ref, state),
                            ),
                          // Adding a stop is only possible while the ride is
                          // live; the handler answers 409 RIDE_CLOSED
                          // otherwise. Offered from the trip proper, once
                          // the rider is aboard and can ask for one.
                          if (ride.phase == TripPhase.inTrip) ...[
                            const SizedBox(height: 10),
                            _mapButton(
                              icon: Icons.add_location_alt_outlined,
                              tooltip: 'Add a stop',
                              onPressed: () => _addStop(context, ref, ride),
                            ),
                          ],
                        ],
                      ),
                      ),
                    ),
                  ),
                ),
              // The bottom panel is a real sheet now: drag it down to a
              // peek (grab handle + the action row stay reachable) to see
              // the whole map, pull it back up for the cards. Intercepted,
              // so dragging the sheet never pans the map beneath it on web.
              DraggableScrollableSheet(
                initialChildSize: 0.42,
                minChildSize: 0.17,
                maxChildSize: 0.80,
                snap: true,
                snapSizes: const [0.17, 0.42],
                builder: (context, scrollController) => PointerInterceptor(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.background,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(26)),
                      boxShadow: [
                        BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 14,
                            offset: Offset(0, -3)),
                      ],
                    ),
                    child: SafeArea(
                      top: false,
                      child: Column(
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 12, bottom: 4),
                            height: 5,
                            width: 78,
                            decoration: BoxDecoration(
                              color: AppColors.textDisabled,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          // Pinned: at the peek size the driver still sees
                          // the waiting clock / passenger and the CTA.
                          Padding(
                            padding:
                                const EdgeInsets.fromLTRB(20, 6, 20, 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(child: _sheetStatus(state, ride)),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: _action(context, ref, state, ride,
                                      ref.read(
                                          tripControllerProvider(rideId)
                                              .notifier)),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListView(
                              controller: scrollController,
                              padding:
                                  const EdgeInsets.fromLTRB(0, 4, 0, 12),
                              children: [
                                if (ride.phase == TripPhase.waiting)
                                  WaitingCancelCard(
                                    arrivedAt: ride.arrivedAt,
                                    freeCancelRemaining:
                                        state.freeCancelSecondsRemaining,
                                  ),
                                StopsCard(
                                  stops: state.stops,
                                  busy: state.isBusy,
                                  onArrive: ride.phase == TripPhase.inTrip
                                      ? (stop) =>
                                          _arriveAtStop(context, ref, stop)
                                      : null,
                                  onDepart: ride.phase == TripPhase.inTrip
                                      ? (stop) =>
                                          _departStop(context, ref, stop)
                                      : null,
                                ),
                                if (state.stops.multiStop)
                                  const SizedBox(height: 10),
                                if (ride.phase == TripPhase.inTrip &&
                                    state.stops.nextStop == null)
                                  TripDestinationPlate(
                                      label: ride.geo.dropoff.label),
                                if (ride.rider != null)
                                  RiderCard(
                                    rider: ride.rider!,
                                    rideRef: ride.ref,
                                    chatUnread: ride.chatUnread,
                                    onCall: () => _call(ride.rider!.phone),
                                    onChat: () => context
                                        .push('${Routes.trip}/$rideId/chat'),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// The dark round map control the design uses for the recentre and zoom
  /// buttons. Ours carries the cancel action.
  Widget _mapButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    Color? color,
  }) =>
      Container(
        decoration: BoxDecoration(
          color: color ?? Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(12),
        ),
        child: IconButton(
          icon: Icon(icon, color: Colors.white),
          tooltip: tooltip,
          onPressed: onPressed,
        ),
      );


  /// The left column of the sheet: the waiting clock while waiting, and who
  /// is aboard once under way — the two things the design puts there.
  Widget _sheetStatus(TripState state, Ride ride) {
    if (ride.phase == TripPhase.waiting && state.policy != null) {
      return WaitingTimer(policy: state.policy!);
    }
    if (ride.phase == TripPhase.inTrip && ride.rider != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Current Passenger', style: AppText.caption),
          const SizedBox(height: 2),
          Text(
            ride.rider!.fullName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.title.copyWith(fontWeight: FontWeight.w500),
          ),
        ],
      );
    }
    if (ride.phase == TripPhase.headingToPickup) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Pickup', style: AppText.caption),
          const SizedBox(height: 2),
          Text(
            ride.geo.pickup.label ?? 'Heading to pickup',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.heading,
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _action(BuildContext context, WidgetRef ref, TripState state, Ride ride,
      TripController controller) {
    final (label, action) = switch (ride.phase) {
      TripPhase.headingToPickup => ('Arrived at Pickup', controller.arrive),
      TripPhase.waiting => ('Start Trip', controller.start),
      TripPhase.inTrip => ('Finish Trip', controller.complete),
      _ => ('Back to Home', null),
    };

    // The design reserves the brand orange for the two moments that move the
    // meter — Start Trip and Finish Trip. Everything else here (Arrived at
    // Pickup, Back to Home, any future phase) states a fact rather than
    // starting a charge, and stays in the forms' lilac.
    final chargeMoment =
        ride.phase == TripPhase.waiting || ride.phase == TripPhase.inTrip;
    final style = AppButtons.primary().copyWith(
      backgroundColor: WidgetStatePropertyAll(
          chargeMoment ? AppColors.accent : AppColors.buttonPrimary),
      textStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
    );

    if (action == null) {
      return AppButton(
        label: label,
        style: style,
        onPressed: () => context.go(Routes.home),
      );
    }

    return AppButton(
      label: label,
      style: style,
      busy: state.isBusy,
      onPressed: () async {
        final result = await action();
        if (!context.mounted) return;
        result.when(
          ok: (_) {},
          err: (e) => ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(errorCopy(e)))),
        );
      },
    );
  }

  /// Shown when the trip poll is failing. The ride on screen may be out of
  /// date — the driver needs to know that before they keep driving to a
  /// pickup that could already have been cancelled.
  Widget _staleBanner() => Container(
        width: double.infinity,
        color: AppColors.warning.withValues(alpha: 0.15),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: const Row(
          children: [
            Icon(Icons.cloud_off, size: 18, color: AppColors.warning),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                "We've lost contact with the server — this may be out of date.",
                style: AppText.caption,
              ),
            ),
          ],
        ),
      );

  /// Where the map should look. While stops remain, the driver is heading
  /// for the next stop — pointing at the final dropoff would send them past
  /// it.
  static GeoPoint _mapTarget(Ride ride, RideStops stops) {
    if (ride.phase != TripPhase.inTrip) return ride.geo.pickup;
    final next = stops.nextStop;
    if (next != null) return next.to;
    return ride.geo.dropoff;
  }

  Future<void> _arriveAtStop(
      BuildContext context, WidgetRef ref, RideStop stop) async {
    final result =
        await ref.read(tripControllerProvider(rideId).notifier).arriveAtStop(stop.seq);
    if (!context.mounted) return;
    result.when(
      ok: (_) {},
      err: (e) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errorCopy(e)))),
    );
  }

  Future<void> _departStop(
      BuildContext context, WidgetRef ref, RideStop stop) async {
    final result =
        await ref.read(tripControllerProvider(rideId).notifier).departStop(stop.seq);
    if (!context.mounted) return;
    result.when(
      // The waiting charge is the server's answer to this call, and it is
      // the driver's money — so it is said out loud rather than left to be
      // noticed on the summary.
      ok: (waiting) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(waiting.isZero
              ? 'Departed. No waiting charge at this stop.'
              : 'Departed. ${waiting.format()} waiting added to the fare.'),
        ),
      ),
      err: (e) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errorCopy(e)))),
    );
  }

  /// Adds a stop at the ride's current dropoff coordinates.
  ///
  /// The service inserts the new stop before the dropoff and re-prices every
  /// leg. It takes a lat/lng and rejects zeroes, and the driver has no way to
  /// pick a point on this screen — so the coordinates come from where the
  /// ride is already headed, and the label is what makes it meaningful.
  Future<void> _addStop(BuildContext context, WidgetRef ref, Ride ride) async {
    final label = await AddStopSheet.show(context);
    if (label == null || !context.mounted) return;

    final result =
        await ref.read(tripControllerProvider(rideId).notifier).addStop(
              lat: ride.geo.dropoff.lat,
              lng: ride.geo.dropoff.lng,
              label: label.isEmpty ? 'Stop' : label,
            );
    if (!context.mounted) return;

    result.when(
      ok: (added) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Stop added. Fare is now ${added.total.format()}.'),
        ),
      ),
      err: (e) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errorCopy(e)))),
    );
  }

  Future<void> _cancel(
      BuildContext context, WidgetRef ref, TripState state) async {
    final choice = await CancelSheet.show(
      context,
      freeCancelRemaining: state.freeCancelSecondsRemaining,
    );
    if (choice == null || !context.mounted) return;

    final result = await ref
        .read(tripControllerProvider(rideId).notifier)
        .cancel(choice.reasonId);
    if (!context.mounted) return;

    result.when(
      ok: (_) {
        // The driver's own words have no field on the cancel call, so they
        // go to support against the ride. Navigation doesn't wait on the
        // ticket, but its failure is not silent either — losing the one
        // record of why the ride was cancelled deserves a nudge to refile.
        if (choice.details.isNotEmpty) {
          final messenger = ScaffoldMessenger.of(context);
          ref
              .read(supportRepositoryProvider)
              .create(
                // An other-reason cancel is named as such so operations can
                // audit it — it carried no configured reason or fee, and
                // this ticket is its only paper trail.
                subject: choice.reasonId == null
                    ? 'Ride cancelled — other reason (review)'
                    : 'Ride cancellation details',
                category: 'ride',
                ticketBody: choice.details,
                rideId: rideId,
              )
              .then((r) {
            if (!r.isOk) {
              messenger.showSnackBar(const SnackBar(
                content: Text("Your note to support didn't send — please "
                    'refile it from Help & Support.'),
              ));
            }
          });
        }
        context.go(Routes.home);
      },
      // NO_SHOW_TOO_EARLY renders as a countdown rather than a bare refusal,
      // so the driver knows how long to keep waiting.
      err: (e) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errorCopy(e)))),
    );
  }

  Future<void> _call(String? phone) async {
    if (phone == null) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }
}
