import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/location/location_providers.dart';
import 'package:hoppin_driver/features/location/location_service.dart';
import 'package:hoppin_driver/features/motion/motion_builder.dart';

/// 🔴 THE ONE UNPROVEN LINK IN THE MOTION CONTRACT.
///
/// Every existing motion test injects `MotionState(inMotion: true/false)` as a
/// boolean via a `_PinnedMotion` stub — the whole interaction budget is proven
/// against a HAND-SET flag, and the REAL speed→inMotion decision in
/// `MotionInteractor._tick()` is never exercised. If that comparison were
/// inverted, or compared an mph value against an m/s threshold, EVERY existing
/// motion test would still pass, because they all bypass the interactor.
///
/// This file drives the REAL `motionInteractorProvider` — the actual
/// `MotionInteractor`, no stub — from a scripted [DriverLocationService], and
/// asserts `inMotion` flips at the correct m/s boundary. It exercises the exact
/// comparison in `_tick`, so an inverted compare or a unit bug makes it FAIL.
///
/// The seam: the interactor reads `driverLocationServiceProvider.currentFix()`.
/// We override that provider with a fake whose speed we script, then step the
/// gate one poll at a time via the `@visibleForTesting` `debugTick()` — never
/// racing the real 3-second wall-clock timer.
void main() {
  /// A location seam whose speed is scripted per-tick. Everything else degrades
  /// exactly like the live service's null/absent paths; only `currentFix` is
  /// interesting here, and only its `speedMps` field.
  ///
  /// `speedMps` is a *field*, not a constructor argument, so a single instance
  /// can walk a speed profile (below → above → boundary) across successive
  /// `debugTick()` calls, which is how hysteresis has to be probed.
  final fake = _ScriptedSpeedService();

  ProviderContainer boot() {
    // 🔴 build() fires an IMMEDIATE unawaited _tick() that reads whatever speed
    // the fake currently reports. Reset to null (ignorance → gate stays OFF)
    // BEFORE materialising, so a value left over from a previous test can never
    // latch the fresh gate ON behind our backs. Every test then drives its own
    // first meaningful speed explicitly through `tickAt`.
    fake.speedMps = null;
    final container = ProviderContainer(
      overrides: [
        driverLocationServiceProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);
    // Materialise the notifier so `build()` runs and wires its timer; we drive
    // ticks by hand from here on.
    container.read(motionInteractorProvider);
    return container;
  }

  /// Steps the REAL interactor exactly one poll and returns the resulting state.
  Future<MotionState> tickAt(ProviderContainer c, double? speedMps) async {
    fake.speedMps = speedMps;
    await c.read(motionInteractorProvider.notifier).debugTick();
    return c.read(motionInteractorProvider);
  }

  group('🔴 the REAL speed→inMotion threshold (not a pinned stub)', () {
    test('honest starting position is NOT MOVING', () {
      final c = boot();
      expect(c.read(motionInteractorProvider).inMotion, isFalse);
    });

    test('a speed BELOW the ON bar does NOT engage the gate', () async {
      final c = boot();
      // 2.0 m/s ≈ 4.5 mph — below kMotionOnMps (2.235). From rest, the gate
      // stays OPEN: the driver keeps their keyboard.
      final state = await tickAt(c, 2.0);
      expect(
        state.inMotion,
        isFalse,
        reason: '🔴 the gate engaged below the ON threshold. Either the '
            'comparison is inverted, or an mph value is being compared against '
            'the m/s constant — 2.0 m/s is 4.5 mph, below the ~5 mph bar.',
      );
      expect(state.speedMps, 2.0);
    });

    test('a speed ABOVE the ON bar engages the gate', () async {
      final c = boot();
      // 3.0 m/s ≈ 6.7 mph — above kMotionOnMps (2.235). From rest, the gate
      // LATCHES ON: the keyboard goes away.
      final state = await tickAt(c, 3.0);
      expect(
        state.inMotion,
        isTrue,
        reason: '🔴 the gate stayed OPEN above the ON threshold. A driver at '
            '6.7 mph is DRIVING and the keyboard must be gone. An inverted '
            'compare or an mph/m·s⁻¹ unit bug lands here.',
      );
      expect(state.speedMps, 3.0);
    });

    test(
        'right at the ON boundary: strictly above engages, exactly-at does not',
        () async {
      // The compare is `speed > kMotionOnMps` (strict). A hair above engages;
      // the constant itself does not. This is the assertion a `>=`/`>` slip or
      // a shifted constant fails.
      var c = boot();
      final justAbove = await tickAt(c, kMotionOnMps + 0.001);
      expect(
        justAbove.inMotion,
        isTrue,
        reason: 'a speed just above kMotionOnMps did not engage the gate',
      );

      c = boot();
      final exactlyAt = await tickAt(c, kMotionOnMps);
      expect(
        exactlyAt.inMotion,
        isFalse,
        reason: 'the ON compare is strict (`speed > kMotionOnMps`); the '
            'constant itself must not engage the gate',
      );
    });

    test(
        'HYSTERESIS: inside the band [kMotionOffMps, kMotionOnMps] the gate '
        'holds whatever it already was', () async {
      final c = boot();

      // Engage above the ON bar.
      expect((await tickAt(c, 3.0)).inMotion, isTrue);

      // Now creep DOWN into the band (e.g. a red light): 1.8 m/s ≈ 4.0 mph —
      // below the ON bar but ABOVE the OFF bar. A single-threshold gate would
      // strobe the composer back in here. The real gate must HOLD.
      final inBand = await tickAt(c, 1.8);
      expect(
        inBand.inMotion,
        isTrue,
        reason: '🔴 the gate released inside the hysteresis band. It was ON '
            'and 1.8 m/s is above kMotionOffMps (1.5) — releasing here strobes '
            'the composer every time the driver creeps at a light.',
      );

      // Drop below the OFF bar: NOW it releases.
      final released = await tickAt(c, 1.0);
      expect(
        released.inMotion,
        isFalse,
        reason: '🔴 the gate did not release below the OFF threshold. Below '
            'kMotionOffMps (1.5 m/s) the driver has stopped and their keyboard '
            'must come back.',
      );
    });

    test(
        'HYSTERESIS the other way: from rest, a speed inside the band does NOT '
        'engage', () async {
      final c = boot();
      // 2.0 m/s is inside the band. From OFF, only strictly above kMotionOnMps
      // engages — the band must not pull an at-rest gate ON.
      final state = await tickAt(c, 2.0);
      expect(
        state.inMotion,
        isFalse,
        reason: 'a resting gate engaged at a band speed; only >kMotionOnMps '
            'should latch ON',
      );
    });

    test(
        'IGNORANCE DEGRADES OPEN: a null speed never takes the keyboard away, '
        'even after the gate was ON', () async {
      final c = boot();
      expect((await tickAt(c, 3.0)).inMotion, isTrue);

      // The platform stops vouching for its speed (speedAccuracy <= 0 → null).
      final unknown = await tickAt(c, null);
      expect(
        unknown.inMotion,
        isFalse,
        reason: '🔴 a null speed left the gate ON. Null is "we do not know", '
            'not "40 mph" — a parked driver with a junk fix must keep typing.',
      );
      expect(unknown.speedMps, isNull);
    });
  });
}

/// A [DriverLocationService] whose only interesting behaviour is a scripted
/// speed. Everything else answers the way the live seam would on a granted,
/// full-coverage device — none of it is read by the motion interactor, which
/// only ever calls [currentFix].
class _ScriptedSpeedService implements DriverLocationService {
  /// Wolverhampton — the demo world's origin, borrowed so the coordinates are
  /// plausible. The interactor ignores lat/lng entirely.
  static const double _lat = 52.5862;
  static const double _lng = -2.1281;

  /// The speed the next [currentFix] will report. Mutable so one instance can
  /// walk a profile across successive ticks (required to probe hysteresis).
  double? speedMps;

  @override
  Future<DriverFix?> currentFix({
    Duration timeout = const Duration(seconds: 10),
  }) async =>
      (lat: _lat, lng: _lng, speedMps: speedMps);

  @override
  Future<({double lat, double lng})?> currentPosition({
    Duration timeout = const Duration(seconds: 10),
  }) async =>
      (lat: _lat, lng: _lng);

  @override
  Future<bool> hasPermission() async => true;

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
  Future<bool> openSettings() async => true;
}
