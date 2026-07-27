import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_demo/hoppin_demo.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

/// DEMO-07 acceptance: the world assembles [RideDriverInfo] for the scripted
/// live ride (Gurpreet + the Silver Prius + clock-honest ETA + real labels)
/// and the seeded history cast; pre-match and unknown rides answer null; the
/// fake repository is a pure one-line delegate over [DemoWorld.driverInfoFor].
///
/// Script timings with seed 42: match 4.2s after request, ETA 120s, floors
/// into arrivingHold at ~124.2s, arrived ~126.7s, inTrip ~130.7s,
/// completed ~205.7s, archived ~208.7s.
void main() {
  DemoWorld riderWorld() => DemoWorld.riderScenario(
      seed: DemoSeed.seed, store: InMemorySnapshotStore())
    ..restoreOrSeed();

  DemoWorld driverWorld() => DemoWorld.driverScenario(
      seed: DemoSeed.seed, store: InMemorySnapshotStore())
    ..restoreOrSeed();

  /// Resolves a fake's Future synchronously under fake time.
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

  Future<String> requestScriptedRide(FakeRidesRepository rides) =>
      rides.requestRide(
        pickupLat: DemoPlaces.scriptedPickup.lat,
        pickupLng: DemoPlaces.scriptedPickup.lng,
        dropoffLat: DemoPlaces.scriptedDropoff.lat,
        dropoffLng: DemoPlaces.scriptedDropoff.lng,
      );

  /// Runs the request through the match beat and returns the live ride id.
  String matchedRideId(FakeAsync async, FakeRidesRepository rides) {
    resolve(async, requestScriptedRide(rides));
    async.elapse(const Duration(seconds: 6));
    return resolve(async, rides.history(limit: 10)).first.id;
  }

  group('DemoWorld.driverInfoFor', () {
    test('pre-match ride has no driver info', () {
      FakeAsync().run((async) {
        // Driver scenario: the scripted incoming request materializes a ride
        // row in `matching` with driverId still null — no identity to serve.
        final world = driverWorld()..markSignedIn();
        world.goOnline();
        async.elapse(const Duration(seconds: 6));

        final offer = world.pendingOffers().single;
        final ride = world.rideById(offer.rideId);
        expect(ride.driverId, isNull,
            reason: 'the pre-accept ride row must be unassigned');
        expect(world.driverInfoFor(offer.rideId), isNull);
      });
    });

    test('accepted live ride serves Gurpreet with live ETA and labels', () {
      FakeAsync().run((async) {
        final world = riderWorld()..markSignedIn();
        final rides = FakeRidesRepository(world);
        final rideId = matchedRideId(async, rides);

        final info = world.driverInfoFor(rideId);
        expect(info, isNotNull);
        expect(info!.fullName, 'Gurpreet Singh');
        expect(info.plate, 'BK72 WNH');
        expect(info.vehicleColour, 'Silver');
        expect(info.vehicleMake, 'Toyota');
        expect(info.vehicleModel, 'Prius');
        expect(info.rating, 4.9);
        expect(info.tripsCount, greaterThan(0));
        expect(info.etaSeconds, isNotNull,
            reason: 'accepted phase must carry the live countdown');
        expect(info.etaSeconds, world.etaSecondsRemaining);
        expect(info.etaSeconds, lessThanOrEqualTo(120));
        expect(info.originLabel, 'Wolverhampton Rail Station');
        expect(info.destinationLabel, 'New Cross Hospital');
      });
    });

    test('ETA follows the world clock', () {
      FakeAsync().run((async) {
        final world = riderWorld()..markSignedIn();
        final rides = FakeRidesRepository(world);
        final rideId = matchedRideId(async, rides);

        final before = world.driverInfoFor(rideId)!.etaSeconds!;
        async.elapse(const Duration(seconds: 30));
        final after = world.driverInfoFor(rideId)!.etaSeconds!;

        expect(after, before - 30,
            reason: 'a fresh call must report the clock delta, not a cache');
        // Match landed 4.2s into the run; sampled at 36s the countdown reads
        // ceil(120 - 31.8) = 89 — "approximately 90" via the exact clock math.
        expect(after, closeTo(90, 2));
      });
    });

    test('arrivingHold serves etaSeconds 0', () {
      FakeAsync().run((async) {
        final world = riderWorld()..markSignedIn();
        final rides = FakeRidesRepository(world);
        final rideId = matchedRideId(async, rides);

        // t=6s -> t=125s: past the 124.2s floor, inside the 2.5s hold.
        async.elapse(const Duration(seconds: 119));
        expect(world.phase, WorldPhase.arrivingHold);

        final info = world.driverInfoFor(rideId)!;
        expect(info.etaSeconds, 0);
        expect(info.originLabel, 'Wolverhampton Rail Station');
      });
    });

    test('in-trip and completed serve etaSeconds null, labels still present',
        () {
      FakeAsync().run((async) {
        final world = riderWorld()..markSignedIn();
        final rides = FakeRidesRepository(world);
        final rideId = matchedRideId(async, rides);

        // t=6s -> t=140s: arrived (~126.7s) then started (~130.7s).
        async.elapse(const Duration(seconds: 134));
        expect(world.phase, WorldPhase.inTrip);
        var info = world.driverInfoFor(rideId)!;
        expect(info.fullName, 'Gurpreet Singh');
        expect(info.etaSeconds, isNull);
        expect(info.originLabel, 'Wolverhampton Rail Station');
        expect(info.destinationLabel, 'New Cross Hospital');

        // t=140s -> t=207s: completed (~205.7s), before the archive beat.
        async.elapse(const Duration(seconds: 67));
        expect(world.phase, WorldPhase.completed);
        info = world.driverInfoFor(rideId)!;
        expect(info.etaSeconds, isNull);
        expect(info.originLabel, 'Wolverhampton Rail Station');
        expect(info.destinationLabel, 'New Cross Hospital');
      });
    });

    test('seeded history ride resolves the historyCast driver', () {
      FakeAsync().run((async) {
        final world = riderWorld()..markSignedIn();
        final trip = DemoHistory.trips.first;

        final info = world.driverInfoFor(trip.ride.id);
        expect(info, isNotNull);
        expect(info!.fullName, 'Amara Okafor');
        expect(info.vehicleColour, 'Grey');
        expect(info.vehicleMake, 'Skoda');
        expect(info.vehicleModel, 'Octavia');
        expect(info.plate, 'BD23 VXA');
        expect(info.etaSeconds, isNull,
            reason: 'a finished history trip has no countdown');
        expect(info.originLabel, trip.pickup.label);
        expect(info.destinationLabel, trip.dropoff.label);
      });
    });

    test('unknown ride id returns null (never throws)', () {
      FakeAsync().run((async) {
        final world = riderWorld()..markSignedIn();
        expect(world.driverInfoFor('not-a-ride-id'), isNull);
        expect(
          world.driverInfoFor('e0000000-0000-4000-8000-00000000ffff'),
          isNull,
        );
      });
    });
  });

  group('FakeRidesRepository.driverInfo', () {
    test('delegates to the world', () {
      FakeAsync().run((async) {
        final world = riderWorld()..markSignedIn();
        final rides = FakeRidesRepository(world);
        final rideId = matchedRideId(async, rides);

        final viaRepo = resolve(async, rides.driverInfo(rideId));
        expect(viaRepo, world.driverInfoFor(rideId),
            reason: 'the fake must be a pure delegate over the seam');
        expect(viaRepo!.fullName, 'Gurpreet Singh');
        expect(viaRepo.plate, 'BK72 WNH');
      });
    });

    test('answers null for unknown ids through the repository surface', () {
      FakeAsync().run((async) {
        final rides = FakeRidesRepository(riderWorld());
        expect(resolve(async, rides.driverInfo('nope')), isNull);
      });
    });
  });

  group('DemoPersona.tripsCount', () {
    test('every persona carries a positive trips count', () {
      final counts = <int>[
        DemoPersonas.rider.tripsCount,
        DemoPersonas.driver.tripsCount,
        for (final member in DemoPersonas.historyCast)
          member.persona.tripsCount,
      ];
      for (final count in counts) {
        expect(count, greaterThan(0));
      }
      // Varied, Wolverhampton-plausible working-driver numbers.
      expect(counts.toSet().length, counts.length,
          reason: 'trip counts must vary across the cast');
    });
  });
}
