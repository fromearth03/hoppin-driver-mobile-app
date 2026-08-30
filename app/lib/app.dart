import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/logic/auth_controller.dart';
import 'features/auth/ui/forgot_password_screen.dart';
import 'features/auth/ui/reset_password_screen.dart';
import 'features/auth/ui/sign_in_screen.dart';
import 'shared/nav/app_shell.dart';

/// Placeholder bodies. Each is replaced by its real screen in a later batch.
Widget _placeholder(String name) =>
    Center(child: Text('$name — not built yet'));

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
        Routes.forgotPassword,
        Routes.resetPassword,
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
      GoRoute(
          path: Routes.forgotPassword,
          builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(
          path: Routes.resetPassword,
          builder: (_, __) => const ResetPasswordScreen()),
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
          GoRoute(path: Routes.home, builder: (_, __) => _placeholder('Home')),
          GoRoute(
              path: Routes.earnings,
              builder: (_, __) => _placeholder('Earnings')),
          GoRoute(
              path: Routes.documents,
              builder: (_, __) => _placeholder('Documents')),
          GoRoute(
              path: Routes.stats, builder: (_, __) => _placeholder('Stats')),
          GoRoute(
              path: Routes.trips, builder: (_, __) => _placeholder('Trips')),
          GoRoute(
              path: Routes.personalInfo,
              builder: (_, __) => _placeholder('Personal Information')),
          GoRoute(
              path: Routes.notifications,
              builder: (_, __) => _placeholder('Notifications')),
          GoRoute(
              path: Routes.support,
              builder: (_, __) => _placeholder('Support')),
          GoRoute(
              path: Routes.settings,
              builder: (_, __) => _placeholder('Settings')),
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
      );
}
