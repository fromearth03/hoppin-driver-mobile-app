import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../data/models/app_status.dart';
import '../logic/app_gate_controller.dart';

/// The wall shown when the operator has closed the app.
///
/// Two situations, one screen: the service is down for planned work, or this
/// build is below the floor the operator armed. Both leave the driver unable
/// to work, so both have to say plainly what happened and what ends it —
/// anything vaguer and they spend the outage retrying a login that cannot
/// succeed.
///
/// The service publishes no start or end time for maintenance
/// (`/app-status` carries the flag alone), so this promises no window. A
/// made-up "back at 3pm" is worse than an honest "we are checking".
class AppGateScreen extends ConsumerWidget {
  final AppStatus status;

  const AppGateScreen({super.key, required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final maintenance = status.gate == AppGate.maintenance;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    height: 92,
                    width: 92,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: (maintenance
                              ? AppColors.warning
                              : AppColors.primaryLight)
                          .withValues(alpha: 0.13),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      maintenance
                          ? Icons.construction_outlined
                          : Icons.system_update_alt,
                      size: 42,
                      color: maintenance
                          ? AppColors.warning
                          : AppColors.primaryLight,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  maintenance
                      ? 'Hoppin is down for maintenance'
                      : 'Update to keep driving',
                  textAlign: TextAlign.center,
                  style: AppText.title.copyWith(fontSize: 23),
                ),
                const SizedBox(height: 12),
                Text(
                  maintenance
                      ? "We're working on the service right now, so you "
                          "can't go online or take rides. This screen will "
                          'clear itself the moment we are back — you do not '
                          'need to do anything.'
                      : 'This version of the app can no longer connect to '
                          'the service. Update from the store and sign back '
                          'in — your shift and earnings are unaffected.',
                  textAlign: TextAlign.center,
                  style: AppText.body.copyWith(color: AppColors.textSecondary),
                ),
                if (!maintenance && status.latestVersion != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Latest version ${status.latestVersion}',
                    textAlign: TextAlign.center,
                    style: AppText.caption,
                  ),
                ],
                const SizedBox(height: 30),
                if (maintenance)
                  AppButton(
                    label: 'Check again',
                    style: AppButtons.primary(),
                    // The five-minute poll clears this on its own; the button
                    // is for the driver sitting in a car who does not want to
                    // wait out the interval.
                    onPressed: () =>
                        ref.read(appGateProvider.notifier).refresh(),
                  )
                else
                  AppButton(
                    label: 'Open the store',
                    style: AppButtons.primary(),
                    onPressed: _openStore,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openStore() async {
    // The store listing, not a deep link into a specific build: the operator
    // raises the floor whenever they publish, and a pinned URL would rot.
    final uri = Uri.parse(
        'https://play.google.com/store/apps/details?id=tech.hoppin.driver');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
