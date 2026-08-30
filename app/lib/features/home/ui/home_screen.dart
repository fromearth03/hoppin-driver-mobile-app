import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app_router.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_loading.dart';
import '../data/models/driver_status.dart';
import '../logic/home_controller.dart';
import 'widgets/blocker_list.dart';
import 'widgets/offer_card.dart';
import 'widgets/online_toggle.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(homeControllerProvider);
    final controller = ref.read(homeControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
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
            onRefresh: controller.refresh,
            child: ListView(
              children: [
                if (state.status?.presence == Presence.stale) _staleBanner(),
                if (state.status != null)
                  BlockerList(
                    status: state.status!,
                    onOpenDocument: (_) => context.go(Routes.documents),
                    onRegisterVehicle: () => context.go(Routes.documents),
                    onContactSupport: () => context.go(Routes.support),
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
                        err: (_) {},
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
