import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/location/location_providers.dart';
import 'package:hoppin_driver/features/location/location_service.dart';
import 'package:hoppin_driver/features/motion/motion_builder.dart';

/// 🔴 THE INSTRUMENT THE WHOLE PHASE GATES ON.
///
/// `Position.speed` and `Position.speedAccuracy` have been read from the OS on
/// every heartbeat since the location service was written, and THROWN AWAY on
/// every one. There is no speed anywhere in the driver app today. This suite
/// specifies the gate that stops throwing it away.
///
/// Two rules, and getting either backwards ships a broken app:
///
///  1. **IGNORANCE DEGRADES OPEN.** `speedAccuracy == 0.0` is the platform
///     saying it will not vouch for its own number. `speed` is `0.0` both when
///     the vehicle is genuinely stopped AND when the platform has no idea — the
///     accuracy is the ONLY thing that tells them apart. An unknown speed must
///     NEVER take a control away from a driver who may well be parked.
///     (Contrast the heartbeat, where ignorance degrades CLOSED: no fix → no
///     ping. Both are the same rule: never assert what you do not know. There
///     the assertion would be "you are here"; here it would be "you are
///     driving".)
///
///  2. **HYSTERESIS.** A gate with one threshold strobes the composer in and
///     out of the tree every time the vehicle creeps at a red light — which is
///     a worse distraction than either state.
void main() {
  group('MotionInteractor', () {
    test('a stationary, CONFIDENT fix is not in motion', () async {
      final container = _boot([_fix(speed: 0, accuracy: 1)]);
      addTearDown(container.dispose);

      await _tick(container);

      expect(container.read(motionInteractorProvider).inMotion, isFalse);
      expect(container.read(motionInteractorProvider).speedMps, 0.0);
    });

    test('30 mph is in motion', () async {
      final container = _boot([_fix(speed: 13.4, accuracy: 1)]);
      addTearDown(container.dispose);

      await _tick(container);

      expect(container.read(motionInteractorProvider).inMotion, isTrue);
    });

    test('3.4 mph — a walking creep — is BELOW the bar and is not motion',
        () async {
      final container = _boot([_fix(speed: 1.5, accuracy: 1)]);
      addTearDown(container.dispose);

      await _tick(container);

      expect(
        container.read(motionInteractorProvider).inMotion,
        isFalse,
        reason: '1.5 m/s is under kMotionOnMps (2.235 m/s ≈ 5 mph)',
      );
    });

    test(
        '🔴 speedAccuracy == 0 → NOT in motion, whatever speed claims — '
        'ignorance degrades OPEN', () async {
      // A junk fix claiming 40 mph over a driver parked at a kerb. If we
      // believed it, we would take their keyboard away while they sat still.
      final container = _boot([_fix(speed: 17.9, accuracy: 0)]);
      addTearDown(container.dispose);

      await _tick(container);

      final state = container.read(motionInteractorProvider);
      expect(
        state.inMotion,
        isFalse,
        reason: 'the platform said it does not know. We do not remove an '
            'affordance on a guess.',
      );
      expect(
        state.speedMps,
        isNull,
        reason: 'null is NOT zero — an unconfident speed is no speed at all',
      );
    });

    test('a NULL fix (permission denied) → not in motion. Same rule.', () async {
      final container = _boot([null]);
      addTearDown(container.dispose);

      await _tick(container);

      expect(container.read(motionInteractorProvider).inMotion, isFalse);
      expect(container.read(motionInteractorProvider).speedMps, isNull);
    });

    test(
        '🔴 an unconfident fix RELEASES a latched gate — it never holds it shut',
        () async {
      // Moving, then the platform loses confidence. The lock must OPEN, not
      // stay stuck on the last confident reading.
      final container = _boot([
        _fix(speed: 13.4, accuracy: 1),
        _fix(speed: 13.4, accuracy: 0),
      ]);
      addTearDown(container.dispose);

      await _tick(container);
      expect(container.read(motionInteractorProvider).inMotion, isTrue);

      await _tick(container);
      expect(
        container.read(motionInteractorProvider).inMotion,
        isFalse,
        reason: 'confidence lost → we no longer assert they are driving',
      );
    });

    test('🔴 HYSTERESIS: the gate does not strobe at a red light', () async {
      // 13.4 (driving) → 2.0 (crawling, between the bars) → 13.4 → 2.0.
      // A single-threshold gate would read false/true/false on the crawls and
      // rip the composer in and out of the tree four times.
      final container = _boot([
        _fix(speed: 13.4, accuracy: 1),
        _fix(speed: 2.0, accuracy: 1),
        _fix(speed: 13.4, accuracy: 1),
        _fix(speed: 2.0, accuracy: 1),
      ]);
      addTearDown(container.dispose);

      final observed = <bool>[];
      for (var i = 0; i < 4; i++) {
        await _tick(container);
        observed.add(container.read(motionInteractorProvider).inMotion);
      }

      expect(
        observed,
        [true, true, true, true],
        reason: '2.0 m/s is inside the hysteresis band (above kMotionOffMps '
            '1.5, below kMotionOnMps 2.235). Once LATCHED ON, the gate holds '
            'until the vehicle drops below the LOWER bar. It must not flicker.',
      );
    });

    test('the latch RELEASES below the lower bar — a gate that never opens is '
        'a deletion, not a gate', () async {
      final container = _boot([
        _fix(speed: 13.4, accuracy: 1),
        _fix(speed: 2.0, accuracy: 1),
        _fix(speed: 0.2, accuracy: 1),
      ]);
      addTearDown(container.dispose);

      await _tick(container);
      expect(container.read(motionInteractorProvider).inMotion, isTrue);
      await _tick(container);
      expect(container.read(motionInteractorProvider).inMotion, isTrue);
      await _tick(container);
      expect(
        container.read(motionInteractorProvider).inMotion,
        isFalse,
        reason: '0.2 m/s is below kMotionOffMps — the driver has stopped',
      );
    });

    test('the thresholds are the ones the plan specifies', () {
      expect(kMotionOnMps, closeTo(2.235, 0.001), reason: '~5 mph');
      expect(kMotionOffMps, closeTo(1.5, 0.001), reason: '~3.35 mph');
      expect(
        kMotionOffMps,
        lessThan(kMotionOnMps),
        reason: 'the gap between them IS the hysteresis band',
      );
    });
  });

  group('MotionState', () {
    test('defaults to NOT in motion — a fresh gate never claims to be driving',
        () {
      expect(const MotionState().inMotion, isFalse);
      expect(const MotionState().speedMps, isNull);
    });

    test('copyWith clears speedMps explicitly, and keeps it when omitted', () {
      const moving = MotionState(inMotion: true, speedMps: 13.4);

      expect(moving.copyWith(inMotion: false).speedMps, 13.4);
      expect(moving.copyWith(speedMps: null).speedMps, isNull);
    });
  });
}

DriverFix _fix({required double speed, required double accuracy}) => (
      lat: 52.5862,
      lng: -2.1281,
      speedMps: accuracy > 0 ? speed : null,
    );

/// The scripted service, held so [_tick] can advance it.
late _ScriptedLocationService _script;

/// Boots a container over a scripted location service.
///
/// 🔴 The interactor fires an EAGER tick in `build()` (a runner mounting
/// mid-drive must not spend its first three seconds claiming the driver is
/// parked). The service starts UNARMED, so that eager read answers `null` — a
/// no-op against the honest default state — and the scripted sequence then
/// starts cleanly at the first [_tick]. Without this the eager tick would
/// silently eat script entry 0 and every assertion would be off by one.
ProviderContainer _boot(List<DriverFix?> script) {
  _script = _ScriptedLocationService(script);
  final container = ProviderContainer(
    overrides: [driverLocationServiceProvider.overrideWithValue(_script)],
  );
  // Force build() (and its eager, unarmed tick) to happen NOW.
  container.read(motionInteractorProvider);
  return container;
}

/// Pumps exactly one scripted fix through the interactor.
Future<void> _tick(ProviderContainer container) async {
  _script.armed = true;
  await container.read(motionInteractorProvider.notifier).debugTick();
}

/// A scripted `DriverLocationService`. The project injects fakes; it never
/// channel-mocks.
class _ScriptedLocationService implements DriverLocationService {
  _ScriptedLocationService(this._fixes);

  final List<DriverFix?> _fixes;

  /// Until the test arms it, every read answers `null` — see [_boot].
  bool armed = false;

  int _reads = 0;

  DriverFix? _next() {
    if (!armed || _fixes.isEmpty) return null;
    // The last scripted fix repeats: a test that ticks more often than it
    // scripts is asserting about a steady state, not running off the end.
    final fix = _fixes[_reads.clamp(0, _fixes.length - 1)];
    _reads++;
    return fix;
  }

  @override
  Future<DriverFix?> currentFix({
    Duration timeout = const Duration(seconds: 10),
  }) async =>
      _next();

  @override
  Future<({double lat, double lng})?> currentPosition({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final fix = _next();
    return fix == null ? null : (lat: fix.lat, lng: fix.lng);
  }

  @override
  Future<DriverLocationPermission> requestPermission() async =>
      DriverLocationPermission.granted;

  @override
  Future<DriverLocationPermission> requestBackgroundPermission() async =>
      DriverLocationPermission.granted;

  @override
  Future<DriverLocationCoverage> coverage() async =>
      DriverLocationCoverage.full;

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<bool> openSettings() async => true;
}
