import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'onboarding_interactor.dart';
import 'onboarding_state.dart';
import 'onboarding_view.dart';

/// Assembly point of the onboarding riblet (DOCS/05): declares the interactor's
/// provider so the view and the router both import the builder, never each
/// other.
final onboardingInteractorProvider =
    NotifierProvider<OnboardingInteractor, OnboardingState>(
  OnboardingInteractor.new,
);

/// The riblet's public entry widget — what the `/onboarding` route builds.
///
/// There is no router listener wrapper here (unlike the dashboard): this riblet
/// has no state→navigation translation to do. The wizard's only navigation is
/// the driver's own — forward, back, and out to `/documents` — and it is issued
/// from `onboarding_router.dart`.
class OnboardingRiblet extends ConsumerWidget {
  /// Creates the onboarding riblet.
  const OnboardingRiblet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => const OnboardingView();
}
