import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app_router.dart';
import '../../../core/api/error_codes.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/nav/app_shell.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_loading.dart';
import '../data/models/driver_status.dart';
import '../logic/home_controller.dart';
import 'widgets/active_trip_banner.dart';
import 'widgets/blocker_list.dart';
import 'widgets/offer_card.dart';
import 'widgets/online_toggle.dart';
import 'widgets/today_tiles.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(homeControllerProvider);
    final controller = ref.read(homeControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        // Opens AppShell's drawer, not this Scaffold's — this one has none.
        // Scaffold.of(context) would resolve to the nearest ancestor and
        // throw, so the shell exposes its state via a key instead.
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => AppShell.openDrawer(),
        ),
        title: async.maybeWhen(
          data: (s) => OnlineToggle(
            isOnline: s.isOnline,
            // A blocked driver gets a disabled toggle plus a list saying
            // why — never a live toggle that silently refuses.
            onChanged: (s.status?.isBlocked ?? false) || s.isBusy
                ? null
                : (_) => controller.toggleOnline(),
          ),
          orElse: () => const SizedBox.shrink(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.go(Routes.settings),
          ),
        ],
      ),
      body: async.when(
        loading: () => const AppLoading(),
        error: (e, _) => Center(child: Text('$e', style: AppText.body)),
        data: (state) {
          if (state.error != null && state.status == null) {
            return AppErrorState(
                error: state.error!, onRetry: controller.refresh);
          }
          return RefreshIndicator(
            onRefresh: () async {
              await controller.refresh();
              final error = ref.read(homeControllerProvider).value?.error;
              // A pull-to-refresh the driver asked for must say when it
              // failed, rather than redisplaying stale data as current.
              if (error != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(errorCopy(error))),
                );
              }
            },
            child: ListView(
              children: [
                if (state.status?.presence == Presence.stale) _staleBanner(),
                // Above everything: a driver with a passenger in the car
                // needs the way back to Arrive/Start/Complete before they
                // need anything else on this screen.
                if (state.today?.hasActiveRide ?? false)
                  ActiveTripBanner(
                    onResume: () => context.push(
                        '${Routes.trip}/${state.today!.activeRideId}'),
                  ),
                if (state.today != null) TodayTiles(today: state.today!),
                if (state.status != null)
                  BlockerList(
                    status: state.status!,
                    onOpenDocument: (_) => context.go(Routes.documents),
                    // There is a vehicle form now; sending them to Documents
                    // left them hunting for a screen that was never there.
                    onRegisterVehicle: () =>
                        context.push(Routes.onboardingVehicle),
                    onContactSupport: () => context.go(Routes.support),
                    onOpenOnboarding: () => context.push(Routes.onboarding),
                  ),
                if (state.offer != null)
                  OfferCard(
                    offer: state.offer!,
                    isBusy: state.isBusy,
                    onAccept: () async {
                      final result = await controller.acceptOffer();
                      if (!context.mounted) return;
                      result.when(
                        ok: (rideId) => context.go('${Routes.trip}/$rideId'),
                        // A driver who taps Accept and sees the card simply
                        // vanish has no idea whether they got the job.
                        err: (e) => ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(errorCopy(e))),
                        ),
                      );
                    },
                    onDecline: controller.declineOffer,
                  )
                else
                  _waitingState(state),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _staleBanner() => Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.location_off, color: AppColors.warning),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                "We can't see your location right now, so you won't receive offers.",
                style: AppText.caption,
              ),
            ),
          ],
        ),
      );

  Widget _waitingState(HomeState state) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 80),
        child: Column(
          children: [
            Icon(
              state.isOnline ? Icons.radar : Icons.power_settings_new,
              size: 72,
              color:
                  state.isOnline ? AppColors.positive : AppColors.textDisabled,
            ),
            const SizedBox(height: 20),
            Text(
              state.isOnline ? 'Looking for offers…' : "You're offline",
              style: AppText.heading,
            ),
            const SizedBox(height: 6),
            Text(
              state.isOnline
                  ? "We'll let you know as soon as a ride comes in."
                  : 'Go online to start receiving ride offers.',
              style: AppText.bodySecondary,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
}
