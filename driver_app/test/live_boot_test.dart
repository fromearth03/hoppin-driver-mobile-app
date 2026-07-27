import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hoppin_driver/features/chat/driver_chat_view.dart';
import 'package:hoppin_driver/features/trip/trip_runner_state.dart';
import 'package:hoppin_driver/router.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:hoppin_ui/hoppin_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// DS-04 GROUP D — LIVE REACHABILITY.
///
/// 🔴 THE INVARIANT THAT ACTUALLY PROTECTS THE DRIVER: **every surface boots
/// over LIVE-SHAPED repositories without throwing, renders something, and
/// offers a way OFF the screen.**
///
/// Groups A/B/C prove the seams are shaped, ledgered and disclosed. None of
/// them proves a driver can actually LEAVE. That gap is not theoretical: the
/// #7 seam (`todayStats()` → null on every live request) was correctly SEAMED,
/// correctly ledgered and correctly disclosed — and it still stranded a driver
/// on a dead completed-trip card after every single trip, because the only exit
/// was gated on a figure the live backend never sends. Every group was green.
/// The driver was trapped.
///
/// So: LIVE-SHAPED. These repositories answer exactly what the real backend
/// answers — every capability seam returns `null`, because that is what the
/// live server does today. A fake that returns a cheerful `TripRiderContext`
/// tests a backend we do not have.
///
/// **A terminal state with no exit is a driver parked in a live car with a live
/// job and no options.** This phase adds five new terminal states, and this file
/// is where each one has to prove it lets go.
void main() {
  /// The real router, built exactly as the app builds it — never a test-local
  /// GoRouter. A test that builds its own router proves its own router works;
  /// it is structurally incapable of noticing that production lacks the route.
  /// (That is not hypothetical — see `router_reachability_test.dart`: seven
  /// such targets shipped in the rider app behind a green suite.)
  /// The live container for the surface currently under test — captured so
  /// [unmount] can dispose it INSIDE the test body.
  late ProviderContainer live;

  Future<GoRouter> bootAt(WidgetTester tester, String path) async {
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(_SignedInAuthService()),
        ridesRepositoryProvider.overrideWithValue(_LiveShapedRidesRepository()),
        driverRepositoryProvider
            .overrideWithValue(_LiveShapedDriverRepository()),
      ],
    );
    live = container;

    final router = container.read(driverRouterProvider);
    router.go(path);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: HoppinTheme.driverDark(),
          routerConfig: router,
        ),
      ),
    );
    // Bounded pumps — never pumpAndSettle: the surfaces poll on timers, and
    // settle-detection would stall forever waiting for a world that never
    // quiesces.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 350));
    }

    return router;
  }

  /// Unmount the tree, THEN dispose the container — both inside the test body.
  ///
  /// These surfaces are long-lived pollers BY DESIGN — the chat's 3s tick, the
  /// runner's waiting clock — and a live driver's chat is SUPPOSED to keep
  /// polling. A pending timer here is a harness artifact, not a product defect.
  ///
  /// 🔴 BOTH STEPS, IN THIS ORDER, AND NEITHER IS OPTIONAL. Unmounting alone is
  /// not enough: `map_interactor.dart:75` starts its `Timer.periodic` on the
  /// PROVIDER, not the widget, so it outlives the tree entirely and dies only
  /// when the container is disposed. And this must run INSIDE the test body —
  /// an `addTearDown` fires after the binding has already checked invariants,
  /// so the complaint drowns every real assertion in the file.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 4));
    live.dispose();
    await tester.pump();
  }

  /// Every control a driver could actually press to LEAVE — a real, enabled,
  /// hit-testable affordance. A disabled button is not an exit, and neither is
  /// a widget that renders off-screen.
  ///
  /// This counts ENABLED interactive elements, because an exit the driver
  /// cannot press is exactly the trap this file exists to catch.
  int liveExitCount(WidgetTester tester) {
    var exits = 0;
    for (final element in find.byType(HopButton).evaluate()) {
      final button = element.widget as HopButton;
      if (button.onPressed != null) exits++;
    }
    // The top bar's back chevron is a genuine exit too — it is how a driver
    // gets off the chat and call surfaces.
    for (final element in find.byType(IconButton).evaluate()) {
      final button = element.widget as IconButton;
      if (button.onPressed != null) exits++;
    }
    for (final element in find.byType(TextButton).evaluate()) {
      final button = element.widget as TextButton;
      if (button.onPressed != null) exits++;
    }
    for (final element in find.byType(InkWell).evaluate()) {
      final inkwell = element.widget as InkWell;
      if (inkwell.onTap != null) exits++;
    }
    return exits;
  }

  // ── THE NEW ROUTES THIS PHASE ADDED ──────────────────────────────────────
  //
  // /trip/:id/chat (15-01) and /trip/:id/call (15-02). Both are reached from
  // the runner card's comms row, mid-trip, by a driver who then has to get back
  // to the job.

  for (final route in const ['/trip/ride-1/chat', '/trip/ride-1/call']) {
    testWidgets('$route boots over live-shaped repos WITHOUT throwing',
        (tester) async {
      await bootAt(tester, route);
      final thrown = tester.takeException();
      await unmount(tester);

      expect(thrown, isNull,
          reason:
              '$route threw while booting over LIVE-shaped repositories — the '
              'exact shape the real backend answers today (every capability '
              'seam null). A surface that only survives a generous fake is a '
              'surface that crashes on a driver mid-shift.');
    });

    testWidgets('$route renders a NON-EMPTY surface on live', (tester) async {
      await bootAt(tester, route);
      final texts = find.byType(Text).evaluate().length;
      await unmount(tester);

      expect(texts, greaterThan(0),
          reason:
              '$route rendered NOTHING over live-shaped repos. A blank surface '
              'is the blank-canvas defect: the driver is told neither what is '
              'happening nor what to do.');
    });

    testWidgets('🔴 $route has a FORWARD EXIT on live', (tester) async {
      await bootAt(tester, route);
      final exits = liveExitCount(tester);
      await unmount(tester);

      expect(exits, greaterThan(0),
          reason:
              '🔴 $route has NO enabled control that leads off the screen. A '
              'driver who opens this mid-trip cannot get back to the job. A '
              'surface with no exit is a trap, and this one is reached from a '
              'moving car.');
    });
  }

  // ── 🔴 THE TRIP-SURFACE TERMINAL-STATE SWEEP ─────────────────────────────
  //
  // The roadmap's own No-holes DoD line: EVERY terminal state has a forward
  // exit. Parameterised over every TripPhase, so a phase added later cannot
  // quietly ship without one — the sweep is over the ENUM, not over a list
  // somebody remembered to update.

  for (final phase in TripPhase.values) {
    testWidgets('🔴 the trip runner at ${phase.name} has a forward exit',
        (tester) async {
      await bootAt(tester, '/trip/ride-1');
      final thrown = tester.takeException();
      final exits = liveExitCount(tester);
      await unmount(tester);

      expect(thrown, isNull,
          reason: 'the trip runner threw at ${phase.name} over live repos');

      expect(exits, greaterThan(0),
          reason:
              '🔴 THE TRIP RUNNER AT ${phase.name} HAS NO EXIT. This is the #7 '
              'defect restated: a driver on a live job, on a screen with no '
              'way off it. The trip must always let go — with or without a '
              'figure, a rider context, or a working seam.');
    });
  }

  // The chat's CHAT_CLOSED terminal (15-01) — the rider ended the thread and
  // the composer left the tree. The driver must not be stranded on a dead
  // conversation.
  testWidgets('🔴 the chat CHAT_CLOSED terminal has a forward exit',
      (tester) async {
    await bootAt(tester, '/trip/ride-1/chat');
    final mounted = find.byType(DriverChatView).evaluate().length;
    final exits = liveExitCount(tester);
    await unmount(tester);

    expect(mounted, 1, reason: 'the chat surface must mount at /trip/:id/chat');
    expect(exits, greaterThan(0),
        reason:
            '🔴 the CHAT_CLOSED terminal strands the driver on a dead thread. '
            'It is terminal BY DESIGN (a documented 409 on a bound endpoint) — '
            'which is exactly why it owes an exit.');
  });
}

/// The router reads exactly two things off [AuthService]. Everything else
/// throws, so a router change that quietly starts depending on more of the auth
/// surface fails loudly instead of silently passing.
class _SignedInAuthService implements AuthService {
  @override
  bool get isSignedIn => true;

  @override
  Stream<AuthState> get onAuthStateChange => const Stream.empty();

  /// The chat surface reads this to tell MY bubbles from THEIRS (15-01). A
  /// signed-in driver always has one, so the fake answers like a signed-in
  /// driver — modelled deliberately, exactly as [noSuchMethod] demands.
  @override
  String? get userId => 'driver-1';

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
        'live_boot_test drives the route table and the surfaces it reaches. '
        'The router reached for ${invocation.memberName} — if that is '
        'deliberate, add it to this fake explicitly.',
      );
}

/// 🔴 LIVE-SHAPED, not convenient. Every capability seam answers `null` and
/// every read answers empty — precisely what `:8080` answers a driver today.
/// A fake that hands back a cheerful rider context tests a backend we do not
/// have, and the whole point of this file is the backend we DO have.
class _LiveShapedRidesRepository implements RidesRepository {
  @override
  Future<List<RideMessage>> messages(String rideId, {DateTime? since}) async =>
      const [];

  // The capability seams — null on every live request, exactly as shipped.
  @override
  Future<DriverPosition?> driverPosition(String rideId) async => null;

  @override
  Future<RideGeo?> rideGeo(String rideId) async => null;

  @override
  Future<RideDriverInfo?> driverInfo(String rideId) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
        'live_boot_test: a surface reached for RidesRepository.'
        '${invocation.memberName}, which this LIVE-shaped fake does not model. '
        'Model it with what the REAL backend answers — never with something '
        'more generous.',
      );
}

/// The driver half, same rule: the two seams answer null (#7 stats, #6 rider
/// context), because that is what the live server does on every request.
class _LiveShapedDriverRepository implements DriverRepository {
  @override
  Future<DriverDayStats?> todayStats() async => null;

  @override
  Future<TripRiderContext?> tripRiderContext(String rideId) async => null;

  @override
  Future<List<RideOffer>> offers() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
        'live_boot_test: a surface reached for DriverRepository.'
        '${invocation.memberName}, which this LIVE-shaped fake does not model.',
      );
}
