import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app_router.dart';
import '../../../core/api/error_codes.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_loading.dart';
import '../data/models/ride.dart';
import '../logic/trip_controller.dart';
import 'widgets/cancel_sheet.dart';
import 'widgets/map_pills.dart';
import 'widgets/rider_card.dart';
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
          // The waiting design draws a multi-stop route — A, B ("Mid point")
          // and C — with a per-leg mileage pill on each. The service supports
          // it (GET /rides/:id/stops, PATCH /rides/:id/stops/:seq/arrive and
          // /depart), but this app has no stops model yet, so what follows is
          // the single-leg pickup-to-dropoff variant. The multi-stop version
          // of this state is pending and is a separate piece of work.
          return Stack(
            children: [
              Positioned.fill(
                child: TripMap(
                  geo: ride.geo,
                  target: ride.phase == TripPhase.inTrip
                      ? ride.geo.dropoff
                      : ride.geo.pickup,
                ),
              ),
              SafeArea(
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
                      child: _mapButton(
                        icon: Icons.close,
                        tooltip: 'Cancel ride',
                        onPressed: () => _cancel(context, ref, state),
                      ),
                    ),
                  ),
                ),
              // The floating cards and the sheet share one bottom-aligned
              // column. Aligning them separately let the sheet grow over the
              // cards, hiding the cancel countdown behind Start Trip.
              Align(
                alignment: Alignment.bottomCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // While waiting, the design floats the elapsed wait and
                    // the free-cancellation countdown over the map.
                    if (ride.phase == TripPhase.waiting)
                      WaitingCancelCard(
                        arrivedAt: ride.arrivedAt,
                        freeCancelRemaining: state.freeCancelSecondsRemaining,
                      ),
                    if (ride.phase == TripPhase.inTrip)
                      TripDestinationPlate(label: ride.geo.dropoff.label),
                    const SizedBox(height: 12),
                    _bottomSheet(context, ref, state, ride),
                  ],
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
  }) =>
      Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(12),
        ),
        child: IconButton(
          icon: Icon(icon, color: Colors.white),
          tooltip: tooltip,
          onPressed: onPressed,
        ),
      );

  Widget _bottomSheet(
      BuildContext context, WidgetRef ref, TripState state, Ride ride) {
    final controller = ref.read(tripControllerProvider(rideId).notifier);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The grab handle the design draws. Decorative here - the sheet
            // does not drag - but it reads as the bottom of the map.
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              height: 5,
              width: 78,
              decoration: BoxDecoration(
                color: AppColors.textDisabled,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            if (ride.rider != null)
              RiderCard(
                rider: ride.rider!,
                rideRef: ride.ref,
                chatUnread: ride.chatUnread,
                onCall: () => _call(ride.rider!.phone),
                onChat: () => context.push('${Routes.trip}/$rideId/chat'),
              ),
            // The design pairs a status block on the left with the action
            // button on the right, rather than stacking them full width.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: _sheetStatus(state, ride)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _action(context, ref, state, ride, controller),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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

    // The design's action button is the brand orange, not the lilac the
    // forms use — on a map it has to win against the road behind it.
    final style = AppButtons.primary().copyWith(
      backgroundColor: const WidgetStatePropertyAll(AppColors.accent),
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

  Future<void> _cancel(
      BuildContext context, WidgetRef ref, TripState state) async {
    final reasonId = await CancelSheet.show(
      context,
      freeCancelRemaining: state.freeCancelSecondsRemaining,
    );
    if (reasonId == null || !context.mounted) return;

    final result =
        await ref.read(tripControllerProvider(rideId).notifier).cancel(reasonId);
    if (!context.mounted) return;

    result.when(
      ok: (_) => context.go(Routes.home),
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
