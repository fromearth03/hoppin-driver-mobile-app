import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../shared/nav/app_shell.dart';

import '../../../core/api/error_codes.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../features/profile/ui/widgets/settings_card.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../../shared/widgets/async_view.dart';
import '../data/models/payout_status.dart';
import '../data/payout_repository.dart';

final payoutStatusProvider = FutureProvider<PayoutStatus>((ref) async {
  final result = await ref.watch(payoutRepositoryProvider).status();
  return result.valueOrNull ?? const PayoutStatus();
});

/// Payout setup. The app shows status and opens Stripe's hosted onboarding;
/// it never asks for a bank account or a card itself.
///
/// This screen stands in for the Figma's "Payment Methods" and "Add Payment
/// Methods" pair, neither of which is built:
///
///  * All four `/me/payment-methods` routes are rider-only in the Go source —
///    a driver calling them gets a 403, so the list would always be empty and
///    the add form would always fail.
///  * Drivers are paid OUT through Stripe Connect, not charged, so a saved
///    card is the wrong instrument entirely.
///  * The design's card-capture form (PAN, holder name, expiry, CVV) would put
///    the app in PCI scope. Stripe's hosted page keeps it at SAQ-A, which is
///    why the button below leaves the app rather than collecting anything.
///
/// There is no "Retry payout" action anywhere here: payouts are administered
/// on the operator's schedule and no endpoint lets a driver trigger one, so a
/// button would be a lie about what the driver controls.
class PayoutScreen extends ConsumerStatefulWidget {
  const PayoutScreen({super.key});

  @override
  ConsumerState<PayoutScreen> createState() => _PayoutScreenState();
}

class _PayoutScreenState extends ConsumerState<PayoutScreen> {
  bool _busy = false;

  Future<void> _onboard() async {
    setState(() => _busy = true);
    final result = await ref.read(payoutRepositoryProvider).startOnboarding();
    if (!mounted) return;
    setState(() => _busy = false);

    final failure = result.errorOrNull;
    if (failure != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errorCopy(failure))));
      return;
    }

    final onboarding = result.valueOrNull!;
    if (onboarding.alreadyEnabled) {
      ref.invalidate(payoutStatusProvider);
      return;
    }
    final uri = Uri.tryParse(onboarding.onboardingUrl);
    if (uri == null || onboarding.onboardingUrl.isEmpty) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(payoutStatusProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: settingsAppBar(context, 'Payments'),
      body: AsyncView(
        value: async,
        loading: () => const SkeletonList(),
        error: (e, _) => Center(child: Text('$e', style: AppText.body)),
        data: (v, _) => _body(v),
      ),
    );
  }

  Widget _body(PayoutStatus status) {
    final (icon, tint, title, detail) = status.isReady
        ? (
            Icons.check_circle,
            AppColors.positive,
            'Ready to be paid',
            'Your payout account is set up. Your operator issues payouts on '
                'their usual schedule.',
          )
        : status.connected
            ? (
                Icons.access_time_filled,
                AppColors.warning,
                'Setup in review',
                "We're waiting on Stripe to finish checking your details. "
                    'Nothing for you to do.',
              )
            : (
                Icons.info_outline,
                AppColors.negative,
                'Payment setup needed',
                'Set up your payout account so your earnings can reach you.',
              );

    return SingleChildScrollView(
      padding: const EdgeInsets.only(
          top: 8, bottom: AppShell.bottomClearance),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingsCard(
            title: 'Payout account',
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      decoration: BoxDecoration(
                        color: tint.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(icon, size: 24, color: tint),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: AppText.body.copyWith(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                      color: tint),
                                ),
                                const SizedBox(height: 6),
                                Text(detail, style: AppText.bodySecondary),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // The account reference, so a driver on the phone to
                    // support can say WHICH account, and so a connected
                    // screen shows something concrete rather than only a
                    // green tick.
                    if (status.accountId != null) ...[
                      const SizedBox(height: 16),
                      _AccountRow(accountId: status.accountId!),
                    ],
                    const SizedBox(height: 20),
                    // Always offered, in both directions. A connected driver
                    // previously got a status page with no actions at all —
                    // no way to change the bank account their money lands in,
                    // which is the one thing this screen exists to control.
                    AppButton(
                      label: status.connected
                          ? 'Manage payout account'
                          : 'Set up payouts',
                      busy: _busy,
                      onPressed: _onboard,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      status.connected
                          ? 'Opens Stripe, where you can change your bank '
                              'account, update your details or check what '
                              'they still need from you.'
                          : 'You will be taken to Stripe to enter your bank '
                              'details securely.',
                      style: AppText.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SettingsCard(
            title: 'How you get paid',
            children: [
              _InfoRow(
                icon: Icons.account_balance_outlined,
                label: 'Bank transfer via Stripe',
                detail:
                    'Your earnings are transferred to the bank account you '
                    'gave Stripe. Hoppin never holds your bank details.',
              ),
              _InfoRow(
                icon: Icons.event_outlined,
                label: 'On your operator’s schedule',
                detail:
                    'Your operator decides when payouts run. You can see past '
                    'payouts on the Earnings screen.',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A short explainer row inside a [SettingsCard].
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String detail;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 24, color: AppColors.textPrimary),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppText.body.copyWith(fontSize: 17)),
                  const SizedBox(height: 4),
                  Text(detail, style: AppText.caption),
                ],
              ),
            ),
          ],
        ),
      );
}

/// The connected Stripe account, shown as a reference rather than a secret.
///
/// The id is not sensitive — it identifies the account, it does not authorise
/// anything — and support asks for it, so a driver who can read it off their
/// own screen is not stuck on a call trying to describe which account they
/// mean.
class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.accountId});

  final String accountId;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.account_balance_outlined,
                size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Connected account', style: AppText.caption),
                  const SizedBox(height: 2),
                  Text(
                    accountId,
                    style: AppText.body.copyWith(
                      fontSize: 14,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
