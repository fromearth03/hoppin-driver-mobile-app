import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app_router.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/api/api_exception.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../data/models/onboarding_status.dart';
import '../logic/onboarding_controller.dart';

/// One step of the application, and where the driver goes to finish it.
class _Step {
  final String label;
  final bool done;
  final String? route;
  const _Step(this.label, this.done, [this.route]);
}

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Your application')),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorState(
          error: e is ApiException
              ? e
              : ApiException('INTERNAL', e.toString(), 0),
          onRetry: () =>
              ref.read(onboardingControllerProvider.notifier).refresh(),
        ),
        data: (data) {
          final onboarding = data.onboarding;
          if (onboarding == null) {
            return AppErrorState(
              error: data.error ??
                  ApiException('INTERNAL', 'no application found', 0),
              onRetry: () =>
                  ref.read(onboardingControllerProvider.notifier).refresh(),
            );
          }
          return RefreshIndicator(
            onRefresh: () =>
                ref.read(onboardingControllerProvider.notifier).refresh(),
            // A fixed checklist, not a feed: a lazy list would leave the
            // later steps out of the tree entirely on a short viewport.
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _statusCard(onboarding),
                  const SizedBox(height: 16),
                  ..._rejections(onboarding),
                  ..._steps(onboarding).map(
                    (step) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        step.done
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color:
                            step.done ? AppColors.positive : AppColors.border,
                      ),
                      title: Text(step.label, style: AppText.body),
                      trailing: step.done || step.route == null
                          ? null
                          : const Icon(Icons.chevron_right),
                      onTap: step.done || step.route == null
                          ? null
                          : () => context.push(step.route!),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _statusCard(DriverOnboarding o) {
    final steps = o.steps;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_title(o.status), style: AppText.heading),
          const SizedBox(height: 8),
          // The server's own wording, verbatim, so the app and support never
          // tell the driver different stories.
          Text(o.message, style: AppText.bodySecondary),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: steps.completed / steps.total,
            backgroundColor: AppColors.border,
          ),
          const SizedBox(height: 8),
          Text('${steps.completed} of ${steps.total} steps done',
              style: AppText.caption),
        ],
      ),
    );
  }

  static String _title(OnboardingStatus status) => switch (status) {
        OnboardingStatus.active => "You're approved",
        OnboardingStatus.restricted => 'Your account is restricted',
        OnboardingStatus.suspended => 'Your account is suspended',
        OnboardingStatus.pendingApproval => 'Under review',
      };

  /// Rejected documents lead, because they are the only thing the driver can
  /// actually act on while they wait.
  List<Widget> _rejections(DriverOnboarding o) {
    final rejected = o.rejectedDocuments;
    if (rejected.isEmpty) return const [];
    return [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.negative),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Needs your attention',
                style: AppText.body.copyWith(color: AppColors.negative)),
            const SizedBox(height: 8),
            ...rejected.map((d) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    d.rejectionReason.isEmpty
                        ? '${_documentLabel(d.type)} was rejected.'
                        : '${_documentLabel(d.type)}: ${d.rejectionReason}',
                    style: AppText.caption,
                  ),
                )),
          ],
        ),
      ),
      const SizedBox(height: 16),
    ];
  }

  static String _documentLabel(String type) =>
      type.replaceAll('_', ' ').replaceFirstMapped(
          RegExp(r'^[a-z]'), (m) => m.group(0)!.toUpperCase());

  List<_Step> _steps(DriverOnboarding o) {
    final s = o.steps;
    return [
      _Step('Your details', s.profile, Routes.personalInfo),
      _Step('Driving licence', s.license, Routes.onboardingLicense),
      _Step('Your vehicle', s.vehicle, Routes.onboardingVehicle),
      _Step('Vehicle compliance', s.vehicleCompliance,
          Routes.onboardingVehicle),
      _Step('Badge and credentials', s.credentials,
          Routes.onboardingCredentials),
      _Step('Documents', s.documents, Routes.documents),
      _Step('Payout details', s.payout, Routes.payouts),
    ];
  }
}
