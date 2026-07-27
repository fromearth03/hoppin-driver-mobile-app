import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/dashboard/dashboard_builder.dart';
import 'package:hoppin_driver/features/dashboard/dashboard_interactor.dart';
import 'package:hoppin_driver/features/dashboard/dashboard_state.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

/// View smoke layer (riblet testing contract, DOCS/05): state in → widgets
/// out against fixed fixtures, intents dispatched exactly once. The
/// interactor is stubbed with a Notifier subclass whose build() returns the
/// fixture. Bounded pumps only — GoButton loops and MoneyTicker settles.
void main() {
  const offlineFixture = DashboardState(
    earningsPence: 4375,
    tripCount: 5,
    onlineTime: Duration(hours: 3, minutes: 10),
    statsReady: true,
  );

  Future<_StubInteractor> pumpDashboard(
    WidgetTester tester,
    DashboardState fixture, {
    ThemeData? theme,
  }) async {
    final stub = _StubInteractor(fixture);
    await tester.pumpWidget(ProviderScope(
      overrides: [dashboardInteractorProvider.overrideWith(() => stub)],
      child: MaterialApp(
        theme: theme ?? HoppinTheme.driverDark(),
        home: const DashboardRiblet(),
      ),
    ));
    await tester.pump();
    return stub;
  }

  testWidgets('offline: GO canvas over the seeded trio, no quiet affordance',
      (tester) async {
    await pumpDashboard(tester, offlineFixture);

    expect(find.text('Ready to drive?'), findsOneWidget);
    // The composed idle state: a quiet neutral pill names the pool state.
    expect(find.text('Off duty'), findsOneWidget);
    final go = tester.widget<GoButton>(find.byType(GoButton));
    expect(go.online, isFalse);
    expect(go.busy, isFalse);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('£43.75'), findsOneWidget);
    expect(find.text('5 trips'), findsOneWidget);
    expect(find.text('3h 10m'), findsOneWidget);
    expect(find.text('Go offline'), findsNothing);
  });

  testWidgets('online: quiet header and the Go offline text affordance',
      (tester) async {
    await pumpDashboard(
      tester,
      offlineFixture.copyWith(phase: DashboardPhase.online),
    );

    expect(find.text("You're online"), findsOneWidget);
    expect(find.text('Finding trips nearby'), findsOneWidget);
    // Waiting-for-trips reads composed: success pill + copy, never empty.
    expect(find.text('On duty'), findsOneWidget);
    expect(
      tester.widget<StatusPill>(find.byType(StatusPill)).tone,
      PillTone.success,
    );
    expect(tester.widget<GoButton>(find.byType(GoButton)).online, isTrue);
    expect(find.text('Go offline'), findsOneWidget);
  });

  testWidgets('GO tap dispatches goOnline exactly once', (tester) async {
    final stub = await pumpDashboard(tester, offlineFixture);

    await tester.tap(find.byType(GoButton));
    await tester.pump(const Duration(milliseconds: 150));
    expect(stub.goOnlineCalls, 1);
    expect(stub.goOfflineCalls, 0);
  });

  testWidgets('absorb: chip rises and the total ticks up to the new figure',
      (tester) async {
    await pumpDashboard(
      tester,
      offlineFixture.copyWith(
        earningsPence: 5014,
        tripCount: 6,
        recentEarnedPence: 639,
      ),
    );

    // The delta chip is on screen and the remount-seeded ticker starts
    // from the pre-absorb total (W2: fromPence renders the tick-up).
    expect(find.text('+£6.39'), findsOneWidget);
    expect(find.text('£43.75'), findsOneWidget);

    // The §5 landing hold: 250ms in (inside the 300ms tileAbsorbDelay)
    // the total still reads the pre-absorb figure — the driver lands
    // first, then witnesses the tick.
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('£43.75'), findsOneWidget);

    // Past the 300ms delay, the 600ms rise-and-fade, and the 700ms tick —
    // bounded pumps.
    for (var i = 0; i < 9; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('£50.14'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('error: friendly HopBanner, never a red screen', (tester) async {
    const message = 'Something went wrong. Please try again.';
    await pumpDashboard(tester, offlineFixture.copyWith(error: message));

    expect(find.text(message), findsOneWidget);
    expect(find.byType(HopBanner), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('live degrade: quiet placeholders before the first telemetry',
      (tester) async {
    await pumpDashboard(tester, const DashboardState());

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    expect(find.text('— trips'), findsOneWidget);
    expect(find.text('—h —m'), findsOneWidget);
    // Graceful degradation is never a spinner-centred screen.
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  /// 🔴 SIGN-OUT IS CONFIRMED, NEVER IMMEDIATE.
  ///
  /// The logout control sat in the top chrome as a bare IconButton wired
  /// straight to `signOut()` — one stray tap, a hand steadying the phone
  /// against the wheel, and a driver is signed out of a LIVE SHIFT. There is no
  /// undo: the auth redirect fires, presence drops, the heartbeat stops and
  /// dispatch loses them. The recovery is a full re-login, in a car park, at
  /// exactly the moment a driver can least afford it.
  ///
  /// So the tap ASKS. The destructive path is one deliberate confirmation away,
  /// and the cancel path must leave the shift completely untouched.
  // 🔴 The sign-out confirmation group MOVED to
  // .
  //
  // The chrome shell owns the sign-out affordance now (the top bar's avatar),
  // so the dashboard has no logout control to drive and these assertions had
  // nothing to tap. They were RELOCATED, not deleted: they are the only proof
  // that a stray tap cannot end a driver's shift.

  testWidgets('hygiene: no Opacity widget anywhere in the riblet subtree',
      (tester) async {
    await pumpDashboard(
      tester,
      offlineFixture.copyWith(
        earningsPence: 5014,
        recentEarnedPence: 639,
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.descendant(
        of: find.byType(DashboardRiblet),
        matching: find.byType(Opacity),
      ),
      findsNothing,
    );
  });

  testWidgets('hygiene: light theme renders the offline canvas cleanly',
      (tester) async {
    await pumpDashboard(
      tester,
      offlineFixture,
      theme: HoppinTheme.driverLight(),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Ready to drive?'), findsOneWidget);
    expect(find.text('£43.75'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

/// Fixture-holding stub: build() returns the fixed state (the established
/// Riverpod 3 pattern) and the intent methods record instead of acting.
class _StubInteractor extends DashboardInteractor {
  _StubInteractor(this.fixture);

  final DashboardState fixture;
  int goOnlineCalls = 0;
  int goOfflineCalls = 0;
  int signOutCalls = 0;

  @override
  DashboardState build() => fixture;

  @override
  Future<void> goOnline() async {
    goOnlineCalls++;
  }

  @override
  Future<void> goOffline() async {
    goOfflineCalls++;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }
}
