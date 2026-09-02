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
import 'widgets/offline_hero.dart';
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
              error: state.error!,
              onRetry: controller.refresh,
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              await controller.refresh();
              final error = ref.read(homeControllerProvider).value?.error;
              // A pull-to-refresh the driver asked for must say when it
              // failed, rather than redisplaying stale data as current.
              if (error != null && context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(errorCopy(error))));
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
                      '${Routes.trip}/${state.today!.activeRideId}',
                    ),
                  ),
                // The offline hero leads: it is the reason to go online and
                // the button that does it. Suppressed once an offer is on
                // screen, which outranks everything.
                if (!state.isOnline && state.offer == null)
                  OfflineHero(
                    onGoOnline:
                        (state.status?.isBlocked ?? false) || state.isBusy
                        ? null
                        : () => controller.toggleOnline(),
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
                if (!state.isOnline && state.offer == null)
                  const MoreRidesCard(),
                if (state.offer != null)
                  // The match landing is the moment of the whole shift —
                  // the card arrives with a spring rather than blinking
                  // into place. Keyed by offer id so only a NEW offer
                  // animates, not every poll refresh of the same one.
                  TweenAnimationBuilder<double>(
                    key: ValueKey(state.offer!.id),
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeOutBack,
                    builder: (context, v, child) => Transform.translate(
                      offset: Offset(0, (1 - v) * 28),
                      child: Transform.scale(
                        scale: 0.94 + v * 0.06,
                        child: Opacity(opacity: v.clamp(0, 1), child: child),
                      ),
                    ),
                    child: OfferCard(
                      offer: state.offer!,
                      isBusy: state.isBusy,
                      onAccept: () async {
                        final result = await controller.acceptOffer();
                        if (!context.mounted) return;
                        result.when(
                          ok: (rideId) => context.go('${Routes.trip}/$rideId'),
                          // A driver who taps Accept and sees the card simply
                          // vanish has no idea whether they got the job.
                          err: (e) => ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(errorCopy(e)))),
                        );
                      },
                      onDecline: controller.declineOffer,
                      // The card's own clock is the only thing watching once
                      // the poll stops, so it is what takes the dead card
                      // down.
                      onExpired: controller.expireOffer,
                    ),
                  )
                else
                  NoBookingsCard(isOnline: state.isOnline),
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
}
