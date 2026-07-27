import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hoppin_driver/features/dashboard/dashboard_builder.dart';
import 'package:hoppin_driver/features/dashboard/dashboard_interactor.dart';
import 'package:hoppin_driver/features/dashboard/dashboard_state.dart';
import 'package:hoppin_driver/features/shell/driver_shell.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

/// 🔴 SIGN-OUT CONFIRMATION — RELOCATED, NOT RE-WRITTEN.
///
/// These four assertions used to live in `dashboard_view_test.dart` and drove
/// the dashboard's own `IconButton(Icons.logout)`. The chrome shell moved the
/// sign-out affordance to the top bar's avatar, so the dashboard no longer has
/// a logout icon and those tests began failing on a missing widget — the
/// classic shape of a guard that looks broken when it is merely homeless.
///
/// The BEHAVIOUR they protect has not changed and is not negotiable: a driver
/// mid-shift must never be signed out by one stray tap. So the group moved here,
/// to the widget that now owns the affordance, with the assertions intact.
///
/// Deleting them because they went red would have removed the only proof that a
/// mis-tap cannot end a shift.
void main() {
  const offlineFixture = DashboardState(
    earningsPence: 4375,
    tripCount: 5,
    onlineTime: Duration(hours: 3, minutes: 10),
    statsReady: true,
  );

  /// Pumps the real [DriverShell] over a one-branch router, which is the shape
  /// `router.dart` builds it in. The shell needs a `StatefulNavigationShell`,
  /// so it cannot be pumped bare the way the dashboard riblet can.
  Future<_StubInteractor> pumpShell(
    WidgetTester tester, {
    ThemeData? theme,
  }) async {
    final stub = _StubInteractor(offlineFixture);
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (_, _, navigationShell) =>
              DriverShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (_, _) => const SizedBox.shrink(),
                ),
              ],
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [dashboardInteractorProvider.overrideWith(() => stub)],
      child: MaterialApp.router(
        theme: theme ?? HoppinTheme.driverDark(),
        routerConfig: router,
      ),
    ));
    await tester.pump();
    return stub;
  }

  /// The avatar is the sign-out affordance. It carries a 'Sign out' tooltip so
  /// a screen reader announces what the control does before it is used — an
  /// unlabelled circle in front of an action that ends a shift is not
  /// acceptable, and the tooltip is what makes it findable here too.
  Future<void> tapAvatar(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Sign out'), warnIfMissed: true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('🔴 sign-out confirmation', () {
    testWidgets('a logout tap does NOT sign out — it asks first',
        (tester) async {
      final stub = await pumpShell(tester);

      await tapAvatar(tester);

      expect(
        stub.signOutCalls,
        0,
        reason: '🔴 a bare tap signed the driver out of a live shift with no '
            'confirmation. A mis-tap must never end a shift.',
      );
      expect(find.byType(HopPopup), findsOneWidget);
    });

    testWidgets('confirming the popup dispatches signOut exactly once',
        (tester) async {
      final stub = await pumpShell(tester);

      await tapAvatar(tester);
      await tester.tap(find.text('Log out'), warnIfMissed: true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(stub.signOutCalls, 1);
    });

    testWidgets('cancelling leaves the shift alone', (tester) async {
      final stub = await pumpShell(tester);

      await tapAvatar(tester);
      await tester.tap(find.text('Stay signed in'), warnIfMissed: true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(stub.signOutCalls, 0);
      expect(find.byType(HopPopup), findsNothing);
    });

    testWidgets('hygiene: the confirmation renders cleanly in light theme',
        (tester) async {
      await pumpShell(tester, theme: HoppinTheme.driverLight());

      await tapAvatar(tester);

      expect(find.byType(HopPopup), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('chrome', () {
    testWidgets('the avatar carries an accessible label', (tester) async {
      await pumpShell(tester);

      // The bell and the chevron always had tooltips; the avatar did not, so it
      // read as an unlabelled tappable circle in front of a shift-ending action.
      expect(find.byTooltip('Sign out'), findsOneWidget);
    });

    testWidgets('🔴 the bell draws NO badge over a gated handler',
        (tester) async {
      await pumpShell(tester);

      // Push DELIVERY is gated on the backend — the server cannot send. The
      // feed is session-local and empty on a cold pump, so the real unread
      // count is 0 and HopTopBar hides the badge at 0. A number here would be
      // a promise the platform cannot keep; a hardcoded one shipped a permanent
      // fake badge on every rider screen once.
      expect(find.text('1'), findsNothing);
      expect(find.text('2'), findsNothing);
    });
  });
}

class _StubInteractor extends DashboardInteractor {
  _StubInteractor(this.fixture);

  final DashboardState fixture;
  int signOutCalls = 0;

  @override
  DashboardState build() => fixture;

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }
}
