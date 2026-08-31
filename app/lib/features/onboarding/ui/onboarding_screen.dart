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
import 'widgets/wizard_scaffold.dart';

/// One step of the application, and where the driver goes to finish it.
class _Step {
  final String label;
  final bool done;
  final String? route;
  const _Step(this.label, this.done, [this.route]);
}

/// Step 4 of 4: the approval gate.
///
/// The design's fourth screen is a "Thank You — The Driver has been added."
/// confirmation. That is the admin panel's flow, where an operator really has
/// just added a driver. A self-registering driver has done no such thing:
/// GET /drivers/me/onboarding comes back pending_approval until a human
/// approves them, and until then they cannot go online. A tick and a thank
/// you would tell them they are finished when they are not, so the step keeps
/// the design's frame — same header pill, same 1-2-3-4 rail with 4 lit — and
/// puts the real status inside it.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingControllerProvider);

    return state.when(
      loading: () => const _Frame(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 64),
            child: CircularProgressIndicator(),
          ),
        ),
      ),
      error: (e, _) => _Frame(
        child: AppErrorState(
          error:
              e is ApiException ? e : ApiException('INTERNAL', e.toString(), 0),
          onRetry: () =>
              ref.read(onboardingControllerProvider.notifier).refresh(),
        ),
      ),
      data: (data) {
        final onboarding = data.onboarding;
        if (onboarding == null) {
          return _Frame(
            child: AppErrorState(
              error: data.error ??
                  ApiException('INTERNAL', 'no application found', 0),
              onRetry: () =>
                  ref.read(onboardingControllerProvider.notifier).refresh(),
            ),
          );
        }
        return _Frame(
          onRefresh: () =>
              ref.read(onboardingControllerProvider.notifier).refresh(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _statusCard(onboarding),
              const SizedBox(height: 16),
              ..._rejections(onboarding),
              // A Material of its own: a ListTile paints its ink on the
              // nearest Material, and the card behind it is a plain
              // DecoratedBox, which would swallow both the fill and the
              // splash.
              Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ..._steps(onboarding).map(
                        (step) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            step.done
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color: step.done
                                ? AppColors.positive
                                : AppColors.border,
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
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statusCard(DriverOnboarding o) {
    final steps = o.steps;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: _accent(o.status).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(_icon(o.status), color: _accent(o.status), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text(_title(o.status), style: AppText.title)),
            ],
          ),
          const SizedBox(height: 14),
          // The server's own wording, verbatim, so the app and support never
          // tell the driver different stories.
          Text(o.message, style: AppText.bodySecondary),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: steps.completed / steps.total,
              minHeight: 8,
              backgroundColor: AppColors.border,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 10),
          Text('${steps.completed} of ${steps.total} steps done',
              style: AppText.caption),
        ],
      ),
    );
  }

  static Color _accent(OnboardingStatus status) => switch (status) {
        OnboardingStatus.active => AppColors.positive,
        OnboardingStatus.restricted => AppColors.warning,
        OnboardingStatus.suspended => AppColors.negative,
        OnboardingStatus.pendingApproval => AppColors.warning,
      };

  static IconData _icon(OnboardingStatus status) => switch (status) {
        OnboardingStatus.active => Icons.check_circle_outline,
        OnboardingStatus.restricted => Icons.error_outline,
        OnboardingStatus.suspended => Icons.block_outlined,
        OnboardingStatus.pendingApproval => Icons.hourglass_empty,
      };

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
          borderRadius: BorderRadius.circular(16),
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

/// The wizard chrome step 4 shares with steps 1-3, with the pull-to-refresh
/// the review screen needs wrapped inside it. Not [WizardScaffold] directly:
/// this step scrolls a refreshable list rather than a form, and the driver
/// has no "Save & Continue" left to press — an admin has the next move.
class _Frame extends StatelessWidget {
  final Widget child;
  final Future<void> Function()? onRefresh;

  const _Frame({required this.child, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    // A fixed checklist, not a feed: a lazy list would leave the later steps
    // out of the tree entirely on a short viewport.
    Widget body = SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const WizardSteps(current: kWizardSteps),
          const SizedBox(height: 28),
          child,
          const SizedBox(height: 24),
          const WizardFooterNote(),
        ],
      ),
    );
    if (onRefresh != null) {
      body = RefreshIndicator(onRefresh: onRefresh!, child: body);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const WizardHeader(title: 'Your application'),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}
