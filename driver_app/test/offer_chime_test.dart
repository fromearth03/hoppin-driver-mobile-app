import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_demo/hoppin_demo.dart';
import 'package:hoppin_driver/app.dart';
import 'package:hoppin_driver/audio/offer_chime.dart';
import 'package:hoppin_driver/features/dashboard/dashboard_builder.dart';
import 'package:hoppin_driver/features/dashboard/dashboard_interactor.dart';
import 'package:hoppin_driver/features/dashboard/dashboard_state.dart';
import 'package:hoppin_driver/providers.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import 'support/demo_clock.dart';

/// DRIVER-02 chime foundations.
///
/// Three guarantees: the committed asset is a real, short, small WAV; the
/// [OfferChime] service NEVER throws (tests, web autoplay blocks, platforms
/// with no audio plugin — the visual offer entrance carries the beat alone);
/// and the login tap primes the player, which is the click that satisfies
/// Chrome's gesture unlock for the whole session.
///
/// OT-05 adds a fourth: the chime is ALSO primed at the GO tap — a real, fresh
/// gesture seconds before the first offer can arrive — because on Android a
/// driver's login is hours and a process-death behind their GO, and the audio
/// session it unlocked may be long gone. A silently-blocked chime is a MISSED
/// OFFER; the chime is the offer delivery mechanism, not a flourish.
class _RecordingChime extends OfferChime {
  bool primed = false;
  int primeCalls = 0;
  bool throwOnPrime = false;

  @override
  Future<void> prime() async {
    primeCalls++;
    primed = true;
    if (throwOnPrime) throw StateError('audio session unavailable');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('chime asset is a valid short WAV', () {
    final file = File('assets/audio/offer_chime.wav');
    expect(file.existsSync(), isTrue,
        reason: 'run `dart run tool/gen_chime.dart` to generate the asset');

    final bytes = file.readAsBytesSync();
    expect(bytes.length, lessThan(100 * 1024),
        reason: 'the chime must stay a small asset');

    final data = ByteData.sublistView(Uint8List.fromList(bytes));
    String tag(int offset) =>
        String.fromCharCodes(bytes.sublist(offset, offset + 4));

    // RIFF/WAVE magic + canonical 44-byte header layout.
    expect(tag(0), 'RIFF');
    expect(tag(8), 'WAVE');
    expect(tag(12), 'fmt ');
    expect(data.getUint32(16, Endian.little), 16,
        reason: 'PCM fmt chunk is 16 bytes');
    expect(data.getUint16(20, Endian.little), 1, reason: 'format must be PCM');
    expect(data.getUint16(22, Endian.little), 1, reason: 'must be mono');
    expect(data.getUint16(34, Endian.little), 16,
        reason: 'must be 16-bit samples');
    expect(tag(36), 'data');

    final byteRate = data.getUint32(28, Endian.little);
    final dataLength = data.getUint32(40, Endian.little);
    final seconds = dataLength / byteRate;
    expect(seconds, greaterThan(0.3));
    expect(seconds, lessThan(1.2));
  });

  test('OfferChime never throws off-platform', () async {
    // Plain test env: no audio plugin registered, every platform call ends
    // in MissingPluginException internally — both calls must swallow it.
    final chime = OfferChime();
    await chime.prime();
    await chime.play();
  });

  testWidgets('login tap primes the chime', (tester) async {
    final world = DemoWorld.driverScenario(
      seed: DemoSeed.seed,
      store: InMemorySnapshotStore(),
    )..restoreOrSeed();
    final chime = _RecordingChime();

    await tester.pumpWidget(ProviderScope(
      overrides: [
        ...driverDemoOverrides(world),
        demoClockOverride,
        offerChimeProvider.overrideWithValue(chime),
      ],
      child: const DriverApp(),
    ));
    await tester.pump();

    expect(chime.primed, isFalse,
        reason: 'nothing may prime before the user gesture');

    await tester.tap(find.widgetWithText(HopButton, 'Sign in'));

    // Bounded pumps (not pumpAndSettle): the world's timers stall
    // settle-detection.
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    expect(chime.primed, isTrue,
        reason: 'the login tap is the Chrome gesture-unlock click');
    expect(find.byType(DashboardRiblet), findsOneWidget,
        reason: 'priming must never break the sign-in flow');
  });

  // ───────────────────────── OT-05 — prime at GO ──────────────────────────
  group('OT-05 — the chime is primed at the GO tap, not only at a login that '
      'happened eight hours ago', () {
    test('CH1 — goOnline() succeeding primes the chime', () {
      FakeAsync().run((async) {
        final h = _DashHarness();

        unawaited(h.interactor.goOnline());
        async.flushMicrotasks();

        expect(h.state.phase, DashboardPhase.online,
            reason: 'the 200 is the confirmation');
        expect(h.chime.primeCalls, greaterThanOrEqualTo(1),
            reason: '🔴 GO is a real, fresh gesture seconds before the first '
                'offer — it arms the audio');

        h.dispose();
      });
    });

    test('CH2 — it primes on the GO path even when the login prime already ran',
        () {
      FakeAsync().run((async) {
        final h = _DashHarness();

        // The login prime already happened once (as it does in production).
        unawaited(h.chime.prime());
        async.flushMicrotasks();
        final afterLogin = h.chime.primeCalls;

        unawaited(h.interactor.goOnline());
        async.flushMicrotasks();

        expect(h.chime.primeCalls, greaterThan(afterLogin),
            reason: '🔴 prime is cheap and idempotent by design — GO primes '
                'again, because the login session may be long gone on Android');

        h.dispose();
      });
    });

    test('CH3 — a failed prime NEVER blocks going online', () {
      FakeAsync().run((async) {
        final h = _DashHarness();
        h.chime.throwOnPrime = true;

        unawaited(h.interactor.goOnline());
        async.flushMicrotasks();

        // 🔴 AUDIO IS DECORATION. IT NEVER GATES A SHIFT. A driver blocked from
        // working because an AudioPlayer would not initialise is the exact
        // class of defect this project has already paid for once.
        expect(h.chime.primeCalls, greaterThanOrEqualTo(1),
            reason: 'the prime was attempted');
        expect(h.state.phase, DashboardPhase.online,
            reason: '🔴 a throwing prime must not stop the driver going online');
        expect(h.state.error, isNull,
            reason: 'a failed prime surfaces no error — it is decoration');

        h.dispose();
      });
    });
  });
}

/// Injected-telemetry dashboard harness — the interactor sees ONLY overridden
/// providers and a recording chime; no polling, no world.
class _DashHarness {
  _DashHarness() {
    container = ProviderContainer(
      overrides: [
        driverStatsProvider.overrideWith((ref) => statsCtrl.stream),
        pendingOffersProvider.overrideWith((ref) => offersCtrl.stream),
        activeRideProvider.overrideWith((ref) => activeRideCtrl.stream),
        driverRepositoryProvider.overrideWithValue(repo),
        offerChimeProvider.overrideWithValue(chime),
      ],
    );
    _sub = container.listen(dashboardInteractorProvider, (_, _) {});
  }

  final statsCtrl = StreamController<DriverDayStats>();
  final offersCtrl = StreamController<List<RideOffer>>();
  final activeRideCtrl = StreamController<Ride?>();
  final repo = _StubDriverRepo();
  final chime = _RecordingChime();
  late final ProviderContainer container;
  late final ProviderSubscription<DashboardState> _sub;

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

/// The two BOUND driver reads goOnline touches; goOnline itself just answers 200.
class _StubDriverRepo implements DriverRepository {
  @override
  Future<List<DriverDocument>> documents() async => const [];

  @override
  Future<void> goOnline() async {}

  @override
  Future<void> goOffline() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
