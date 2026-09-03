import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/nav/app_shell.dart';

import '../../../app_router.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../../shared/widgets/async_view.dart';
import '../data/notification_settings.dart';
import '../logic/profile_controller.dart';
import 'widgets/logout_dialog.dart';
import 'widgets/settings_card.dart';

/// Settings, grouped into the three cards the design uses: the toggles, the
/// destinations, then the two account actions.
///
/// The design's second card lists Navigation, Distance Units and Language.
/// None of the three is on the server's preference whitelist — the endpoint
/// rejects the whole patch on an unknown key — so the rows are not built.
/// Language is dropped outright: the app ships a single locale.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(preferencesControllerProvider);
    final controller = ref.read(preferencesControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: settingsAppBar(context, 'Settings'),
      body: AsyncView(
        value: async,
        loading: () => const SkeletonList(lines: 1),
        error: (e, _) => Center(child: Text('$e', style: AppText.body)),
        // A fixed set of rows, not a feed: a lazy list would leave the
        // later rows out of the tree entirely on a short viewport.
        data: (prefs, _) => SingleChildScrollView(
          padding: const EdgeInsets.only(
              top: 8, bottom: AppShell.bottomClearance),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SettingsCard(
                children: [
                  SettingsRow(
                    icon: Icons.notifications_none,
                    label: 'Notifications',
                    trailing: SettingsSwitch(
                      value: prefs.notificationsEnabled,
                      onChanged: (v) => controller
                          .apply(prefs.copyWith(notificationsEnabled: v)),
                    ),
                  ),
                  SettingsRow(
                    icon: Icons.volume_up_outlined,
                    label: 'Ride request sound',
                    trailing: SettingsSwitch(
                      value: prefs.rideRequestSound,
                      onChanged: (v) =>
                          controller.apply(prefs.copyWith(rideRequestSound: v)),
                    ),
                  ),
                  SettingsRow(
                    icon: Icons.vibration,
                    label: 'Vibrate for alerts',
                    trailing: SettingsSwitch(
                      // Local to this handset rather than part of the
                      // account's preferences: the same driver on a second
                      // phone should not inherit a choice made about the
                      // first, and the toast needs the answer without waiting
                      // on a round trip.
                      value: ref.watch(notificationHapticsProvider),
                      onChanged: (v) =>
                          ref.read(notificationHapticsProvider.notifier).set(v),
                    ),
                  ),
                  SettingsRow(
                    icon: Icons.campaign_outlined,
                    label: 'Promotions',
                    trailing: SettingsSwitch(
                      value: prefs.pushPromotions,
                      onChanged: (v) =>
                          controller.apply(prefs.copyWith(pushPromotions: v)),
                    ),
                  ),
                  SettingsRow(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Payout alerts',
                    trailing: SettingsSwitch(
                      value: prefs.pushPayouts,
                      onChanged: (v) =>
                          controller.apply(prefs.copyWith(pushPayouts: v)),
                    ),
                  ),
                ],
              ),
              SettingsCard(
                children: [
                  SettingsRow(
                    icon: Icons.mail_outline,
                    label: 'Email receipts',
                    trailing: SettingsSwitch(
                      value: prefs.emailReceipts,
                      onChanged: (v) =>
                          controller.apply(prefs.copyWith(emailReceipts: v)),
                    ),
                  ),
                  SettingsRow(
                    icon: Icons.sms_outlined,
                    label: 'Trip updates by SMS',
                    trailing: SettingsSwitch(
                      value: prefs.smsTripUpdates,
                      onChanged: (v) =>
                          controller.apply(prefs.copyWith(smsTripUpdates: v)),
                    ),
                  ),
                ],
              ),
              // Personal information, Payouts and Help & Support used to be
              // linked from here too. The drawer is their one home now — a
              // second path from Settings was redundancy the design never
              // drew, and two routes to the same screen is two places for a
              // driver to look for it.
              SettingsCard(
                children: [
                  SettingsRow(
                    icon: Icons.logout,
                    label: 'Logout',
                    onTap: () => showLogoutDialog(context, ref),
                  ),
                  SettingsRow(
                    icon: Icons.delete_outline,
                    label: 'Delete account',
                    labelColor: AppColors.negative,
                    onTap: () => context.push(Routes.deleteAccount),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

