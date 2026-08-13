import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/dashboard/dashboard_builder.dart';
import 'package:hoppin_driver/features/dashboard/dashboard_interactor.dart';
import 'package:hoppin_driver/features/dashboard/dashboard_state.dart';
import 'package:hoppin_driver/features/location/location_providers.dart';
import 'package:hoppin_driver/features/location/location_service.dart';
import 'package:hoppin_driver/features/presence/presence_builder.dart';
import 'package:hoppin_driver/features/presence/presence_interactor.dart';
import 'package:hoppin_driver/features/presence/presence_state.dart';
import 'package:hoppin_driver/features/presence/shift_service.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

/// THE DISPATCHABILITY PROOF.
///
/// `DriverRepository.heartbeat()` → `POST /drivers/me/location` was bound,
/// typed and CALLED BY NOTHING. A driver tapped GO, the server pooled them,
/// they never pinged, and the admin dropped them from the dispatch pool after
/// FIVE MINUTES — earning nothing, receiving nothing, and told nothing.
///
/// These tests are the machine assertion that the loop is closed.
void main() {
  test('LIVE-01 — going online sends a heartbeat IMMEDIATELY', () {
    FakeAsync().run((async) {
      final h = _Harness();
      async.flushMicrotasks();
      expect(
        h.repo.pings,
        isEmpty,
        reason: 'an OFFLINE driver is not in the pool and must not ping',
      );

      h.goOnline();
      async.elapse(const Duration(milliseconds: 100));

      expect(
        h.repo.pings,
        hasLength(1),
        reason:
            'the ping fires IMMEDIATELY, not on the first 5s tick. '
            'goOnline() has already returned 200, so the driver is in the '
            'pool RIGHT NOW — even a five-second gap delays dispatch while it '
            'can match them from no fix at all',
      );
      expect(
        h.repo.pings.single.lat,
        _Loc.defaultFix.lat,
        reason: 'the ping carries the DEVICE fix, not a constant',
      );
      expect(
        h.repo.pings.single.lng,
        _Loc.defaultFix.lng,
        reason: 'the ping carries the DEVICE fix, not a constant',
      );
      expect(
        h.state.phase,
        PresencePhase.live,
        reason: 'a landed ping means the driver is genuinely reachable',
      );

      h.dispose();
    });
  });

  test('LIVE-02 — three minutes online yields MANY heartbeats', () {
    FakeAsync().run((async) {
      final h = _Harness();
      h.goOnline();
      async.elapse(const Duration(minutes: 3));

      // The server drops a driver after 5 MINUTES with no ping. At the 5s
      // cadence a 3-minute shift owes ~36 pings; anything at or below 8 would
      // mean presence lapses and the driver silently leaves the pool.
      expect(
        h.repo.pings.length,
        greaterThan(2),
        reason:
            'dispatchability must survive the server 5-minute presence '
            'window — 3 minutes of shift must produce far more than 2 pings',
      );
      expect(
        h.repo.pings.length,
        greaterThanOrEqualTo(35),
        reason:
            'the 5s cadence gives 60 misses of headroom before presence '
            'lapses; ~36 pings in 3 minutes is the shape of that guarantee',
      );
      expect(
        h.state.pingCount,
        h.repo.pings.length,
        reason: 'every accepted ping is counted',
      );

      h.dispose();
    });
  });

  test('going offline STOPS the heartbeat', () {
    FakeAsync().run((async) {
      final h = _Harness();
      h.goOnline();
      async.elapse(const Duration(minutes: 1));
      final whileOnline = h.repo.pings.length;
      expect(whileOnline, greaterThan(1), reason: 'it was pinging');

      h.goOffline();
      async.elapse(const Duration(minutes: 2));

      expect(
        h.repo.pings,
        hasLength(whileOnline),
        reason:
            'an offline driver is NOT in the dispatch pool and must not '
            'keep telling the server where they are — that is both a lie to '
            'dispatch and a battery drain',
      );
      expect(
        h.state.phase,
        PresencePhase.idle,
        reason: 'presence returns to idle when the shift ends',
      );

      h.dispose();
    });
  });

  // 🔴 SEAM #84 — the device rung.
  test('NO FIX → ZERO pings, and the driver is TOLD (never 0,0)', () {
    FakeAsync().run((async) {
      final h = _Harness(location: _Loc(fix: null));
      h.goOnline();
      async.elapse(const Duration(minutes: 3));

      expect(
        h.repo.pings,
        isEmpty,
        reason:
            '🔴 NEVER POST A FABRICATED COORDINATE. The server ACCEPTS an '
            'empty body and binds it to 0,0 — a "send something rather than '
            'nothing" heartbeat would silently pin the driver to the Gulf of '
            'Guinea and hand dispatch a confident, wrong answer. No fix means '
            'NO PING',
      );
      expect(
        h.state.phase,
        PresencePhase.noFix,
        reason: 'the state says the driver is unreachable',
      );
      expect(
        h.state.locationUnavailable,
        isTrue,
        reason:
            'this is what raises the #84 LocationUnavailableBanner on the '
            'dashboard — the app must never show a confident ONLINE state '
            'over a driver nobody can reach',
      );
      expect(
        h.state.pingCount,
        0,
        reason: 'nothing landed, because nothing was sent',
      );

      h.dispose();
    });
  });

  test('a failing WIRE degrades but keeps retrying (presence has 5 min)', () {
    FakeAsync().run((async) {
      final h = _Harness();
      h.repo.throwOnPing = true;
      h.goOnline();
      async.elapse(const Duration(seconds: 45));

      expect(
        h.state.phase,
        PresencePhase.degraded,
        reason:
            'the fix is good; the wire is not — that is a different '
            'state from having no fix, and it is not the #84 rung',
      );
      expect(
        h.state.locationUnavailable,
        isFalse,
        reason:
            'a network blip is NOT an OS permission problem — raising the '
            '"turn on location" banner here would send the driver to a '
            'settings page that fixes nothing',
      );
      expect(
        h.repo.attempts,
        greaterThan(1),
        reason:
            'the timer keeps trying — presence only lapses if nothing '
            'lands for 5 minutes, so one failed request must not end the '
            'shift',
      );

      h.dispose();
    });
  });

  // ══ PHASE 2 — THE ANDROID FOREGROUND SERVICE AND THE TWO-STAGE GRANT ══════
  //
  // Everything above proves the heartbeat FIRES. Everything below proves the
  // app is HONEST about whether that heartbeat will survive the driver locking
  // their phone — which, on Android, is a completely separate question.

  group('the foreground service (the shift survives a locked screen)', () {
    test('going online STARTS the foreground service', () {
      FakeAsync().run((async) {
        final h = _Harness();
        async.flushMicrotasks();
        expect(
          h.shift.starts,
          0,
          reason:
              'an offline driver owes the OS no persistent notification '
              'and no wake lock',
        );

        h.goOnline();
        async.elapse(const Duration(milliseconds: 100));

        expect(
          h.shift.starts,
          1,
          reason:
              '🔴 THE WHOLE POINT OF PHASE 2. Without the foreground '
              'service Android is free to freeze the isolate the moment the '
              'app leaves the screen — the 5s timer stops, the heartbeat '
              'starves, and the admin drops the driver from the pool 5 '
              'minutes later. The service is what keeps the isolate ALIVE',
        );
        expect(
          h.state.shiftServiceRunning,
          isTrue,
          reason:
              'the state records what the OS actually did, not what we '
              'asked it to do',
        );
        expect(
          h.state.backgroundProtected,
          isTrue,
          reason:
              'full coverage + a running service = the shift genuinely '
              'survives a locked screen. THIS is the only state the app is '
              'allowed to be confident about',
        );

        h.dispose();
      });
    });

    test('going offline STOPS the foreground service', () {
      FakeAsync().run((async) {
        final h = _Harness();
        h.goOnline();
        async.elapse(const Duration(seconds: 30));
        expect(h.shift.running, isTrue, reason: 'it was running');

        h.goOffline();
        async.elapse(const Duration(seconds: 1));

        expect(
          h.shift.stops,
          greaterThanOrEqualTo(1),
          reason:
              'a persistent "On shift" notification over a driver who has '
              'clocked off is its own small lie — and the wake lock is not '
              'free',
        );
        expect(
          h.state.shiftServiceRunning,
          isFalse,
          reason: 'the state follows the world',
        );
        expect(
          h.state.backgroundProtected,
          isFalse,
          reason:
              'an offline driver is not protected because there is '
              'nothing to protect',
        );

        h.dispose();
      });
    });

    test('🔴 the service REFUSING to start is DISCLOSED, never swallowed '
        '(the OEM battery-killer case)', () {
      FakeAsync().run((async) {
        // Permission is FULL. The OS still refuses to run the service —
        // notifications denied, or one of the many OEM battery managers that
        // kill foreground services on sight. The driver holds every grant and
        // is STILL not protected.
        final h = _Harness(shift: _Shift(startSucceeds: false));
        h.goOnline();
        async.elapse(const Duration(seconds: 1));

        expect(
          h.repo.pings,
          isNotEmpty,
          reason:
              'the driver is still DISPATCHABLE — the heartbeat runs in '
              'the app isolate and works perfectly while the app is on '
              'screen. A failed service must never stop them working',
        );
        expect(
          h.state.shiftServiceRunning,
          isFalse,
          reason: 'we asked the OS and it said no. We record what it said',
        );
        expect(
          h.state.backgroundProtected,
          isFalse,
          reason:
              '🔴 THE PERMISSION IS NOT THE PROTECTION. Holding '
              'ACCESS_BACKGROUND_LOCATION with no running foreground service '
              'gets the driver exactly nothing once the screen locks. An '
              'optimistic `true` here — "well, they granted it" — is the lie',
        );
        expect(
          h.state.foregroundOnly,
          isTrue,
          reason:
              'the CONSEQUENCE is identical to a foreground-only grant '
              '(the shift dies at the lock screen), so the disclosure must be '
              'identical too — the #85 rung, on the dashboard, right now',
        );

        h.dispose();
      });
    });
  });

  group('🔴 the two-stage permission flow (seam #85)', () {
    test('a FOREGROUND-ONLY driver is STILL DISPATCHABLE — and is told exactly '
        'what they lose', () {
      FakeAsync().run((async) {
        final h = _Harness(
          location: _Loc(coverageLevel: DriverLocationCoverage.foregroundOnly),
        );
        h.goOnline();
        async.elapse(const Duration(minutes: 2));

        // HALF ONE: they are a real, working driver. Do not break them.
        expect(
          h.repo.pings.length,
          greaterThan(2),
          reason:
              '🔴 A FOREGROUND-ONLY DRIVER IS NOT A BROKEN DRIVER. They '
              'granted location, they tapped GO, the server pooled them, and '
              'offers arrive. While the app is on screen they are fully '
              'dispatchable and the heartbeat is fully real. Blocking them '
              'would be its own defect',
        );
        expect(
          h.state.phase,
          PresencePhase.live,
          reason: 'the pings are landing — presence is genuinely live',
        );
        expect(
          h.state.locationUnavailable,
          isFalse,
          reason:
              'this is NOT the #84 no-fix state. Raising the "turn on '
              'location" banner here would tell a driver who HAS location '
              'that they do not, and send them to a settings page to fix '
              'something that is not broken',
        );

        // HALF TWO: and the app knows the cliff is two seconds away.
        expect(
          h.state.coverage,
          DriverLocationCoverage.foregroundOnly,
          reason:
              'coverage is read from the OS, not assumed from the fact '
              'that a fix arrived — a fix arrives in BOTH worlds while the '
              'app is on screen, which is exactly what makes this lie so easy '
              'to ship',
        );
        expect(
          h.state.backgroundProtected,
          isFalse,
          reason:
              '🔴 THE ASSERTION THIS WHOLE PHASE EXISTS FOR. The app must '
              'NEVER claim background coverage it does not have. This driver '
              'locks their phone, Android stops delivering fixes, the '
              'heartbeat starves, and the admin drops them from the pool in 5 '
              'minutes — while a green ONLINE badge tells them they are '
              'earning. That badge is the same class of lie as a fabricated '
              'payment card',
        );
        expect(
          h.state.foregroundOnly,
          isTrue,
          reason:
              'this is what mounts BackgroundLocationLimitedNotice on the '
              'dashboard — the rung that states the consequence ("keep the '
              'app open"), not the Android fact ("permission not granted")',
        );

        h.dispose();
      });
    });

    test('stage two: the driver taps the rung, the OS says YES', () {
      FakeAsync().run((async) {
        final h = _Harness(
          location: _Loc(
            coverageLevel: DriverLocationCoverage.foregroundOnly,
            grantsBackgroundOnRequest: true,
          ),
        );
        h.goOnline();
        async.elapse(const Duration(seconds: 1));
        expect(h.state.foregroundOnly, isTrue, reason: 'precondition');

        h.presence.requestBackgroundCoverage();
        async.elapse(const Duration(seconds: 1));

        expect(
          h.state.coverage,
          DriverLocationCoverage.full,
          reason:
              'the OS granted "Allow all the time" and we re-read it FROM '
              'THE OS — never from our own request\'s return value, because '
              'the driver may still be standing in the Settings app',
        );
        expect(
          h.state.backgroundProtected,
          isTrue,
          reason:
              'full grant + running service: the shift now genuinely '
              'survives a locked screen, and the badge may finally be '
              'confident',
        );
        expect(
          h.state.foregroundOnly,
          isFalse,
          reason:
              'the #85 rung disappears — because the condition it '
              'discloses is gone, not because we stopped looking',
        );

        h.dispose();
      });
    });

    test('stage two: the OS says NO (Android 11+ shows no dialog) → the driver '
        'is walked to SETTINGS, and the rung STAYS', () {
      FakeAsync().run((async) {
        final h = _Harness(
          location: _Loc(
            coverageLevel: DriverLocationCoverage.foregroundOnly,
            // The real Android 11+ behaviour: the OS does not even show a
            // dialog for the background upgrade. The request resolves straight
            // to "denied" and the ONLY route is the Settings app.
            grantsBackgroundOnRequest: false,
          ),
        );
        h.goOnline();
        async.elapse(const Duration(seconds: 1));

        h.presence.requestBackgroundCoverage();
        async.elapse(const Duration(seconds: 1));

        expect(
          h.loc.settingsOpened,
          1,
          reason:
              '🔴 A DISCLOSURE THAT STRANDS THE DRIVER IS ONLY HALF '
              'HONEST. On Android 11+ "Allow all the time" cannot be granted '
              'from a dialog AT ALL — it lives only in the Settings app. A '
              'rung that says "you are limited" and offers no route to fix it '
              'is a shrug',
        );
        expect(
          h.state.backgroundProtected,
          isFalse,
          reason:
              'the driver has not granted it yet — they are still walking '
              'to Settings. We do not credit them for a permission they have '
              'not given',
        );
        expect(
          h.state.foregroundOnly,
          isTrue,
          reason:
              'the rung STAYS. It disappears when the OS says the grant '
              'is held (on the next app resume — refreshCoverage()), never '
              'when we merely ASKED for it',
        );
        expect(
          h.repo.pings,
          isNotEmpty,
          reason: 'and throughout all of it they kept working',
        );

        h.dispose();
      });
    });

    test('🔴 coverage REVOKED mid-shift from Settings is caught on the next '
        'resume', () {
      FakeAsync().run((async) {
        final h = _Harness();
        h.goOnline();
        async.elapse(const Duration(seconds: 1));
        expect(h.state.backgroundProtected, isTrue, reason: 'precondition');

        // The driver goes to Settings and flips "Allow all the time" back to
        // "While using the app". Android pushes us NO EVENT for this. Nothing
        // tells us. Our cached belief survives the exact user action that
        // falsified it — and the app would keep drawing a confident ONLINE
        // badge over a shift that now dies at the lock screen.
        h.loc.coverageLevel = DriverLocationCoverage.foregroundOnly;

        expect(
          h.state.backgroundProtected,
          isTrue,
          reason:
              'sanity: nothing has told us yet — this is precisely the '
              'window in which the app is silently wrong, and precisely why '
              'the resume hook is not optional',
        );

        // The dashboard's AppLifecycleListener fires this on every resume.
        h.presence.refreshCoverage();
        async.elapse(const Duration(seconds: 1));

        expect(
          h.state.coverage,
          DriverLocationCoverage.foregroundOnly,
          reason:
              'we ASKED THE OS AGAIN rather than trusting what we '
              'remembered. That is the only honest way to know',
        );
        expect(
          h.state.backgroundProtected,
          isFalse,
          reason:
              'the badge drops out of confidence the moment the truth '
              'does',
        );
        expect(
          h.state.foregroundOnly,
          isTrue,
          reason: 'and the #85 rung comes back up',
        );

        h.dispose();
      });
    });

    test('an OFFLINE driver has nothing to refresh (no spurious OS calls)', () {
      FakeAsync().run((async) {
        final h = _Harness();
        async.flushMicrotasks();

        h.presence.refreshCoverage();
        async.elapse(const Duration(seconds: 1));

        expect(
          h.state.coverage,
          DriverLocationCoverage.none,
          reason:
              'an offline driver is not covered because they are not '
              'working — there is nothing to be honest about yet, and probing '
              'the OS on every resume of an idle app is noise',
        );
        expect(
          h.shift.starts,
          0,
          reason: 'a resume must never start a shift the driver did not',
        );

        h.dispose();
      });
    });
  });
}

/// Container harness: the presence interactor over a recording repository and
/// a scripted location seam, with the dashboard phase driven by hand.
class _Harness {
  _Harness({_Loc? location, _Shift? shift})
    : loc = location ?? _Loc(),
      shift = shift ?? _Shift() {
    container = ProviderContainer(
      overrides: [
        driverRepositoryProvider.overrideWithValue(repo),
        driverLocationServiceProvider.overrideWithValue(loc),
        driverShiftServiceProvider.overrideWithValue(this.shift),
        // The dashboard phase is the ONLY thing presence listens to. It must
        // never listen to `todayStats()` (#7) — that seam answers null on every
        // live request, so a heartbeat hung off it would never start at all.
        dashboardInteractorProvider.overrideWith(_StubDashboard.new),
      ],
    );
    _sub = container.listen(presenceInteractorProvider, (_, _) {});
  }

  final _Loc loc;
  final _Shift shift;
  final repo = _RecordingDriverRepo();
  late final ProviderContainer container;
  late final ProviderSubscription<PresenceState> _sub;

  PresenceState get state => container.read(presenceInteractorProvider);

  PresenceInteractor get presence =>
      container.read(presenceInteractorProvider.notifier);

  void goOnline() =>
      (container.read(dashboardInteractorProvider.notifier) as _StubDashboard)
          .set(DashboardPhase.online);

  void goOffline() =>
      (container.read(dashboardInteractorProvider.notifier) as _StubDashboard)
          .set(DashboardPhase.offline);

  void dispose() {
    _sub.close();
    container.dispose();
  }
}

/// The dashboard phase, driven by hand — presence's only input.
class _StubDashboard extends DashboardInteractor {
  @override
  DashboardState build() => const DashboardState();

  void set(DashboardPhase phase) => state = state.copyWith(phase: phase);
}

/// A scripted location seam. `fix: null` is the DENIED-PERMISSION case, which
/// is the whole of seam #84; [coverageLevel] scripts the two-stage grant, which
/// is the whole of seam #85.
///
/// 🔴 NOTE WHAT IS **NOT** HERE: a MethodChannel mock. Every location call in
/// the driver app goes through the `DriverLocationService` seam, so a test
/// injects a plain Dart object and drives every failure path — permission
/// denied, background refused, OS services off, a fix that times out. If a test
/// in this repository ever needs `TestDefaultBinaryMessenger.setMockMethodCall
/// Handler`, the abstraction has been put in the wrong place.
class _Loc implements DriverLocationService {
  _Loc({
    this.fix = defaultFix,
    this.coverageLevel = DriverLocationCoverage.full,
    this.grantsBackgroundOnRequest = false,
  });

  static const ({double lat, double lng}) defaultFix = (
    lat: 52.5862,
    lng: -2.1281,
  );

  final ({double lat, double lng})? fix;

  /// What the OS says we hold RIGHT NOW.
  DriverLocationCoverage coverageLevel;

  /// Whether the stage-two request succeeds. On a real Android 11+ device it
  /// usually does NOT — the OS shows no dialog and answers "denied", and the
  /// driver must be walked out to Settings. Both branches are tested.
  final bool grantsBackgroundOnRequest;

  /// Every `openSettings()` call. The #85 rung's exit is a REAL exit; a rung
  /// that strands the driver is only half-honest.
  int settingsOpened = 0;

  @override
  Future<DriverLocationPermission> requestPermission() async => fix == null
      ? DriverLocationPermission.denied
      : DriverLocationPermission.granted;

  @override
  Future<DriverLocationPermission> requestBackgroundPermission() async {
    if (!grantsBackgroundOnRequest) return DriverLocationPermission.denied;
    coverageLevel = DriverLocationCoverage.full;
    return DriverLocationPermission.granted;
  }

  @override
  Future<DriverLocationCoverage> coverage() async => coverageLevel;

  @override
  Future<bool> hasPermission() async => fix != null;

  @override
  Future<({double lat, double lng})?> currentPosition({
    Duration timeout = const Duration(seconds: 10),
  }) async => fix;

  /// The heartbeat does not read speed — the motion gate does. This fake simply
  /// satisfies the interface: the same fix, with a confident zero.
  @override
  Future<DriverFix?> currentFix({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final f = fix;
    return f == null ? null : (lat: f.lat, lng: f.lng, speedMps: 0.0);
  }

  @override
  Future<bool> openSettings() async {
    settingsOpened++;
    return true;
  }
}

/// A scripted foreground-service seam — the Android FGS, driven from Dart.
///
/// `startSucceeds: false` is the OEM-battery-killer / notifications-denied case:
/// the driver holds the permission and the OS still refuses to run the service.
/// The consequence for the driver is identical to not holding the permission —
/// the shift dies at the lock screen — so the disclosure must be identical too.
class _Shift implements DriverShiftService {
  _Shift({this.startSucceeds = true});

  final bool startSucceeds;
  bool running = false;
  int starts = 0;
  int stops = 0;

  @override
  Future<bool> start() async {
    starts++;
    running = startSucceeds;
    return running;
  }

  @override
  Future<void> stop() async {
    stops++;
    running = false;
  }

  @override
  Future<bool> isRunning() async => running;
}

/// Records every heartbeat that reaches the wire. Only the members presence
/// touches are implemented.
class _RecordingDriverRepo implements DriverRepository {
  final List<({double lat, double lng})> pings = [];
  int attempts = 0;
  bool throwOnPing = false;

  @override
  Future<void> heartbeat({required double lat, required double lng}) async {
    attempts++;
    if (throwOnPing) throw const ApiException(statusCode: 503, message: 'down');
    pings.add((lat: lat, lng: lng));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'presence must not call ${invocation.memberName}',
  );
}
