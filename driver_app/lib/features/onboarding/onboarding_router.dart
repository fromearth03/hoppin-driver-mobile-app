import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'onboarding_builder.dart';

/// ALL onboarding navigation lives in this file (riblet rule, DOCS/05): the
/// riblet's route contribution below, and the two exits the wizard offers. No
/// `context.go/push/pop` for onboarding concerns exists anywhere else — the
/// steps take callbacks and the view wires them here.
///
/// 🔴 **THE ROUTE IS AUTH-GATED, AND NOT BY ANYTHING IN THIS FILE.** The driver
/// AppRiblet's redirect (`router.dart`) already bounces every unauthenticated
/// visitor to `/login`, so contributing `...onboardingRoutes` to that table
/// inherits the gate for free. This matters more here than anywhere else in the
/// app: `DOCS/04` forbids driver self-registration, so a wizard reachable by a
/// signed-OUT visitor would be a signup flow in all but name. There is no such
/// thing as a driver who signed themselves up.
///
/// `no_self_signup_test.dart` pumps the REAL router at `/onboarding` with a
/// signed-out `AuthService` and asserts the login screen renders instead.
final onboardingRoutes = <RouteBase>[
  GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingRiblet()),
];

/// The wizard's exits, in one place.
extension OnboardingNav on BuildContext {
  /// Out to the documents surface (LANE A / 13-01) — the attachments step links
  /// here rather than re-implementing the list, and the complete step offers it
  /// as the place to finish anything still outstanding.
  void goToDocuments() => go('/documents');

  /// Out to the dashboard — the wizard's terminal exit.
  void goToDashboard() => go('/');
}
