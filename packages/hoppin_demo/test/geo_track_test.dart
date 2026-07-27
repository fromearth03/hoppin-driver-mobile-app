import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_demo/hoppin_demo.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

/// MAP-01/MAP-02 spatial ground truth and determinism proofs.
///
/// Part 1 — the committed OSRM Wolverhampton legs follow real streets,
/// terminate EXACTLY on the scripted pickup/dropoff coords (so pins and
/// track endpoints coincide), and [GeoTrack.pointAlong] is a pure, clamped,
/// deterministic interpolation over the committed cumulative-distance table.
///
/// Part 2 — [DemoWorld.driverPositionFor] emits the car's position as a
/// PURE FUNCTION of already-persisted world state: same seed + same virtual
/// instant = same lat/lng, across runs AND across snapshot restore, with
/// ZERO snapshot-codec changes.
///
/// Script timings with seed 42: match 4.2s after request, ETA 120s, floors
/// into arrivingHold at ~124.2s, arrived ~126.7s, inTrip ~130.7s,
/// completed ~205.7s, archived ~208.7s. Driver scenario: offer ~5.0s after
/// going online.
void main() {
  group('GeoTrack legs', () {
    test('approach starts at the Molineux spawn, ends exactly on the pickup',
        () {
      final first = GeoTrack.approach.points.first;
      expect(first.lat, closeTo(52.5903, 0.002));
      expect(first.lng, closeTo(-2.1306, 0.002));
      final last = GeoTrack.approach.points.last;
      expect(last.lat, 52.5877);
      expect(last.lng, -2.1200);
    });

    test('trip runs exactly pickup -> dropoff (scripted coords, both ends)',
        () {
      final first = GeoTrack.trip.points.first;
      expect(first.lat, 52.5877);
      expect(first.lng, -2.1200);
      final last = GeoTrack.trip.points.last;
      expect(last.lat, 52.6046);
      expect(last.lng, -2.0930);
    });

    test('cumulative distances start at zero and are strictly monotonic', () {
      for (final leg in [GeoTrack.approach, GeoTrack.trip]) {
        expect(leg.points.first.cumulativeMeters, 0.0);
        for (var i = 1; i < leg.points.length; i++) {
          expect(
            leg.points[i].cumulativeMeters,
            greaterThan(leg.points[i - 1].cumulativeMeters),
            reason: 'zero/negative segment at index $i',
          );
        }
      }
    });

    test('leg lengths are road-plausible for the Wolverhampton routes', () {
      // Molineux -> Rail Station: ~1 km crow-flies, so 1-3 km by road.
      expect(GeoTrack.approach.lengthMeters, inInclusiveRange(1000, 3000));
      // Rail Station -> New Cross Hospital: ~2 km crow-flies, 2-5 km by road.
      expect(GeoTrack.trip.lengthMeters, inInclusiveRange(2000, 5000));
    });

    test('every bearing is a sane compass value in [0, 360)', () {
      for (final leg in [GeoTrack.approach, GeoTrack.trip]) {
        for (final point in leg.points) {
          expect(point.bearingDeg, greaterThanOrEqualTo(0));
          expect(point.bearingDeg, lessThan(360));
        }
      }
    });
  });

  group('GeoTrack.pointAlong', () {
    test('t=0 returns exactly the first point', () {
      for (final leg in [GeoTrack.approach, GeoTrack.trip]) {
        final (lat, lng, bearing) = GeoTrack.pointAlong(leg, 0);
        expect(lat, leg.points.first.lat);
        expect(lng, leg.points.first.lng);
        expect(bearing, leg.points.first.bearingDeg);
      }
    });

    test('t=1 returns exactly the last point', () {
      for (final leg in [GeoTrack.approach, GeoTrack.trip]) {
        final (lat, lng, _) = GeoTrack.pointAlong(leg, 1);
        expect(lat, leg.points.last.lat);
        expect(lng, leg.points.last.lng);
      }
    });

    test('t=0.5 lies between its cumulative-table neighbours', () {
      final leg = GeoTrack.trip;
      final (lat, lng, _) = GeoTrack.pointAlong(leg, 0.5);
      final target = 0.5 * leg.lengthMeters;
      var i = 0;
      while (i < leg.points.length - 2 &&
          leg.points[i + 1].cumulativeMeters < target) {
        i++;
      }
      final a = leg.points[i];
      final b = leg.points[i + 1];
      expect(a.cumulativeMeters, lessThanOrEqualTo(target));
      expect(b.cumulativeMeters, greaterThanOrEqualTo(target));
      expect(
        lat,
        inInclusiveRange(
          a.lat < b.lat ? a.lat : b.lat,
          a.lat < b.lat ? b.lat : a.lat,
        ),
      );
      expect(
        lng,
        inInclusiveRange(
          a.lng < b.lng ? a.lng : b.lng,
          a.lng < b.lng ? b.lng : a.lng,
        ),
      );
    });

    test('t outside [0, 1] clamps to the endpoints', () {
      final leg = GeoTrack.approach;
      final below = GeoTrack.pointAlong(leg, -0.5);
      expect(below.$1, leg.points.first.lat);
      expect(below.$2, leg.points.first.lng);
      final above = GeoTrack.pointAlong(leg, 1.7);
      expect(above.$1, leg.points.last.lat);
      expect(above.$2, leg.points.last.lng);
    });

    test('bearing at trip t=0 is a sane compass value', () {
      final (_, _, bearing) = GeoTrack.pointAlong(GeoTrack.trip, 0);
      expect(bearing, greaterThanOrEqualTo(0));
      expect(bearing, lessThan(360));
    });

    test('same t always yields the same point — pure and deterministic', () {
      for (final t in [0.0, 0.25, 0.4, 0.5, 0.75, 1.0]) {
        expect(
          GeoTrack.pointAlong(GeoTrack.trip, t),
          GeoTrack.pointAlong(GeoTrack.trip, t),
        );
      }
    });
  });

  // ---- Part 2: world-level emission -----------------------------------------

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
  /// Leaves the fake clock at t=6.0s (match landed at 4.2s).
  String matchedRideId(FakeAsync async, FakeRidesRepository rides) {
    resolve(async, requestScriptedRide(rides));
    async.elapse(const Duration(seconds: 6));
    return resolve(async, rides.history(limit: 10)).first.id;
  }

  group('DemoWorld.driverPositionFor', () {
    test('idle world and wrong ride ids answer null', () {
      FakeAsync().run((async) {
        final world = riderWorld()..markSignedIn();
        expect(world.driverPositionFor('any-id'), isNull);

        final rides = FakeRidesRepository(world);
        final rideId = matchedRideId(async, rides);
        expect(world.driverPositionFor('not-the-live-ride'), isNull);
        expect(world.driverPositionFor(rideId), isNotNull);
        world.reset();
      });
    });

    test('matching offer parks the car at the Molineux spawn (driver world)',
        () {
      FakeAsync().run((async) {
        final world = driverWorld()..markSignedIn();
        world.goOnline();
        async.elapse(const Duration(seconds: 6));

        final offer = world.pendingOffers().single;
        final spawn = GeoTrack.approach.points.first;
        final pos = world.driverPositionFor(offer.rideId)!;
        expect(pos.lat, spawn.lat);
        expect(pos.lng, spawn.lng);
        expect(pos.heading, spawn.bearingDeg);
        expect(world.driverPositionFor('some-other-ride'), isNull);

        // The offered ride also serves geometry pre-accept — the MAP-04
        // offer inset draws driver->pickup context from this.
        expect(world.rideGeoFor(offer.rideId), isNotNull);
        world.reset();
      });
    });

    test('accepted with half the ETA elapsed sits at approach t=0.5', () {
      FakeAsync().run((async) {
        final world = riderWorld()..markSignedIn();
        final rides = FakeRidesRepository(world);
        final rideId = matchedRideId(async, rides);

        // t=6.0s -> t=64.2s: ETA started at 4.2s, so 60 of 120s remain.
        async.elapse(const Duration(milliseconds: 58200));
        expect(world.etaSecondsRemaining, 60);

        final expected = GeoTrack.pointAlong(GeoTrack.approach, 0.5);
        final pos = world.driverPositionFor(rideId)!;
        expect(pos.lat, expected.$1);
        expect(pos.lng, expected.$2);
        expect(pos.heading, expected.$3);
        // updatedAt derives from the VIRTUAL clock (anchor + elapsed run
        // time), never the wall clock.
        expect(
          pos.updatedAt,
          DemoSeed.anchor.add(const Duration(milliseconds: 64200)),
        );
        world.reset();
      });
    });

    test('arrivingHold floors the car onto the pickup', () {
      FakeAsync().run((async) {
        final world = riderWorld()..markSignedIn();
        final rides = FakeRidesRepository(world);
        final rideId = matchedRideId(async, rides);

        // t=6s -> t=125s: past the 124.2s floor, inside the 2.5s hold.
        async.elapse(const Duration(seconds: 119));
        expect(world.phase, WorldPhase.arrivingHold);

        final pos = world.driverPositionFor(rideId)!;
        expect(pos.lat, DemoPlaces.scriptedPickup.lat);
        expect(pos.lng, DemoPlaces.scriptedPickup.lng);
        world.reset();
      });
    });

    test('arrived parks exactly on the pickup (approach t=1)', () {
      FakeAsync().run((async) {
        final world = riderWorld()..markSignedIn();
        final rides = FakeRidesRepository(world);
        final rideId = matchedRideId(async, rides);

        // t=6s -> t=128s: arrived at ~126.7s, trip starts ~130.7s.
        async.elapse(const Duration(seconds: 122));
        expect(world.phase, WorldPhase.arrived);

        final pos = world.driverPositionFor(rideId)!;
        expect(pos.lat, DemoPlaces.scriptedPickup.lat);
        expect(pos.lng, DemoPlaces.scriptedPickup.lng);
        world.reset();
      });
    });

    test('in-trip 30s into the 75s leg sits at trip t=0.4', () {
      FakeAsync().run((async) {
        final world = riderWorld()..markSignedIn();
        final rides = FakeRidesRepository(world);
        final rideId = matchedRideId(async, rides);

        // t=6s -> t=160.7s: trip started at ~130.7s, so 30s of 75 elapsed.
        async.elapse(const Duration(milliseconds: 154700));
        expect(world.phase, WorldPhase.inTrip);

        final expected = GeoTrack.pointAlong(GeoTrack.trip, 0.4);
        final pos = world.driverPositionFor(rideId)!;
        expect(pos.lat, expected.$1);
        expect(pos.lng, expected.$2);
        expect(pos.heading, expected.$3);
        world.reset();
      });
    });

    test('completed parks exactly on the dropoff (trip t=1)', () {
      FakeAsync().run((async) {
        final world = riderWorld()..markSignedIn();
        final rides = FakeRidesRepository(world);
        final rideId = matchedRideId(async, rides);

        // t=6s -> t=207s: completed at ~205.7s, archived at ~208.7s.
        async.elapse(const Duration(milliseconds: 201000));
        expect(world.phase, WorldPhase.completed);

        final pos = world.driverPositionFor(rideId)!;
        expect(pos.lat, DemoPlaces.scriptedDropoff.lat);
        expect(pos.lng, DemoPlaces.scriptedDropoff.lng);
        world.reset();
      });
    });

    test('snapshot restore mid-trip resumes the exact position (F5-safe)', () {
      FakeAsync().run((async) {
        final store1 = InMemorySnapshotStore();
        final world1 =
            DemoWorld.riderScenario(seed: DemoSeed.seed, store: store1)
              ..restoreOrSeed();
        world1.markSignedIn();
        final rides = FakeRidesRepository(world1);
        final rideId = matchedRideId(async, rides);
        async.elapse(const Duration(milliseconds: 154700)); // trip t=0.4
        expect(world1.phase, WorldPhase.inTrip);

        // A data-only event persists the snapshot mid-trip — the codec
        // carries NO geo fields; position must rebuild from what already
        // round-trips (startedAtVirtualMs + virtualMs).
        world1.addSavedLocation(label: 'Persist beat', lat: 52.59, lng: -2.12);
        final pos1 = world1.driverPositionFor(rideId)!;
        final raw = store1.read()!;

        final store2 = InMemorySnapshotStore()..write(raw);
        final world2 =
            DemoWorld.riderScenario(seed: DemoSeed.seed, store: store2)
              ..restoreOrSeed();
        expect(world2.phase, WorldPhase.inTrip);

        final pos2 = world2.driverPositionFor(rideId)!;
        expect(pos2, pos1,
            reason: 'same virtual instant must rebuild the same position');
        world1.reset();
        world2.reset();
      });
    });

    test('same seed twice: positions at three instants are byte-identical',
        () {
      List<DriverPosition> run() {
        final samples = <DriverPosition>[];
        FakeAsync().run((async) {
          final world = riderWorld()..markSignedIn();
          final rides = FakeRidesRepository(world);
          final rideId = matchedRideId(async, rides);
          async.elapse(const Duration(milliseconds: 58200)); // 64.2s approach
          samples.add(world.driverPositionFor(rideId)!);
          async.elapse(const Duration(milliseconds: 96500)); // 160.7s in-trip
          samples.add(world.driverPositionFor(rideId)!);
          async.elapse(const Duration(milliseconds: 46300)); // 207s completed
          samples.add(world.driverPositionFor(rideId)!);
          world.reset();
        });
        return samples;
      }

      expect(run(), run());
    });
  });

  group('DemoWorld.rideGeoFor', () {
    test('serves scripted pins plus both track polylines for the live ride',
        () {
      FakeAsync().run((async) {
        final world = riderWorld()..markSignedIn();
        final rides = FakeRidesRepository(world);
        final rideId = matchedRideId(async, rides);

        final geo = world.rideGeoFor(rideId)!;
        expect(geo.pickupLat, DemoPlaces.scriptedPickup.lat);
        expect(geo.pickupLng, DemoPlaces.scriptedPickup.lng);
        expect(geo.dropoffLat, DemoPlaces.scriptedDropoff.lat);
        expect(geo.dropoffLng, DemoPlaces.scriptedDropoff.lng);

        expect(geo.route, hasLength(GeoTrack.trip.points.length));
        expect(geo.route.first.lat, GeoTrack.trip.points.first.lat);
        expect(geo.route.first.lng, GeoTrack.trip.points.first.lng);
        expect(geo.route.last.lat, GeoTrack.trip.points.last.lat);
        expect(geo.route.last.lng, GeoTrack.trip.points.last.lng);

        expect(geo.approach, isNotNull);
        expect(geo.approach, hasLength(GeoTrack.approach.points.length));
        expect(geo.approach!.first.lat, GeoTrack.approach.points.first.lat);
        expect(geo.approach!.last.lng, GeoTrack.approach.points.last.lng);
        world.reset();
      });
    });

    test('unknown ride ids and the idle world answer null', () {
      FakeAsync().run((async) {
        final world = riderWorld()..markSignedIn();
        expect(world.rideGeoFor('any-id'), isNull);
        final rides = FakeRidesRepository(world);
        final rideId = matchedRideId(async, rides);
        expect(world.rideGeoFor('not-the-live-ride'), isNull);
        expect(world.rideGeoFor(rideId), isNotNull);
        world.reset();
      });
    });
  });

  group('FakeRidesRepository geo seams', () {
    test('driverPosition and rideGeo are pure delegates over the world', () {
      FakeAsync().run((async) {
        final world = riderWorld()..markSignedIn();
        final rides = FakeRidesRepository(world);
        final rideId = matchedRideId(async, rides);

        expect(
          resolve(async, rides.driverPosition(rideId)),
          world.driverPositionFor(rideId),
        );
        expect(
          resolve(async, rides.rideGeo(rideId)),
          world.rideGeoFor(rideId),
        );
        expect(resolve(async, rides.driverPosition('nope')), isNull);
        expect(resolve(async, rides.rideGeo('nope')), isNull);
        world.reset();
      });
    });
  });
}
