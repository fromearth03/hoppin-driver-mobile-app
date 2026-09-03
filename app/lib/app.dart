import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/logic/auth_controller.dart';
import 'features/auth/ui/expired_link_screen.dart';
import 'features/auth/ui/forgot_password_screen.dart';
import 'features/auth/ui/reset_password_screen.dart';
import 'features/auth/ui/sign_in_screen.dart';
import 'features/documents/ui/documents_screen.dart';
import 'features/earnings/ui/earnings_screen.dart';
import 'features/home/ui/home_screen.dart';
import 'features/notifications/ui/notifications_screen.dart';
import 'features/payment/ui/payout_screen.dart';
import 'features/profile/ui/delete_account_screen.dart';
import 'features/profile/ui/profile_screen.dart';
import 'features/profile/ui/settings_screen.dart';
import 'features/statement/ui/statement_screen.dart';
import 'features/onboarding/ui/credentials_screen.dart';
import 'features/onboarding/ui/license_screen.dart';
import 'features/onboarding/ui/onboarding_screen.dart';
import 'features/onboarding/ui/sign_up_screen.dart';
import 'features/onboarding/ui/vehicle_screen.dart';
import 'features/stats/ui/stats_screen.dart';
import 'features/support/ui/support_screen.dart';
import 'features/support/ui/ticket_thread_screen.dart';
import 'features/trip/ui/chat_screen.dart';
import 'features/trip/ui/trip_screen.dart';
import 'features/trips/ui/trips_screen.dart';
import 'core/auth/session_lost.dart';
import 'features/auth/ui/session_taken_screen.dart';
import 'features/gate/logic/app_gate_controller.dart';
import 'features/gate/ui/app_gate_screen.dart';
import 'shared/nav/app_shell.dart';
import 'shared/nav/tab_transition.dart';
import 'features/home/logic/home_controller.dart';
import 'features/earnings/logic/earnings_controller.dart';
import 'features/statement/logic/statement_controller.dart';
import 'features/documents/logic/documents_controller.dart';
import 'features/stats/logic/stats_controller.dart';
import 'features/trips/logic/trips_controller.dart';
import 'features/notifications/logic/notifications_controller.dart';
import 'features/profile/logic/profile_controller.dart';
import 'shared/widgets/revalidate_on_visit.dart';
import 'shared/widgets/scroll_edge_blur.dart';

import 'shared/responsive_frame.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Routes.home,
    // Re-evaluates the redirect whenever auth state changes, so a token
    // expiring mid-session bounces the driver to sign-in rather than
    // leaving them on a screen whose calls all 401.
    refreshListenable: _AuthListenable(ref),
    redirect: (context, state) {
      final status = ref.read(authControllerProvider);
      final path = state.uri.path;
      const authRoutes = {
        Routes.signIn,
        Routes.signUp,
        Routes.forgotPassword,
        Routes.resetPassword,
        Routes.expiredLink,
      };

      // The SDK resolves any stored session during Supabase.initialize, so
      // by the time the router runs the status is already settled.
      if (status == AuthStatus.unknown) return null;

      final signedIn = status == AuthStatus.signedIn;
      if (!signedIn && !authRoutes.contains(path)) return Routes.signIn;
      // Expired-link is exempt from the signed-in bounce: opening a stale
      // recovery email leaves the SDK holding a recovery session, so the
      // driver IS signed in at the exact moment this screen is needed.
      if (signedIn &&
          authRoutes.contains(path) &&
          path != Routes.expiredLink) {
        return Routes.home;
      }
      return null;
    },
    routes: [
      GoRoute(path: Routes.signIn, builder: (_, __) => const SignInScreen()),
      GoRoute(path: Routes.signUp, builder: (_, __) => const SignUpScreen()),
      // Outside the shell: a driver still under review has no bottom nav to
      // sit in, and every tab behind it would refuse them anyway.
      GoRoute(
          path: Routes.onboarding,
          builder: (_, __) => const OnboardingScreen()),
      GoRoute(
          path: Routes.onboardingLicense,
          builder: (_, __) => const LicenseScreen()),
      GoRoute(
          path: Routes.onboardingVehicle,
          builder: (_, __) => const VehicleScreen()),
      GoRoute(
          path: Routes.onboardingCredentials,
          builder: (_, __) => const CredentialsScreen()),
      GoRoute(
          path: Routes.forgotPassword,
          builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(
          path: Routes.resetPassword,
          builder: (_, __) => const ResetPasswordScreen()),
      GoRoute(
          path: Routes.expiredLink,
          builder: (_, __) => const ExpiredLinkScreen()),
      GoRoute(
          path: Routes.sessionTaken,
          builder: (_, __) => const SessionTakenScreen()),
      ShellRoute(
        builder: (context, state, child) => Consumer(
          builder: (context, ref, _) => AppShell(
            currentIndex: Routes.tabs.indexOf(state.uri.path).clamp(0, 3),
            currentPath: state.uri.path,
            onLogout: () =>
                ref.read(authControllerProvider.notifier).signOut(),
            // The slide lives here rather than on each tab's pageBuilder:
            // the shell sees every navigation through it, so one place knows
            // both where the driver was and where they are going.
            child: TabSwitcher(path: state.uri.path, child: child),
          ),
        ),
        routes: [
          GoRoute(path: Routes.home, builder: (_, __) => ScrollEdgeBlur(child: RevalidateOnVisit(revalidate: (ref) => revalidateIfLoaded(ref, homeControllerProvider, ref.read(homeControllerProvider.notifier).refresh), child: const HomeScreen()))),
          GoRoute(
              path: Routes.earnings,
              builder: (_, __) => ScrollEdgeBlur(child: RevalidateOnVisit(revalidate: (ref) => revalidateIfLoaded(ref, earningsControllerProvider, ref.read(earningsControllerProvider.notifier).refresh), child: const EarningsScreen()))),
          GoRoute(
              path: Routes.statement,
              builder: (_, __) => ScrollEdgeBlur(child: RevalidateOnVisit(revalidate: (ref) => revalidateIfLoaded(ref, statementControllerProvider, ref.read(statementControllerProvider.notifier).refresh), child: const StatementScreen()))),
          GoRoute(
              path: Routes.documents,
              builder: (_, __) => ScrollEdgeBlur(child: RevalidateOnVisit(revalidate: (ref) => revalidateIfLoaded(ref, documentsControllerProvider, ref.read(documentsControllerProvider.notifier).refresh), child: const DocumentsScreen()))),
          GoRoute(path: Routes.stats, builder: (_, __) => ScrollEdgeBlur(child: RevalidateOnVisit(revalidate: (ref) => revalidateIfLoaded(ref, statsControllerProvider, ref.read(statsControllerProvider.notifier).refresh), child: const StatsScreen()))),
          GoRoute(path: Routes.trips, builder: (_, __) => ScrollEdgeBlur(child: RevalidateOnVisit(revalidate: (ref) => revalidateIfLoaded(ref, tripsControllerProvider, ref.read(tripsControllerProvider.notifier).refresh), child: const TripsScreen()))),
          GoRoute(
            path: '${Routes.trip}/:rideId',
            builder: (_, state) =>
                TripScreen(rideId: state.pathParameters['rideId']!),
          ),
          GoRoute(
            path: '${Routes.trip}/:rideId/chat',
            builder: (_, state) =>
                ChatScreen(rideId: state.pathParameters['rideId']!),
          ),
          GoRoute(
              path: Routes.personalInfo,
              builder: (_, __) => ScrollEdgeBlur(child: RevalidateOnVisit(revalidate: (ref) => revalidateIfLoaded(ref, profileProvider, () => ref.invalidate(profileProvider)), child: const ProfileScreen()))),
          GoRoute(
              path: Routes.notifications,
              builder: (_, __) => ScrollEdgeBlur(child: RevalidateOnVisit(revalidate: (ref) => revalidateIfLoaded(ref, notificationsControllerProvider, ref.read(notificationsControllerProvider.notifier).refresh), child: const NotificationsScreen()))),
          GoRoute(
              path: Routes.support,
              builder: (_, state) => ScrollEdgeBlur(
                  child: SupportScreen(
                      initialTab: state.uri.queryParameters['tab'] ==
                              'complaints'
                          ? 1
                          : 0))),
          GoRoute(
            path: '${Routes.supportTicket}/:id',
            builder: (_, state) => ScrollEdgeBlur(
                child:
                    TicketThreadScreen(ticketId: state.pathParameters['id']!)),
          ),
          GoRoute(
              path: Routes.settings,
              builder: (_, __) => const ScrollEdgeBlur(child: SettingsScreen())),
          GoRoute(
              path: Routes.payouts, builder: (_, __) => ScrollEdgeBlur(child: RevalidateOnVisit(revalidate: (ref) => revalidateIfLoaded(ref, payoutStatusProvider, () => ref.invalidate(payoutStatusProvider)), child: const PayoutScreen()))),
          GoRoute(
              path: Routes.deleteAccount,
              builder: (_, __) =>
                  const ScrollEdgeBlur(child: DeleteAccountScreen())),
        ],
      ),
    ],
  );
});

/// Bridges Riverpod auth state to GoRouter's Listenable-based refresh.
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    ref.listen(authControllerProvider, (_, __) => notifyListeners());
  }
}

class HoppinDriverApp extends ConsumerWidget {
  const HoppinDriverApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
        title: 'Hoppin Driver',
        theme: appTheme(),
        routerConfig: ref.watch(routerProvider),
        debugShowCheckedModeBanner: false,
        // Wraps the navigator itself, so dialogs and sheets stay inside the
        // phone column on wide screens rather than spanning a desktop.
        //
        // The gate sits outside the router on purpose: maintenance has to be
        // sayable to a driver who is not signed in, and a forced update has
        // to hold on every route rather than on the ones someone remembered
        // to guard.
        builder: (context, child) => ResponsiveFrame(
          child: _Gated(child: child ?? const SizedBox.shrink()),
        ),
      );
}

/// Puts the maintenance or force-update wall in front of the whole app.
///
/// Anything other than a resolved, blocking status renders the app: a gate
/// that is still loading, or one whose read failed, must never stop a driver
/// working. The cost of a missed gate is one stale client; the cost of a
/// false one is a fleet that cannot earn.
class _Gated extends ConsumerWidget {
  final Widget child;

  const _Gated({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Losing the session outranks the launch gate: nothing can load once
    // every call is 401, so there is no point showing a maintenance notice
    // over a driver who is no longer signed in.
    if (ref.watch(sessionLostProvider)) return const SessionTakenScreen();

    final status = ref.watch(appGateProvider).value;
    if (status != null && status.blocks) {
      return AppGateScreen(status: status);
    }
    return child;
  }
}
