import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/error_codes.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/app_loading.dart';
import '../data/models/payout_status.dart';
import '../data/payout_repository.dart';

final payoutStatusProvider = FutureProvider<PayoutStatus>((ref) async {
  final result = await ref.watch(payoutRepositoryProvider).status();
  return result.valueOrNull ?? const PayoutStatus();
});

/// Payout setup. The app shows status and opens Stripe's hosted onboarding;
/// it never asks for a bank account or a card itself.
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
      appBar: AppBar(title: const Text('Payments')),
      body: async.when(
        loading: () => const AppLoading(),
        error: (e, _) => Center(child: Text('$e', style: AppText.body)),
        data: (status) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          status.isReady
                              ? Icons.check_circle
                              : Icons.info_outline,
                          color: status.isReady
                              ? AppColors.positive
                              : AppColors.warning,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            status.isReady
                                ? 'Ready to be paid'
                                : status.connected
                                    ? 'Setup in review'
                                    : 'Payment setup needed',
                            style: AppText.heading,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      status.isReady
                          ? 'Your payout account is set up. Your operator issues payouts on their usual schedule.'
                          : status.connected
                              ? "We're waiting on Stripe to finish checking your details. Nothing for you to do."
                              : 'Set up your payout account so your earnings can reach you.',
                      style: AppText.bodySecondary,
                    ),
                    if (!status.isReady && !status.connected) ...[
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _busy ? null : _onboard,
                        child: const Text('Set up payouts'),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'You will be taken to Stripe to enter your bank details securely.',
                        style: AppText.caption,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
