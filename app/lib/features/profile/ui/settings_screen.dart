import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/nav/app_shell.dart';

import '../../../app_router.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/app_loading.dart';
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
      body: async.when(
        loading: () => const AppLoading(),
        error: (e, _) => Center(child: Text('$e', style: AppText.body)),
        // A fixed set of rows, not a feed: a lazy list would leave the
        // later rows out of the tree entirely on a short viewport.
        data: (prefs) => SingleChildScrollView(
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
              SettingsCard(
                children: [
                  SettingsRow(
                    icon: Icons.person_outline,
                    label: 'Personal information',
                    trailing: const _Chevron(),
                    onTap: () => context.push(Routes.personalInfo),
                  ),
                  SettingsRow(
                    icon: Icons.account_balance_outlined,
                    label: 'Payouts',
                    trailing: const _Chevron(),
                    onTap: () => context.push(Routes.payouts),
                  ),
                  SettingsRow(
                    icon: Icons.headset_mic_outlined,
                    label: 'Help & support',
                    trailing: const _Chevron(),
                    onTap: () => context.push(Routes.support),
                  ),
                ],
              ),
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

class _Chevron extends StatelessWidget {
  const _Chevron();

  @override
  Widget build(BuildContext context) => const Icon(Icons.chevron_right,
      size: 24, color: AppColors.textPrimary);
}
