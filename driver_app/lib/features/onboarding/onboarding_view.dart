import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import 'onboarding_builder.dart';
import 'onboarding_interactor.dart';
import 'onboarding_router.dart';
import 'onboarding_state.dart';
import 'steps/attachments_step.dart';
import 'steps/licence_step.dart';
import 'steps/onboarding_complete.dart';
import 'steps/personal_step.dart';
import 'steps/vehicle_step.dart';

/// The post-invite completion wizard — the Registration1–4 layout, honestly
/// re-purposed (D3).
///
/// Takes the Figma's **shape**: the centred title, the four-node step rail with
/// its labels, the field rhythm, the Previous / Next placement, the quiet
/// reassurance line at the foot.
///
/// Does NOT take the flow's **meaning**: those frames describe self-signup, and
/// `DOCS/04` forbids it. The driver reaching this view was provisioned by an
/// admin, followed an emailed invite, set a password, and is signed in. The
/// wizard completes their profile; it does not create them.
class OnboardingView extends ConsumerWidget {
  /// Creates the wizard view.
  const OnboardingView({super.key});

  static const _titles = <OnboardingStep, String>{
    OnboardingStep.personal: 'Personal Information',
    OnboardingStep.licence: 'Licences & Certificates',
    OnboardingStep.vehicle: 'Vehicle',
    OnboardingStep.attachments: 'Attachments',
    OnboardingStep.complete: 'Almost there',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    final state = ref.watch(onboardingInteractorProvider);
    final interactor = ref.read(onboardingInteractorProvider.notifier);
    final onComplete = state.step == OnboardingStep.complete;

    return Scaffold(
      backgroundColor: colors.canvas,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: hoppin.spacing.gutter,
              vertical: hoppin.spacing.xl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _titles[state.step]!,
                    textAlign: TextAlign.center,
                    style: hoppin.type.h1.copyWith(color: colors.textHi),
                  ),
                  SizedBox(height: hoppin.spacing.gutter),
                  if (!onComplete) ...[
                    _StepRail(current: state.step),
                    SizedBox(height: hoppin.spacing.xl),
                  ],
                  _stepBody(context, state, interactor),
                  SizedBox(height: hoppin.spacing.xl),
                  // The Figma's footer reassurance — kept, because it is TRUE:
                  // documents go up over TLS to a presigned slot and are
                  // reviewed by a human. It sits under every step.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 14,
                        color: colors.textMid,
                      ),
                      SizedBox(width: hoppin.spacing.xs),
                      Text(
                        'Your data is encrypted and secure',
                        style: hoppin.type.metaSmall.copyWith(
                          color: colors.textMid,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The current step. Every navigation callback is issued here, against the
  /// riblet's router extension — the steps themselves are dumb and take
  /// callbacks (riblet rule: navigation lives in `*_router.dart`).
  Widget _stepBody(
    BuildContext context,
    OnboardingState state,
    OnboardingInteractor interactor,
  ) {
    switch (state.step) {
      case OnboardingStep.personal:
        return PersonalStep(onContinue: interactor.next);
      case OnboardingStep.licence:
        return LicenceStep(
          onBack: interactor.back,
          onContinue: interactor.next,
          onOpenDocuments: context.goToDocuments,
        );
      case OnboardingStep.vehicle:
        // 🔴 `onContactSupport` is deliberately NOT wired: the driver app has
        // no support route today, and a "Contact the team" button that drops
        // the driver on go_router's error page is worse than no button. The
        // rung's copy still names WHO holds the vehicle details; the tappable
        // exit lands when a support surface does. Wiring it to a route that
        // does not resolve is precisely what router_reachability_test exists
        // to catch — see the seven dead targets it was written for.
        return VehicleStep(
          onBack: interactor.back,
          onContinue: interactor.next,
        );
      case OnboardingStep.attachments:
        return AttachmentsStep(
          onBack: interactor.back,
          onContinue: interactor.next,
          onOpenDocuments: context.goToDocuments,
        );
      case OnboardingStep.complete:
        return OnboardingComplete(
          onGoToDashboard: context.goToDashboard,
          onOpenDocuments: context.goToDocuments,
        );
    }
  }
}

/// The Figma's four-node step rail: numbered circles joined by a connector,
/// filled once reached, with the step name beneath.
class _StepRail extends StatelessWidget {
  const _StepRail({required this.current});

  final OnboardingStep current;

  static const _labels = <OnboardingStep, String>{
    OnboardingStep.personal: 'Personal',
    OnboardingStep.licence: 'Licence',
    OnboardingStep.vehicle: 'Vehicle',
    OnboardingStep.attachments: 'Attachments',
  };

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    final steps = OnboardingState.numberedSteps;
    final currentIndex = steps.indexOf(current);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (index, step) in steps.indexed) ...[
          if (index > 0)
            Expanded(
              child: Padding(
                // Align the connector with the centre of the circles above the
                // labels, not with the column as a whole.
                padding: EdgeInsets.only(top: hoppin.spacing.lg),
                child: Container(
                  height: 1,
                  color: index <= currentIndex
                      ? colors.accent
                      : colors.hairline,
                ),
              ),
            ),
          _StepNode(
            number: index + 1,
            label: _labels[step]!,
            reached: index <= currentIndex,
          ),
        ],
      ],
    );
  }
}

/// One numbered node of the rail.
class _StepNode extends StatelessWidget {
  const _StepNode({
    required this.number,
    required this.label,
    required this.reached,
  });

  final int number;
  final String label;
  final bool reached;

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: reached ? colors.accent : colors.card,
            border: Border.all(
              color: reached ? colors.accent : colors.hairline,
            ),
          ),
          child: Text(
            '$number',
            style: hoppin.type.metaSmall.copyWith(
              color: reached ? colors.onAccent : colors.textMid,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(height: hoppin.spacing.xs),
        Text(
          label,
          style: hoppin.type.metaSmall.copyWith(
            color: reached ? colors.textHi : colors.textMid,
          ),
        ),
      ],
    );
  }
}
