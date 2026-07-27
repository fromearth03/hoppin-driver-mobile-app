import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_demo/hoppin_demo.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

/// Scheduled-rides demo acceptance: [FakeRidesRepository] serves the
/// `/scheduled-rides` surface from deterministic in-memory state — one
/// seeded future booking (tomorrow 08:30, the New Cross Hospital
/// appointment run) plus session creations, mirroring the live contract's
/// ≥30-minute rule with the same `{ error, code }` shapes.
void main() {
  DemoWorld riderWorld() => DemoWorld.riderScenario(
        seed: DemoSeed.seed,
        store: InMemorySnapshotStore(),
      )..restoreOrSeed();

  /// Resolves a fake's Future synchronously under fake time — every fake
  /// wraps a synchronous read, so a microtask flush must complete it.
  T resolve<T>(FakeAsync async, Future<T> future) {
    late T value;
    var done = false;
    future.then((v) {
      value = v;
      done = true;
    });
    async.flushMicrotasks();
    expect(done, isTrue, reason: 'fakes must not need real time to complete');
    return value;
  }

  /// The error a fake's Future completes with, or null when it succeeds.
  Object? errorOf(FakeAsync async, Future<void> Function() call) {
    Object? error;
    call().then((_) {}, onError: (Object e) {
      error = e;
    });
    async.flushMicrotasks();
    return error;
  }

  /// Tomorrow 08:30 relative to the seeded anchor (Tue 30 June 2026 09:30).
  final tomorrowAt0830 = DateTime(2026, 7, 1, 8, 30);

  group('seeded scheduled ride', () {
    test('scheduledRides serves exactly one pending booking tomorrow 08:30',
        () {
      FakeAsync().run((async) {
        final rides = FakeRidesRepository(riderWorld());

        final scheduled = resolve(async, rides.scheduledRides());
        expect(scheduled, hasLength(1));
        expect(scheduled.single.requestedPickupTime, tomorrowAt0830);
        expect(scheduled.single.status, 'pending');
        expect(scheduled.single.riderId, DemoSeed.riderId);
        expect(scheduled.single.activeRideId, isNull,
            reason: 'a pending booking has not converted to a ride yet');
      });
    });

    test('scheduledRide fetches the seeded booking by id', () {
      FakeAsync().run((async) {
        final rides = FakeRidesRepository(riderWorld());

        final seeded = resolve(async, rides.scheduledRides()).single;
        final fetched = resolve(async, rides.scheduledRide(seeded.id));
        expect(fetched, seeded);
      });
    });

    test('scheduledRide rejects an unknown id with the 404 shape', () {
      // Live currently surfaces this as 500 INTERNAL (gap #22); the demo
      // serves the corrected 404 the backend was asked for.
      FakeAsync().run((async) {
        final rides = FakeRidesRepository(riderWorld());

        final error = errorOf(
          async,
          () => rides.scheduledRide('e1000000-0000-4000-8000-0000000000ff'),
        );
        expect(
          error,
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 404)
              .having((e) => e.code, 'code', 'NOT_FOUND'),
        );
      });
    });
  });

  group('createScheduledRide', () {
    test('books a future ride: pending row appended with a fresh id', () {
      FakeAsync().run((async) {
        final rides = FakeRidesRepository(riderWorld());
        final pickupTime = DateTime(2026, 7, 2, 18, 15);

        final created = resolve(
          async,
          rides.createScheduledRide(
            pickupLat: DemoPlaces.home.lat,
            pickupLng: DemoPlaces.home.lng,
            dropoffLat: DemoPlaces.newCrossHospital.lat,
            dropoffLng: DemoPlaces.newCrossHospital.lng,
            requestedPickupTime: pickupTime,
            estimatedFareId: 'fare-demo-1',
          ),
        );
        expect(created.status, 'pending');
        expect(created.riderId, DemoSeed.riderId);
        expect(created.requestedPickupTime, pickupTime);
        expect(created.estimatedFareId, 'fare-demo-1');

        final all = resolve(async, rides.scheduledRides());
        expect(all, hasLength(2));
        expect(all.map((s) => s.id).toSet(), hasLength(2),
            reason: 'every booking must carry a distinct id');
        expect(all, contains(created));
        expect(resolve(async, rides.scheduledRide(created.id)), created);
      });
    });

    test('rejects a pickup under 30 minutes out with VALIDATION_FAILED', () {
      FakeAsync().run((async) {
        final rides = FakeRidesRepository(riderWorld());

        // The virtual clock boots at the anchor (09:30) — 09:45 is only
        // 15 minutes out, inside the live contract's rejection window.
        final error = errorOf(
          async,
          () => rides.createScheduledRide(
            pickupLat: DemoPlaces.home.lat,
            pickupLng: DemoPlaces.home.lng,
            dropoffLat: DemoPlaces.newCrossHospital.lat,
            dropoffLng: DemoPlaces.newCrossHospital.lng,
            requestedPickupTime: DateTime(2026, 6, 30, 9, 45),
          ),
        );
        expect(
          error,
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having((e) => e.code, 'code', 'VALIDATION_FAILED'),
        );
        expect(resolve(async, rides.scheduledRides()), hasLength(1),
            reason: 'a rejected booking must not land in the list');
      });
    });
  });
}
