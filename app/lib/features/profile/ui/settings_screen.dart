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
                title: const Text('Keep screen awake'),
                subtitle: const Text('While you are on a trip'),
                value: prefs.keepScreenAwake,
                onChanged: (v) =>
                    controller.apply(prefs.copyWith(keepScreenAwake: v)),
              ),
              const Divider(color: AppColors.border),
              ListTile(
                title: const Text('Distance units'),
                trailing: DropdownButton<DistanceUnit>(
                  value: prefs.distanceUnit,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(
                        value: DistanceUnit.miles, child: Text('Miles')),
                    DropdownMenuItem(
                        value: DistanceUnit.kilometres,
                        child: Text('Kilometres')),
                  ],
                  onChanged: (v) => v == null
                      ? null
                      : controller.apply(prefs.copyWith(distanceUnit: v)),
                ),
              ),
              ListTile(
                title: const Text('Navigation app'),
                trailing: DropdownButton<NavApp>(
                  value: prefs.navApp,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(
                        value: NavApp.google, child: Text('Google Maps')),
                    DropdownMenuItem(
                        value: NavApp.apple, child: Text('Apple Maps')),
                  ],
                  onChanged: (v) => v == null
                      ? null
                      : controller.apply(prefs.copyWith(navApp: v)),
                ),
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
