import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

import 'features/auth/auth_router.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/splash_screen.dart';
import 'features/call/driver_call_router.dart';
import 'features/chat/driver_chat_router.dart';
import 'features/dashboard/dashboard_router.dart';
import 'features/documents/documents_router.dart';
import 'features/earnings/earnings_router.dart';
import 'features/notifications/notifications_router.dart';
import 'features/offer_takeover/offer_takeover_router.dart';
import 'features/onboarding/onboarding_router.dart';
import 'features/profile/profile_router.dart';
import 'features/settings/settings_router.dart';
import 'features/shell/driver_shell.dart';
import 'features/shell/route_not_found_screen.dart';
import 'features/support/support_router.dart';
import 'features/trip/trip_runner_router.dart';

/// The driver app's navigation graph — the AppRiblet (DOCS/05): the
/// auth-gated redirect owns signed-in/signed-out navigation, and each
/// riblet contributes its own routes (navigation stays in `*_router.dart`
/// files). New protected routes need zero extra guard code.
///
/// Note: drivers CANNOT self-register — they're provisioned by an admin and
/// set their password from an emailed invite (docs/04). So the login screen
/// offers sign-in + set-password-from-invite, never sign-up.
final driverRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authServiceProvider);

  // Re-run `redirect` whenever Supabase auth state changes (sign-in/out,
  // token refresh) — otherwise a successful login wouldn't navigate anywhere.
  final authChanges = StreamListenable(auth.onAuthStateChange);
  ref.onDispose(authChanges.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: authChanges,
    redirect: (context, state) {
      final signedIn = auth.isSignedIn;
      final loc = state.matchedLocation;
      final onLogin = loc == '/login';
      // 🔴 `/reset` MUST survive the signed-out redirect (#49). A driver
      // clicking a password-reset link is by definition not signed in, and
      // bouncing them to the very login they cannot get past means the honest
      // GATED state is never seen. Same one-line allowance the rider makes.
      // `/splash` is allowlisted so it stays reachable pre-auth, but it is NOT
      // where signed-out traffic is sent: the destination is `/login`. Routing
      // signed-out users to a splash screen puts a wall in front of the one
      // thing they came to do, and the splash screen's own doc comment says
      // the redirect targets /login.
      final onSignedOutAuthRoute =
          onLogin || loc == '/reset' || loc == '/splash';
      if (!signedIn) return onSignedOutAuthRoute ? null : '/login';
      // A signed-in driver who somehow lands on login or splash goes home.
      if (onLogin || loc == '/splash') return '/';
      return null;
    },
    // 🔴 THE DESIGNED DEAD END. Without an errorBuilder, go_router renders its
    // own default for an unresolvable path: a grey page reading "Page not found"
    // over a raw exception dump — in a shipped app, to a driver in a moving car.
    //
    // This is NOT hypothetical, and it is MORE reachable here than in the rider
    // app, because Phase 2 is the phase that turns push ON: deep links and FCM
    // payloads carry paths from OUTSIDE the binary (and the backend has
    // published no push schema at all — #15/#16 — so `deep_link` is an
    // ASSUMPTION we parse defensively). Route hygiene inside `lib/` cannot
    // constrain a path the server sends.
    //
    // `router_reachability_test.dart` proves every `context.go` literal in
    // `lib/` currently resolves. This is what stands behind the next one that
    // does not.
    errorBuilder: (_, _) => const DriverRouteNotFoundScreen(),
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const DriverSplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const DriverLoginScreen()),
      ...onboardingRoutes,

      // ── The dashboard shell ────────────────────────────────────────────
      // Single-branch StatefulShellRoute: provides the persistent floating
      // chrome (HopTopBar + bell → /notifications) over the dashboard body.
      // The trip, offer, chat, and call routes are TOP-LEVEL (outside the
      // shell) so they cover the chrome with no top bar of their own.
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigationShell) =>
            DriverShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: dashboardRoutes,
          ),
        ],
      ),

      // ── Top-level pushes OVER the shell ───────────────────────────────
      // Everything below renders its OWN HopTopBar, so these stay OUTSIDE the
      // shell branch. Moving any of them inside it draws two top bars.
      ...documentsRoutes,
      ...earningsRoutes,
      ...offerRoutes,
      ...tripRoutes,
      ...driverChatRoutes,
      ...driverCallRoutes,
      ...supportRoutes,
      ...notificationsRoutes,
      ...profileRoutes,
      ...settingsRoutes,
      ...authRoutes,
    ],
  );
});
