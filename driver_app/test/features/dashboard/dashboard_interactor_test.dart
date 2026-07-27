import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/audio/offer_chime.dart';
import 'package:hoppin_driver/features/dashboard/dashboard_builder.dart';
import 'package:hoppin_driver/features/dashboard/dashboard_interactor.dart';
import 'package:hoppin_driver/features/dashboard/dashboard_state.dart';
import 'package:hoppin_driver/providers.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

/// Interactor unit layer (riblet testing contract, DOCS/05):
/// every phase transition and guard proven against hand-fed telemetry
/// streams and recording repository/auth fakes. The polling transport
/// itself was proven in providers_test.dart (03-01) — here the providers
/// are overridden with injected StreamControllers so each beat is exact.
void main() {
  test('telemetry merges into state', () {
    FakeAsync().run((async) {
      final h = _Harness();
      expect(h.state.statsReady, isFalse);
      expect(h.state.phase, DashboardPhase.offline);

      h.statsCtrl.add(_stats());
      async.flushMicrotasks();
      expect(h.state.phase, DashboardPhase.offline);
      expect(h.state.earningsPence, 4375);
      expect(h.state.tripCount, 5);
      expect(h.state.onlineTime, const Duration(hours: 3, minutes: 10));
      expect(h.state.statsReady, isTrue);

      h.statsCtrl.add(_stats(
        online: true,
        pickupEtaSeconds: 120,
        activeRideId: 'ride-1',
      ));
      async.flushMicrotasks();
      expect(h.state.phase, DashboardPhase.online);
      expect(h.state.pickupEtaSeconds, 120);

      // 🔴 THE SEAM DOES NOT FEED NAVIGATION. The telemetry payload above
      // CARRIES `activeRideId: 'ride-1'` and the interactor IGNORES IT.
      //
      // `activeRideId` drives the mid-trip resume redirect, and it used to be
      // written straight out of this handler — the #7 (`todayStats()`) seam,
      // which answers null on EVERY live request. So on live the redirect never
      // fired: a driver who refreshed mid-trip was dumped on the dashboard with
      // no way back into a trip the server still had running.
      //
      // The value now comes from a BOUND `GET /rides` read (activeRideProvider)
      // and from nowhere else. A capability seam may only feed DECORATION.
      expect(h.state.activeRideId, isNull,
          reason: 'navigation state must NOT be sourced from the #7 seam — '
              'the telemetry above carried activeRideId and it must be ignored');

      h.dispose();
    });
  });

  test('activeRideId is sourced from the BOUND ride read', () {
    FakeAsync().run((async) {
      final h = _Harness();
      expect(h.state.activeRideId, isNull,
          reason: 'no running ride yet');

      h.activeRideCtrl.add(_ride('ride-1', RideStatus.started));
      async.flushMicrotasks();
      expect(h.state.activeRideId, 'ride-1',
          reason: 'the BOUND `GET /rides` read is what drives the resume '
              'redirect — the driver lands back in the trip they are running');

      // The trip ends: the bound read stops reporting a running ride, and the
      // redirect must stop firing with it (or every dashboard visit would be
      // yanked into a finished trip).
      h.activeRideCtrl.add(null);
      async.flushMicrotasks();
      expect(h.state.activeRideId, isNull,
          reason: 'a finished trip is not a trip to resume');

      h.dispose();
    });
  });

  test('goOnline delegates, busy-guards, and the 200 IS the confirmation', () {
    FakeAsync().run((async) {
      final h = _Harness();
      final gate = Completer<void>();
      h.repo.goOnlineGate = gate;

      unawaited(h.interactor.goOnline());
      async.flushMicrotasks();
      expect(h.repo.goOnlineCalls, 1,
          reason: 'the GO intent delegates to the repository exactly once');
      expect(h.state.phase, DashboardPhase.goingOnline,
          reason: 'the transition is held only while the call is in flight');

      // A second tap while the first is in flight is a no-op (busy guard).
      unawaited(h.interactor.goOnline());
      async.flushMicrotasks();
      expect(h.repo.goOnlineCalls, 1,
          reason: 'the busy guard swallows a second tap mid-flight');

      // PRESENCE IS AUTHORITATIVE FROM THE ENDPOINT. The 200 means the driver
      // IS in the dispatch pool — the phase flips on it, with no telemetry
      // emission at all. Gating on telemetry was the Wave-0 live bug: seam #7
      // answers null forever, so that emission never came and the driver was
      // stranded on a spinner while already taking offers.
      gate.complete();
      async.flushMicrotasks();
      expect(h.state.phase, DashboardPhase.online,
          reason:
              'presence comes from the 200, never from a seam that can be null');

      h.dispose();
    });
  });

  test('goOnline failure surfaces a friendly error and returns offline', () {
    FakeAsync().run((async) {
      final h = _Harness();
      h.repo.throwOnGoOnline = true;

      unawaited(h.interactor.goOnline());
      async.flushMicrotasks();
      expect(h.repo.goOnlineCalls, 1,
          reason: 'the failing intent still reached the repository');
      expect(h.state.phase, DashboardPhase.offline,
          reason: 'a failed GO returns the driver to a settled offline phase');
      expect(h.state.error, 'Something went wrong. Please try again.',
          reason: 'the failure surfaces as friendly copy, never a raw throw');

      // The next attempt clears the error and — on its 200 — lands online.
      h.repo.throwOnGoOnline = false;
      unawaited(h.interactor.goOnline());
      async.flushMicrotasks();
      expect(h.state.error, isNull,
          reason: 'a fresh intent clears the stale error banner');
      expect(h.state.phase, DashboardPhase.online,
          reason: 'the retry succeeds and the 200 confirms presence');

      h.dispose();
    });
  });

  test('goOffline is the quiet path, and its 200 IS the confirmation', () {
    FakeAsync().run((async) {
      final h = _Harness();
      h.statsCtrl.add(_stats(online: true));
      async.flushMicrotasks();
      expect(h.state.phase, DashboardPhase.online,
          reason: 'telemetry that DOES arrive still resolves the phase');

      final gate = Completer<void>();
      h.repo.goOfflineGate = gate;

      unawaited(h.interactor.goOffline());
      async.flushMicrotasks();
      expect(h.repo.goOfflineCalls, 1,
          reason: 'the quiet affordance delegates to the repository once');
      expect(h.state.phase, DashboardPhase.goingOffline,
          reason: 'the transition is held only while the call is in flight');

      // Stale telemetry mid-flight still says online — it must NOT undo the
      // transition the driver asked for.
      h.statsCtrl.add(_stats(online: true));
      async.flushMicrotasks();
      expect(h.state.phase, DashboardPhase.goingOffline,
          reason: 'stale in-flight telemetry never clobbers a live transition');

      // The 200 lands: out of the pool, no telemetry emission needed.
      gate.complete();
      async.flushMicrotasks();
      expect(h.state.phase, DashboardPhase.offline,
          reason: 'the offline 200 confirms departure from the dispatch pool');

      h.dispose();
    });
  });

  test('earnings absorb trigger sets the delta and clears itself', () {
    FakeAsync().run((async) {
      final h = _Harness();

      // First-ever emission must NOT trigger the chip (no chip on boot).
      h.statsCtrl.add(_stats());
      async.flushMicrotasks();
      expect(h.state.recentEarnedPence, isNull);
      expect(h.state.statsReady, isTrue);

      // Earnings tick up by 639 — the absorb delta arms.
      h.statsCtrl.add(_stats(earningsPence: 5014, tripCount: 6));
      async.flushMicrotasks();
      expect(h.state.recentEarnedPence, 639);
      expect(h.state.earningsPence, 5014);
      expect(h.state.tripCount, 6);

      // The clear timer (~2.5s) wipes the chip.
      async.elapse(const Duration(milliseconds: 2600));
      expect(h.state.recentEarnedPence, isNull);
      expect(h.state.earningsPence, 5014);

      h.dispose();
    });
  });

  test('offer surfaces in state', () {
    FakeAsync().run((async) {
      final h = _Harness();
      final offer = RideOffer(
        offerId: 'offer-1',
        rideId: 'ride-1',
        pickupLat: 52.5875,
        pickupLng: -2.1288,
        dropoffLat: 52.5862,
        dropoffLng: -2.1272,
        fare: 6.39,
        estimatedMiles: 1.8,
        expiresAt: DateTime.utc(2026, 7, 7, 12, 0, 15),
        offeredAt: DateTime.utc(2026, 7, 7, 12),
      );

      h.offersCtrl.add([offer]);
      async.flushMicrotasks();
      expect(h.state.pendingOffer, offer);

      h.offersCtrl.add(const []);
      async.flushMicrotasks();
      expect(h.state.pendingOffer, isNull);

      h.dispose();
    });
  });

  test('signOut delegates to authService', () {
    FakeAsync().run((async) {
      final h = _Harness();
      unawaited(h.interactor.signOut());
      async.flushMicrotasks();
      expect(h.auth.signOutCalls, 1);
      h.dispose();
    });
  });
}

DriverDayStats _stats({
  bool online = false,
  int earningsPence = 4375,
  int tripCount = 5,
  Duration onlineTime = const Duration(hours: 3, minutes: 10),
  int? pickupEtaSeconds,
  String? activeRideId,
}) =>
    (
      online: online,
      earningsPence: earningsPence,
      tripCount: tripCount,
      onlineTime: onlineTime,
      pickupEtaSeconds: pickupEtaSeconds,
      activeRideId: activeRideId,
    );

/// Injected-telemetry harness: the interactor sees ONLY overridden
/// providers and recording fakes — no polling, no world.
class _Harness {
  _Harness() {
    container = ProviderContainer(
      overrides: [
        driverStatsProvider.overrideWith((ref) => statsCtrl.stream),
        pendingOffersProvider.overrideWith((ref) => offersCtrl.stream),
        // The BOUND `GET /rides` read that now sources activeRideId. It is a
        // SEPARATE stream from the telemetry seam on purpose — that separation
        // IS the fix.
        activeRideProvider.overrideWith((ref) => activeRideCtrl.stream),
        driverRepositoryProvider.overrideWithValue(repo),
        authServiceProvider.overrideWithValue(auth),
        // OT-05: goOnline now primes the offer chime on success — stub it so
        // no real AudioPlayer is created inside FakeAsync (its platform init
        // would throw). The chime is decoration; these tests are about phase.
        offerChimeProvider.overrideWithValue(_SilentChime()),
      ],
    );
    // Keep the interactor actively listened (the view's ref.watch in
    // production) — Riverpod 3 pauses an unlistened provider's own
    // subscriptions, which would freeze the telemetry merge.
    _sub = container.listen(dashboardInteractorProvider, (_, _) {});
  }

  late final ProviderSubscription<DashboardState> _sub;

  final statsCtrl = StreamController<DriverDayStats>();
  final offersCtrl = StreamController<List<RideOffer>>();
  final activeRideCtrl = StreamController<Ride?>();
  final repo = _RecordingDriverRepo();
  final auth = _RecordingAuth();
  late final ProviderContainer container;

  DashboardState get state => container.read(dashboardInteractorProvider);

  DashboardInteractor get interactor =>
      container.read(dashboardInteractorProvider.notifier);

  void dispose() {
    _sub.close();
    container.dispose();
    unawaited(statsCtrl.close());
    unawaited(offersCtrl.close());
    unawaited(activeRideCtrl.close());
  }
}

/// A ride row shaped like `GET /rides` returns one.
Ride _ride(String id, RideStatus status) => Ride(
      id: id,
      riderId: 'rider-1',
      driverId: 'driver-1',
      status: status,
    );

/// Records goOnline/goOffline calls; can be gated (in-flight) or armed to
/// throw. Only the members the interactor touches are implemented.
class _RecordingDriverRepo implements DriverRepository {
  int goOnlineCalls = 0;
  int goOfflineCalls = 0;
  bool throwOnGoOnline = false;
  Completer<void>? goOnlineGate;
  Completer<void>? goOfflineGate;

  /// The BOUND `GET /drivers/me/documents` the eligibility riblet reads for its
  /// expiry ladder (13-04). This fake has no documents, so no rung renders and
  /// nothing blocks — which is exactly the world these dashboard tests assume.
  @override
  Future<List<DriverDocument>> documents() async => const [];

  @override
  Future<void> goOnline() {
    goOnlineCalls++;
    if (throwOnGoOnline) return Future.error(Exception('NOT_ELIGIBLE'));
    return goOnlineGate?.future ?? Future.value();
  }

  @override
  Future<void> goOffline() {
    goOfflineCalls++;
    return goOfflineGate?.future ?? Future.value();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A chime that primes silently — no AudioPlayer, no platform channel.
class _SilentChime extends OfferChime {
  @override
  Future<void> prime() async {}

  @override
  Future<void> play() async {}
}

class _RecordingAuth implements AuthService {
  int signOutCalls = 0;

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
