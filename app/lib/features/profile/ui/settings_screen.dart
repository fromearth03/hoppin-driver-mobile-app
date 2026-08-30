import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app_router.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/app_loading.dart';
import '../data/models/driver_preferences.dart';
import '../logic/profile_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(preferencesControllerProvider);
    final controller = ref.read(preferencesControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: async.when(
        loading: () => const AppLoading(),
        error: (e, _) => Center(child: Text('$e', style: AppText.body)),
        // A fixed set of rows, not a feed: a lazy list would leave the
        // later rows out of the tree entirely on a short viewport.
        data: (prefs) => SingleChildScrollView(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Notifications'),
                subtitle: const Text('Ride offers and account updates'),
                value: prefs.notificationsEnabled,
                onChanged: (v) =>
                    controller.apply(prefs.copyWith(notificationsEnabled: v)),
              ),
              SwitchListTile(
                title: const Text('Ride request sound'),
                value: prefs.rideRequestSound,
                onChanged: (v) =>
                    controller.apply(prefs.copyWith(rideRequestSound: v)),
              ),
              SwitchListTile(
                title: const Text('Promotions'),
                subtitle: const Text('Bonuses and incentives'),
                value: prefs.pushPromotions,
                onChanged: (v) =>
                    controller.apply(prefs.copyWith(pushPromotions: v)),
              ),
              SwitchListTile(
                title: const Text('Payout alerts'),
                subtitle: const Text('When money reaches your bank'),
                value: prefs.pushPayouts,
                onChanged: (v) =>
                    controller.apply(prefs.copyWith(pushPayouts: v)),
              ),
              const Divider(color: AppColors.border),
              SwitchListTile(
                title: const Text('Email receipts'),
                value: prefs.emailReceipts,
                onChanged: (v) =>
                    controller.apply(prefs.copyWith(emailReceipts: v)),
              ),
              SwitchListTile(
                title: const Text('Trip updates by SMS'),
                value: prefs.smsTripUpdates,
                onChanged: (v) =>
                    controller.apply(prefs.copyWith(smsTripUpdates: v)),
              ),
              const Divider(color: AppColors.border),
              ListTile(
                title: const Text('Personal information'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(Routes.personalInfo),
              ),
              ListTile(
                title: const Text('Payments'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(Routes.payouts),
              ),
              ListTile(
                title: const Text('Help & support'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(Routes.support),
              ),
              ListTile(
                title: Text('Delete account',
                    style: AppText.body.copyWith(color: AppColors.negative)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(Routes.deleteAccount),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
