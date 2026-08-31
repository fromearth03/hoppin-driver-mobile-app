import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app_router.dart';
import '../../../core/api/error_codes.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_loading.dart';
import '../data/models/ride.dart';
import '../logic/trip_controller.dart';
import 'widgets/cancel_sheet.dart';
import 'widgets/map_pills.dart';
import 'widgets/rider_card.dart';
import 'widgets/trip_map.dart';
import 'widgets/waiting_timer.dart';

/// One screen for the whole job. The phase comes from the server's status,
/// so the bottom action bar is a function of the ride rather than of local
/// navigation — a ride cancelled elsewhere resolves here on the next read.
class TripScreen extends ConsumerWidget {
  final String rideId;

  const TripScreen({super.key, required this.rideId});

  static const _titles = {
    TripPhase.headingToPickup: 'Heading to pickup',
    TripPhase.waiting: 'Waiting for passenger',
    TripPhase.inTrip: 'On the way',
    TripPhase.completed: 'Trip complete',
    TripPhase.cancelled: 'Trip cancelled',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(tripControllerProvider(rideId));
    final controller = ref.read(tripControllerProvider(rideId).notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[async.value?.phase] ?? 'Trip'),
        actions: [
          if (!(async.value?.ride?.isFinished ?? true))
            IconButton(
              icon: const Icon(Icons.close, color: AppColors.negative),
              onPressed: () => _cancel(context, ref),
            ),
        ],
      ),
      body: async.when(
        loading: () => const AppLoading(),
        error: (e, _) => Center(child: Text('$e', style: AppText.body)),
        data: (state) {
          final ride = state.ride;
          if (ride == null) {
            return AppErrorState(
                error: state.error!, onRetry: controller.refresh);
          }
          // The map is the screen. The sheet sits over it rather than
          // beside it, so the driver keeps as much road as possible.
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
                    TripStatusPill(phase: ride.phase),
                    const Spacer(),
                    TripEtaPill(etaSeconds: ride.pickupEtaSeconds),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: _bottomSheet(context, ref, state, ride),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _bottomSheet(
      BuildContext context, WidgetRef ref, TripState state, Ride ride) {
    final controller = ref.read(tripControllerProvider(rideId).notifier);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
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
                color: AppColors.border,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            if (ride.ref != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(ride.ref!, style: AppText.caption),
              ),
            if (ride.rider != null)
              RiderCard(
                rider: ride.rider!,
                chatUnread: ride.chatUnread,
                onCall: () => _call(ride.rider!.phone),
                onChat: () => context.push('${Routes.trip}/$rideId/chat'),
              ),
            if (ride.phase == TripPhase.waiting && state.policy != null)
              WaitingTimer(policy: state.policy!),
            Padding(
              padding: const EdgeInsets.all(16),
              child: _action(context, ref, state, ride, controller),
            ),
          ],
        ),
      ),
    );
  }

  Widget _action(BuildContext context, WidgetRef ref, TripState state, Ride ride,
      TripController controller) {
    final (label, action) = switch (ride.phase) {
      TripPhase.headingToPickup => ('Arrived at Pickup', controller.arrive),
      TripPhase.waiting => ('Start Trip', controller.start),
      TripPhase.inTrip => ('Finish Trip', controller.complete),
      _ => ('Back to Home', null),
    };

    if (action == null) {
      return FilledButton(
        onPressed: () => context.go(Routes.home),
        child: Text(label),
      );
    }

    return FilledButton(
      onPressed: state.isBusy
          ? null
          : () async {
              final result = await action();
              if (!context.mounted) return;
              result.when(
                ok: (_) {},
                err: (e) => ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(errorCopy(e)))),
              );
            },
      child: Text(label),
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

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final reasonId = await CancelSheet.show(context);
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
