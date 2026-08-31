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
import 'features/trip/ui/chat_screen.dart';
import 'features/trip/ui/trip_screen.dart';
import 'features/trips/ui/trips_screen.dart';
import 'shared/nav/app_shell.dart';
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
      if (signedIn && authRoutes.contains(path)) return Routes.home;
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
      ShellRoute(
        builder: (context, state, child) => Consumer(
          builder: (context, ref, _) => AppShell(
            currentIndex: Routes.tabs.indexOf(state.uri.path).clamp(0, 3),
            onLogout: () =>
                ref.read(authControllerProvider.notifier).signOut(),
            child: child,
          ),
        ),
        routes: [
          GoRoute(path: Routes.home, builder: (_, __) => const HomeScreen()),
          GoRoute(
              path: Routes.earnings,
              builder: (_, __) => const EarningsScreen()),
          GoRoute(
              path: Routes.statement,
              builder: (_, __) => const StatementScreen()),
          GoRoute(
              path: Routes.documents,
              builder: (_, __) => const DocumentsScreen()),
          GoRoute(path: Routes.stats, builder: (_, __) => const StatsScreen()),
          GoRoute(path: Routes.trips, builder: (_, __) => const TripsScreen()),
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
              builder: (_, __) => const ProfileScreen()),
          GoRoute(
              path: Routes.notifications,
              builder: (_, __) => const NotificationsScreen()),
          GoRoute(
              path: Routes.support, builder: (_, __) => const SupportScreen()),
          GoRoute(
              path: Routes.settings,
              builder: (_, __) => const SettingsScreen()),
          GoRoute(
              path: Routes.payouts, builder: (_, __) => const PayoutScreen()),
          GoRoute(
              path: Routes.deleteAccount,
              builder: (_, __) => const DeleteAccountScreen()),
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
        builder: (context, child) =>
            ResponsiveFrame(child: child ?? const SizedBox.shrink()),
      );
}
