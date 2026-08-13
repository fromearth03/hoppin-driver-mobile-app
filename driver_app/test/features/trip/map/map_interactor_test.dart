import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/trip/map/map_builder.dart';
import 'package:hoppin_driver/features/trip/map/map_state.dart';
import 'package:hoppin_driver/features/trip/trip_runner_builder.dart';
import 'package:hoppin_driver/features/trip/trip_runner_interactor.dart';
import 'package:hoppin_driver/features/trip/trip_runner_state.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:hoppin_ui/hoppin_ui.dart'
    show FollowPoint, HopGeoPoint, HopMapPin, HopMapPinRole, HopMapTrack;

/// Interactor unit layer (riblet testing contract, DOCS/05) for the driver
/// map riblet — MAP-04's brain:
///
/// - OBJECTIVE = f(TripRunner stage): pre-start phases frame the approach
///   leg with a pickup objective; a started trip flips pin, track, and
///   label TOGETHER in one state emission.
/// - Degradation is designed: a null approach leg renders the pickup pin
///   without showing pickup→dropoff as if it led to pickup; both
///   seams null hides the map entirely.
/// - remainingMeters sums the current leg from the car's nearest vertex.
/// - Poll hygiene matches the rider riblet contract: 1 Hz driverPosition,
///   rideGeo fetched once, transient throws tolerated, the generation
///   guard gates in-flight writes across dispose.
///
/// FakeAsync throughout; containers dispose before the zone closes.
void main() {
  // Wolverhampton-shaped stub geometry. The approach mid vertex shares the
  // pickup's longitude so the remaining-distance expectation is a single
  // clean haversine along a meridian.
  const spawn = GeoPoint(lat: 52.5903, lng: -2.1306);
  const approachMid = GeoPoint(lat: 52.5890, lng: -2.1200);
  const pickup = GeoPoint(lat: 52.5877, lng: -2.1200);
  const routeMid = GeoPoint(lat: 52.5960, lng: -2.1060);
  const dropoff = GeoPoint(lat: 52.6046, lng: -2.0930);

  const approachLeg = [spawn, approachMid, pickup];
  const routeLeg = [pickup, routeMid, dropoff];

  RideGeo geo({bool withApproach = true}) => RideGeo(
    pickupLat: pickup.lat,
    pickupLng: pickup.lng,
    dropoffLat: dropoff.lat,
    dropoffLng: dropoff.lng,
    route: routeLeg,
    approach: withApproach ? approachLeg : null,
  );

  DriverPosition positionAt(GeoPoint point, {double? heading}) =>
      DriverPosition(
        lat: point.lat,
        lng: point.lng,
        heading: heading,
        updatedAt: clock.now(),
      );

  HopGeoPoint hop(GeoPoint p) => HopGeoPoint(p.lat, p.lng);

  test('headingToPickup: pickup objective, approach track, chase camera', () {
    FakeAsync().run((async) {
      final repo = _GeoRepo(
        geo: geo(),
        position: positionAt(spawn, heading: 90),
      );
      final h = _Harness(repo);
      async.flushMicrotasks();

      expect(h.state.phase, MapPhase.liveTracking);
      expect(h.state.objectiveLabel, 'Pickup');
      expect(h.state.pins, [
        HopMapPin(hop(pickup), HopMapPinRole.objective),
        HopMapPin(hop(dropoff), HopMapPinRole.destination),
      ]);
      expect(h.state.track, HopMapTrack([for (final p in approachLeg) hop(p)]));
      expect(h.state.carPosition, hop(spawn));
      expect(h.state.carHeading, 90);
      expect(h.state.cameraIntent, FollowPoint(hop(spawn)));

      h.dispose();
    });
  });

  test('arrivedAtPickup: objective stays pickup, the parked car is stable', () {
    FakeAsync().run((async) {
      final repo = _GeoRepo(geo: geo(), position: positionAt(pickup));
      final h = _Harness(repo);
      async.flushMicrotasks();
      h.runner.drive(TripPhase.arrivedAtPickup);
      async.elapse(const Duration(seconds: 3));

      expect(h.state.phase, MapPhase.liveTracking);
      expect(h.state.objectiveLabel, 'Pickup');
      expect(
        h.state.pins,
        contains(HopMapPin(hop(pickup), HopMapPinRole.objective)),
      );
      expect(
        h.state.carPosition,
        hop(pickup),
        reason: 'the car parks at the pickup across ticks — no drift',
      );

      h.dispose();
    });
  });

  test('trip start flips pin, track, and label together in ONE emission', () {
    FakeAsync().run((async) {
      final repo = _GeoRepo(geo: geo(), position: positionAt(pickup));
      final h = _Harness(repo);
      async.flushMicrotasks();
      h.runner.drive(TripPhase.arrivedAtPickup);
      async.elapse(const Duration(seconds: 1));
      h.emissions.clear();

      h.runner.drive(TripPhase.inTrip);

      expect(
        h.emissions,
        hasLength(1),
        reason: 'the objective flip is atomic — one state emission',
      );
      final flipped = h.emissions.single;
      expect(flipped.objectiveLabel, 'Drop-off');
      expect(flipped.pins, [
        HopMapPin(hop(pickup), HopMapPinRole.pickup),
        HopMapPin(hop(dropoff), HopMapPinRole.objective),
      ]);
      expect(flipped.track, HopMapTrack([for (final p in routeLeg) hop(p)]));
      expect(
        flipped.cameraIntent,
        FollowPoint(hop(pickup)),
        reason: 'the chase camera keeps following the car through the flip',
      );

      h.dispose();
    });
  });

  test('null approach does not draw the wrong pickup-to-dropoff leg', () {
    FakeAsync().run((async) {
      final repo = _GeoRepo(
        geo: geo(withApproach: false),
        position: positionAt(spawn),
      );
      final h = _Harness(repo);
      async.flushMicrotasks();

      expect(h.state.phase, MapPhase.liveTracking);
      expect(h.state.objectiveLabel, 'Pickup');
      expect(
        h.state.pins,
        contains(HopMapPin(hop(pickup), HopMapPinRole.objective)),
      );
      expect(
        h.state.track,
        isNull,
        reason:
            'the pickup-to-dropoff route does not lead the driver to '
            'pickup and must not be drawn before the trip starts',
      );
      expect(
        h.state.remainingMeters,
        isNull,
        reason:
            'the route leg does not end at the pickup — no honest '
            'along-leg distance exists, so the chip hides',
      );

      h.dispose();
    });
  });

  test('OSRM-snapped route endpoints are joined to the exact pins', () {
    FakeAsync().run((async) {
      const snappedRoute = [
        GeoPoint(lat: 52.5879, lng: -2.1197),
        routeMid,
        GeoPoint(lat: 52.6044, lng: -2.0933),
      ];
      final repo = _GeoRepo(
        geo: RideGeo(
          pickupLat: pickup.lat,
          pickupLng: pickup.lng,
          dropoffLat: dropoff.lat,
          dropoffLng: dropoff.lng,
          route: snappedRoute,
        ),
        position: positionAt(pickup),
      );
      final h = _Harness(repo);
      async.flushMicrotasks();
      h.runner.drive(TripPhase.inTrip);

      expect(h.state.track!.points.first, hop(pickup));
      expect(h.state.track!.points.last, hop(dropoff));

      h.dispose();
    });
  });

  test('remainingMeters sums the leg from the car vertex to the objective', () {
    FakeAsync().run((async) {
      final repo = _GeoRepo(geo: geo(), position: positionAt(approachMid));
      final h = _Harness(repo);
      async.flushMicrotasks();

      final lastSegment = _haversineMeters(hop(approachMid), hop(pickup));
      expect(
        h.state.remainingMeters!.toDouble(),
        closeTo(lastSegment, lastSegment * 0.01),
      );

      // From the spawn vertex the remaining distance is the whole leg.
      repo.position = positionAt(spawn);
      async.elapse(const Duration(seconds: 1));
      final wholeLeg =
          _haversineMeters(hop(spawn), hop(approachMid)) +
          _haversineMeters(hop(approachMid), hop(pickup));
      expect(
        h.state.remainingMeters!.toDouble(),
        closeTo(wholeLeg, wholeLeg * 0.01),
      );

      h.dispose();
    });
  });

  test('both seams null: MapPhase.hidden, rideGeo fetched exactly once', () {
    FakeAsync().run((async) {
      final repo = _GeoRepo();
      final h = _Harness(repo);
      async.flushMicrotasks();

      expect(h.state.phase, MapPhase.hidden);

      async.elapse(const Duration(seconds: 5));
      expect(h.state.phase, MapPhase.hidden);
      expect(
        repo.rideGeoCalls,
        1,
        reason: 'static geometry is a one-shot fetch, never hammered',
      );
      expect(repo.positionCalls, 6, reason: 'initial poll + five 1 Hz ticks');

      h.dispose();
    });
  });

  test('transient seam throws keep the last shown state', () {
    FakeAsync().run((async) {
      final repo = _GeoRepo(geo: geo(), position: positionAt(spawn));
      final h = _Harness(repo);
      async.flushMicrotasks();
      expect(h.state.phase, MapPhase.liveTracking);

      repo.throwOnPosition = true;
      async.elapse(const Duration(seconds: 2));
      expect(h.state.phase, MapPhase.liveTracking);
      expect(
        h.state.carPosition,
        hop(spawn),
        reason: 'a transient telemetry failure never blanks the map',
      );

      h.dispose();
    });
  });

  test('dispose cancels the poll and gates the in-flight write', () {
    FakeAsync().run((async) {
      final repo = _GeoRepo(geo: geo());
      final gate = Completer<DriverPosition?>();
      repo.positionGate = gate;
      final h = _Harness(repo);
      async.flushMicrotasks();
      expect(repo.positionCalls, 1);

      // Dispose while the first poll is suspended on the seam…
      h.dispose();
      gate.complete(positionAt(spawn));
      async.flushMicrotasks();

      // …the generation guard discards the landing instead of writing to a
      // dead notifier, and the 1 Hz timer is gone with ref.onDispose.
      async.elapse(const Duration(seconds: 3));
      expect(repo.positionCalls, 1);
      expect(async.pendingTimers, isEmpty);
    });
  });

  test('a slow read cannot create overlapping out-of-order polls', () {
    FakeAsync().run((async) {
      final gate = Completer<DriverPosition?>();
      final repo = _GeoRepo(geo: geo(), positionGate: gate);
      final h = _Harness(repo);
      async.flushMicrotasks();

      async.elapse(const Duration(seconds: 3));
      expect(
        repo.positionCalls,
        1,
        reason: 'timer ticks are skipped while one read is still in flight',
      );

      gate.complete(positionAt(spawn));
      repo.positionGate = null;
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 1));
      expect(repo.positionCalls, 2);

      h.dispose();
    });
  });
}

/// Nearest-vertex expectation math — the same haversine the interactor
/// hand-rolls (the sanctioned pure-Dart exception; no latlong2 in apps).
double _haversineMeters(HopGeoPoint a, HopGeoPoint b) {
  const earthRadiusMeters = 6371000.0;
  double rad(double deg) => deg * math.pi / 180;
  final dLat = rad(b.lat - a.lat);
  final dLng = rad(b.lng - a.lng);
  final sinLat = math.sin(dLat / 2);
  final sinLng = math.sin(dLng / 2);
  final h =
      sinLat * sinLat +
      math.cos(rad(a.lat)) * math.cos(rad(b.lat)) * sinLng * sinLng;
  return 2 * earthRadiusMeters * math.asin(math.sqrt(h));
}

/// Injected harness: the map interactor sees ONLY the stub geo seams and a
/// drivable runner-phase stub; emissions record every state the notifier
/// publishes.
class _Harness {
  _Harness(this.repo) {
    container = ProviderContainer(
      overrides: [
        ridesRepositoryProvider.overrideWithValue(repo),
        tripRunnerInteractorProvider.overrideWith2((rideId) => runner),
      ],
    );
    // Keep the interactor actively listened (the view's ref.watch in
    // production) — Riverpod 3 pauses an unlistened provider.
    _sub = container.listen(
      tripMapInteractorProvider('ride-1'),
      (_, next) => emissions.add(next),
    );
  }

  final _GeoRepo repo;
  final runner = _StubRunner();
  final emissions = <MapState>[];
  late final ProviderContainer container;
  late final ProviderSubscription<MapState> _sub;

  MapState get state => container.read(tripMapInteractorProvider('ride-1'));

  void dispose() {
    _sub.close();
    container.dispose();
  }
}

/// Drivable trip-runner stub: build() returns the initial heading state and
/// [drive] walks the phase forward (the objective input under test).
class _StubRunner extends TripRunnerInteractor {
  _StubRunner() : super('ride-1');

  @override
  TripRunnerState build() => const TripRunnerState(rideId: 'ride-1');

  void drive(TripPhase phase) => state = state.copyWith(phase: phase);
}

/// Recording geo seams: nullable position/geometry, an optional gate for
/// in-flight dispose proofs, and a throw switch for transient tolerance.
class _GeoRepo implements RidesRepository {
  _GeoRepo({this.geo, this.position, this.positionGate});

  RideGeo? geo;
  DriverPosition? position;
  bool throwOnPosition = false;
  Completer<DriverPosition?>? positionGate;
  int rideGeoCalls = 0;
  int positionCalls = 0;

  @override
  Future<DriverPosition?> driverPosition(String rideId) {
    positionCalls++;
    if (throwOnPosition) return Future.error(Exception('telemetry down'));
    final gate = positionGate;
    if (gate != null) return gate.future;
    return Future.value(position);
  }

  @override
  Future<RideGeo?> rideGeo(String rideId) {
    rideGeoCalls++;
    return Future.value(geo);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
