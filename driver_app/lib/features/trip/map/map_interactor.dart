import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:hoppin_ui/hoppin_ui.dart'
    show
        FitPoints,
        FollowPoint,
        HopGeoPoint,
        HopMapCameraIntent,
        HopMapPin,
        HopMapPinRole,
        HopMapTrack;

import '../trip_runner_builder.dart';
import '../trip_runner_state.dart';
import 'map_state.dart';

/// THE BRAIN of the driver map riblet (DOCS/05, MAP-04): a per-ride
/// nav-context state machine keyed by rideId (family arg via constructor,
/// Riverpod 3).
///
/// Geo flows IN from the capability seams (1 Hz driverPosition poll;
/// rideGeo fetched once); the OBJECTIVE is a pure function of the trip
/// runner's phase, read via `ref.listen` on the sibling brain — pre-start
/// phases frame the approach leg with a pickup objective, a started trip
/// flips pin + track + label together in one emission. The map is context,
/// not navigation: no turn-by-turn, no intents out.
///
/// No Flutter widget imports, no BuildContext, no navigation — the
/// hoppin_ui `show` clause above is the pure-Dart map vocabulary only.
class MapInteractor extends Notifier<MapState> {
  MapInteractor(this.rideId);

  /// The family argument: the ride this map contextualizes.
  final String rideId;

  /// Bumped on dispose; in-flight poll landings from an older generation
  /// discard their result instead of writing to a dead notifier
  /// (BookingController pattern — the rider riblet contract).
  int _generation = 0;

  Timer? _poll;
  RidesRepository? _rides;
  RideGeo? _geo;
  bool _geoFetched = false;
  DriverPosition? _position;
  TripPhase _phase = TripPhase.headingToPickup;

  @override
  MapState build() {
    final gen = ++_generation;
    _geo = null;
    _geoFetched = false;
    _position = null;
    // Captured once: the repository provider is a plain root singleton, and
    // holding it keeps the async poll body free of post-dispose ref reads.
    _rides = ref.read(ridesRepositoryProvider);
    _phase = ref.read(tripRunnerInteractorProvider(rideId)).phase;

    ref.onDispose(() {
      _generation++;
      _poll?.cancel();
    });

    // Objective in: the runner's phase IS the objective. Recompute only on
    // an actual phase change so pin, track, and label flip atomically.
    ref.listen(tripRunnerInteractorProvider(rideId), (previous, next) {
      if (next.phase == _phase) return;
      _phase = next.phase;
      _recompute();
    });

    _poll = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_pollOnce(gen));
    });
    unawaited(_pollOnce(gen));

    return const MapState();
  }

  /// Stable ticks (a parked car) never re-emit — MapState is value-equal.
  @override
  bool updateShouldNotify(MapState previous, MapState next) =>
      previous != next;

  Future<void> _pollOnce(int gen) async {
    final rides = _rides;
    if (rides == null) return;
    try {
      final position = await rides.driverPosition(rideId);
      var geo = _geo;
      var geoFetched = _geoFetched;
      if (!geoFetched) {
        // Static geometry is a one-shot fetch — even a null answer (the
        // live rungs) is an answer; the next tick never re-asks.
        geo = await rides.rideGeo(rideId);
        geoFetched = true;
      }
      if (gen != _generation) return; // superseded, rebuilt, or disposed
      _position = position;
      _geo = geo;
      _geoFetched = geoFetched;
      _recompute();
    } on Exception {
      // Transient seam failure — keep the last shown state; the next 1 Hz
      // tick retries (including rideGeo if the one-shot never landed).
    }
  }

  /// Maps (runner phase, seams) → the full render state in one assignment.
  void _recompute() {
    final geo = _geo;
    final position = _position;
    if (geo == null && position == null) {
      state = const MapState();
      return;
    }

    final preStart = _phase == TripPhase.headingToPickup ||
        _phase == TripPhase.arrivedAtPickup;
    final objectiveLabel = preStart ? 'Pickup' : 'Drop-off';

    HopGeoPoint? pickupPoint;
    HopGeoPoint? dropoffPoint;
    HopGeoPoint? objectivePoint;
    List<HopGeoPoint>? legPoints;
    // Only a leg that actually ENDS at the objective yields an honest
    // along-leg distance — the degraded pre-start rung (no approach line,
    // route polyline as context) hides the chip instead of lying.
    var legEndsAtObjective = false;
    if (geo != null) {
      pickupPoint = HopGeoPoint(geo.pickupLat, geo.pickupLng);
      dropoffPoint = HopGeoPoint(geo.dropoffLat, geo.dropoffLng);
      objectivePoint = preStart ? pickupPoint : dropoffPoint;
      final approach = geo.approach;
      if (preStart && approach != null && approach.length >= 2) {
        legPoints = [for (final p in approach) HopGeoPoint(p.lat, p.lng)];
        legEndsAtObjective = true;
      } else {
        legPoints = [for (final p in geo.route) HopGeoPoint(p.lat, p.lng)];
        legEndsAtObjective = !preStart;
      }
    }

    final carPosition =
        position == null ? null : HopGeoPoint(position.lat, position.lng);

    int? remainingMeters;
    if (carPosition != null &&
        legPoints != null &&
        legPoints.length >= 2 &&
        legEndsAtObjective) {
      remainingMeters = _remainingMetersAlong(legPoints, carPosition);
    }

    // Chase whenever the car exists; frame the endpoints otherwise.
    final HopMapCameraIntent cameraIntent;
    if (carPosition != null) {
      cameraIntent = FollowPoint(carPosition);
    } else if (pickupPoint != null && dropoffPoint != null) {
      cameraIntent = FitPoints([pickupPoint, dropoffPoint]);
    } else {
      cameraIntent = const FitPoints([]);
    }

    state = MapState(
      phase:
          carPosition != null ? MapPhase.liveTracking : MapPhase.routeOnly,
      pins: [
        if (objectivePoint != null)
          HopMapPin(objectivePoint, HopMapPinRole.objective),
      ],
      track: legPoints != null && legPoints.length >= 2
          ? HopMapTrack(legPoints)
          : null,
      carPosition: carPosition,
      carHeading: position?.heading,
      cameraIntent: cameraIntent,
      objectiveLabel: objectiveLabel,
      remainingMeters: remainingMeters,
      // OT-16: the hand-off target flips with the objective pin, same emission.
      destination: objectivePoint,
    );
  }

  /// Remaining distance along [leg] from the car: project onto the leg by
  /// nearest vertex (sufficient at 1 Hz / city scale) and sum the segment
  /// lengths from there to the end.
  int _remainingMetersAlong(List<HopGeoPoint> leg, HopGeoPoint car) {
    var nearest = 0;
    var best = double.infinity;
    for (var i = 0; i < leg.length; i++) {
      final d = _haversineMeters(leg[i], car);
      if (d < best) {
        best = d;
        nearest = i;
      }
    }
    var remaining = 0.0;
    for (var i = nearest; i < leg.length - 1; i++) {
      remaining += _haversineMeters(leg[i], leg[i + 1]);
    }
    return remaining.round();
  }

  /// Great-circle distance in meters — the sanctioned ~15-line pure-Dart
  /// exception (feature code must not import latlong2; the one map-math
  /// helper is hand-rolled instead).
  static double _haversineMeters(HopGeoPoint a, HopGeoPoint b) {
    const earthRadiusMeters = 6371000.0;
    final dLat = _rad(b.lat - a.lat);
    final dLng = _rad(b.lng - a.lng);
    final sinLat = math.sin(dLat / 2);
    final sinLng = math.sin(dLng / 2);
    final h = sinLat * sinLat +
        math.cos(_rad(a.lat)) * math.cos(_rad(b.lat)) * sinLng * sinLng;
    return 2 * earthRadiusMeters * math.asin(math.sqrt(h));
  }

  static double _rad(double deg) => deg * math.pi / 180;
}
