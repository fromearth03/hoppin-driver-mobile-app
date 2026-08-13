import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

import '../seed/demo_seed.dart';
import '../seed/fares.dart';
import '../seed/geo_track.dart';
import '../seed/history.dart';
import '../seed/personas.dart';
import '../seed/places.dart';
import '../storage/snapshot_store.dart';
import 'demo_script.dart';
import 'world_snapshot.dart';

/// Where the world currently is in the scripted ride lifecycle.
///
/// This is the WORLD's phase, not a ride status: `arrivingHold` is the calm
/// "Arriving now" state the ETA floors into (the ride status stays
/// `accepted`), and `arrived` is the beat after the driver's Arrived tap
/// (ride status `arriving`).
enum WorldPhase {
  idle,
  matching,
  accepted,
  arrivingHold,
  arrived,
  inTrip,
  completed,
}

/// Which app composition this world drives. The rider scenario auto-runs a
/// virtual driver; the driver scenario auto-runs a virtual rider.
enum DemoScenario { rider, driver }

/// Every mutation the world understands. Lifecycle events consult the
/// transition table; data-only events (sign-in flag, promo, ratings, saved
/// locations) never change phase and never disturb armed timers.
enum WorldEventType {
  signedIn,
  signedOut,
  rideRequested,
  rideMatched,
  wentOnline,
  wentOffline,
  offerArrived,
  offerAccepted,
  offerDeclined,
  reofferFired,
  etaFloored,
  driverArrived,
  rideStarted,
  rideCompleted,
  rideCancelled,
  worldIdled,
  promoApplied,
  rideRated,
  savedLocationAdded,
  savedLocationDeleted,
}

/// The one-shot script timers the world can arm. At most one is pending at
/// any moment; the 1Hz ETA ticker is tracked separately.
enum ScriptTimerKind {
  match,
  incomingRequest,
  reoffer,
  virtualArrive,
  virtualStart,
  virtualComplete,
  postComplete,
}

/// A pickup/dropoff coordinate pair for one trip.
typedef DemoRoute = ({
  double pickupLat,
  double pickupLng,
  double dropoffLat,
  double dropoffLng,
});

/// The deterministic scenario engine that IS the demo's backend (DEMO-04).
///
/// Every mutation — user taps arriving through the fakes and scripted
/// virtual-counterpart beats alike — funnels through one [_apply] call with
/// an explicit transition table, and every pending timer is cancelled on
/// every transition, so lifecycle states can never skip or double-fire. All
/// run-time pacing reads `clock.now()` (never the wall clock) and all data
/// timestamps derive from [DemoSeed.anchor], so two same-seed runs are
/// byte-identical and every behavior is provable under fake_async.
class DemoWorld {
  /// A world for the rider app: the virtual counterpart is the demo driver.
  DemoWorld.riderScenario({required int seed, required SnapshotStore store})
    : this._(seed: seed, store: store, scenario: DemoScenario.rider);

  /// A world for the driver app: the virtual counterpart is the demo rider.
  DemoWorld.driverScenario({required int seed, required SnapshotStore store})
    : this._(seed: seed, store: store, scenario: DemoScenario.driver);

  DemoWorld._({
    required int seed,
    required this._store,
    required this._scenario,
  }) : _seed = seed,
       _script = DemoScript.fromSeed(seed) {
    _seedFreshState();
  }

  final int _seed;
  final SnapshotStore _store;
  final DemoScenario _scenario;
  final DemoScript _script;

  // ---- Mutable world state -------------------------------------------------

  WorldPhase _phase = WorldPhase.idle;
  int _revision = 0;
  bool _signedIn = false;
  bool _online = false;

  Ride? _liveRide;
  DemoRoute? _liveRoute;
  DemoRoute? _pendingRequest;
  RideOffer? _currentOffer;
  PromoResult? _promo;

  final List<Ride> _sessionRides = [];
  final Map<String, Receipt> _sessionReceipts = {};
  final List<Transaction> _sessionTransactions = [];

  /// Journey labels for archived session rides, captured at the archive
  /// beat (the route itself is dropped there). History Activity-hub rows
  /// and the receipt's completed strip read these through [driverInfoFor]
  /// after the ride leaves the live slot. Deliberately NOT persisted in the
  /// snapshot (codec unchanged): after a reload the seam degrades to
  /// identity-only, exactly the pre-existing contract.
  final Map<String, ({String? origin, String? destination})>
      _sessionJourneyLabels = {};
  final Map<String, ({int score, String? comments})> _ratings = {};
  List<SavedLocation> _savedLocations = [];

  int _earningsPence = 0;
  int _tripCount = 0;
  int _onlineAccumulatedMs = 0;
  DateTime? _onlineSince;

  int _idCounter = 0;
  final List<String> _eventLog = [];

  // ---- Pacing --------------------------------------------------------------

  late DateTime _bootAt;
  int _virtualBaseMs = 0;
  DateTime? _etaStartedAt;
  DateTime? _startedAtVirtual;

  /// The armed script timers plus each one's due instant — the due instant
  /// is what lets the snapshot persist a REMAINING duration for re-arming.
  final Map<ScriptTimerKind, ({Timer timer, DateTime firesAt})> _timers = {};
  Timer? _etaTicker;

  /// The scripted demo route the virtual rider always requests.
  static const DemoRoute _scriptedRoute = (
    pickupLat: 52.5877,
    pickupLng: -2.1200,
    dropoffLat: 52.6046,
    dropoffLng: -2.0930,
  );

  /// One paid transaction per seeded history trip, newest first.
  static final List<Transaction> _seededTransactions =
      List<Transaction>.unmodifiable([
        for (final (index, trip) in DemoHistory.trips.indexed)
          Transaction(
            id: 'd4000000-0000-4000-8000-${'${index + 1}'.padLeft(12, '0')}',
            rideId: trip.ride.id,
            amountPence: trip.receipt.totalPence,
            status: 'paid',
            createdAt: trip.receipt.dropoffTime,
          ),
      ]);

  /// The explicit lifecycle table — the ONLY place a phase change is legal.
  static const Map<(WorldPhase, WorldEventType), WorldPhase> _transitions = {
    // Rider flow: request -> match -> en route.
    (WorldPhase.idle, WorldEventType.rideRequested): WorldPhase.matching,
    (WorldPhase.completed, WorldEventType.rideRequested): WorldPhase.matching,
    (WorldPhase.matching, WorldEventType.rideMatched): WorldPhase.accepted,
    // Driver flow: online -> incoming request -> accept/decline/re-offer.
    (WorldPhase.idle, WorldEventType.wentOnline): WorldPhase.idle,
    (WorldPhase.idle, WorldEventType.wentOffline): WorldPhase.idle,
    (WorldPhase.matching, WorldEventType.wentOffline): WorldPhase.idle,
    (WorldPhase.idle, WorldEventType.offerArrived): WorldPhase.matching,
    (WorldPhase.matching, WorldEventType.offerAccepted): WorldPhase.accepted,
    (WorldPhase.matching, WorldEventType.offerDeclined): WorldPhase.matching,
    (WorldPhase.matching, WorldEventType.reofferFired): WorldPhase.matching,
    // Shared lifecycle spine.
    (WorldPhase.accepted, WorldEventType.etaFloored): WorldPhase.arrivingHold,
    (WorldPhase.accepted, WorldEventType.driverArrived): WorldPhase.arrived,
    (WorldPhase.arrivingHold, WorldEventType.driverArrived): WorldPhase.arrived,
    (WorldPhase.arrived, WorldEventType.rideStarted): WorldPhase.inTrip,
    (WorldPhase.inTrip, WorldEventType.rideCompleted): WorldPhase.completed,
    (WorldPhase.completed, WorldEventType.worldIdled): WorldPhase.idle,
    // The recoverable loop: cancels always land back on idle.
    (WorldPhase.matching, WorldEventType.rideCancelled): WorldPhase.idle,
    (WorldPhase.accepted, WorldEventType.rideCancelled): WorldPhase.idle,
    (WorldPhase.arrivingHold, WorldEventType.rideCancelled): WorldPhase.idle,
    (WorldPhase.arrived, WorldEventType.rideCancelled): WorldPhase.idle,
  };

  /// Data-only events: no phase change, armed timers stay untouched.
  static const Set<WorldEventType> _neutralEvents = {
    WorldEventType.signedIn,
    WorldEventType.signedOut,
    WorldEventType.promoApplied,
    WorldEventType.rideRated,
    WorldEventType.savedLocationAdded,
    WorldEventType.savedLocationDeleted,
  };

  // ---- Boot & lifecycle ----------------------------------------------------

  /// Resumes a valid snapshot, otherwise seeds a fresh world.
  ///
  /// "Valid" means: decodes, same codec version, same seed, same scenario.
  /// Anything else — including garbage — is discarded quietly and the boot
  /// lands on the fresh seeded world (signed out, on the login screen).
  void restoreOrSeed() {
    final raw = _store.read();
    final snapshot = WorldSnapshot.tryDecode(raw);
    if (snapshot == null ||
        snapshot.seed != _seed ||
        snapshot.scenario != _scenario) {
      if (raw != null) _store.clear();
      _seedFreshState();
    } else {
      _restoreFrom(snapshot);
    }
    _revision++;
  }

  /// Cancels every timer, clears the persisted snapshot, and rebuilds the
  /// fresh seeded world — synchronous, so DEMO-06's budget is met by
  /// construction. The next boot lands on the login screen.
  void reset() {
    _cancelPendingTimers();
    _store.clear();
    _seedFreshState();
    _revision++;
  }

  /// The world's current lifecycle phase.
  WorldPhase get phase => _phase;

  /// Bumped on every applied event (and every ETA tick) so pollers can spot
  /// changes cheaply.
  int get revision => _revision;

  /// Ordered "phase>event>nextPhase" strings — the determinism instrument.
  List<String> get eventLog => List.unmodifiable(_eventLog);

  // ---- Auth flag -----------------------------------------------------------

  /// Whether the demo user is signed in. Owned here so the snapshot
  /// round-trips it; DemoAuthService drives it.
  bool get signedIn => _signedIn;

  /// Records a successful demo sign-in.
  void markSignedIn() {
    if (_signedIn) return;
    _apply(WorldEventType.signedIn, () => _signedIn = true);
  }

  /// Records a demo sign-out.
  void markSignedOut() {
    if (!_signedIn) return;
    _apply(WorldEventType.signedOut, () => _signedIn = false);
  }

  // ---- Rider-facing --------------------------------------------------------

  /// Pure `POST /rides/estimate` equivalent for any route.
  FareEstimate estimateFor({
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
  }) => estimateBetween(
    pickupLat: pickupLat,
    pickupLng: pickupLng,
    dropoffLat: dropoffLat,
    dropoffLng: dropoffLng,
  );

  /// The 202-shaped `POST /rides/request`: returns ONLY a request id — the
  /// ride row appears in [rideHistory] once the scripted match beat fires,
  /// 3.6-4.8s later. Never creates the row synchronously (the booking
  /// controller's id-diff poll depends on that).
  String submitRideRequest({
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
  }) {
    if (_phase != WorldPhase.idle && _phase != WorldPhase.completed) {
      throw const ApiException(
        statusCode: 409,
        message: 'You already have an active trip.',
        code: 'ACTIVE_TRIP_EXISTS',
      );
    }
    final requestId = _nextId('d1');
    _apply(WorldEventType.rideRequested, () {
      // A rebook during the post-complete beat cuts it short.
      _archiveLiveRide();
      _pendingRequest = (
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        dropoffLat: dropoffLat,
        dropoffLng: dropoffLng,
      );
    });
    return requestId;
  }

  /// Ride rows newest first: the live ride, then this session's finished
  /// rides, then the seeded history.
  List<Ride> rideHistory({int limit = 50}) {
    final rows = <Ride>[?_liveRide, ..._sessionRides, ...DemoHistory.rides];
    return List.unmodifiable(rows.take(limit));
  }

  /// One ride by id — live, session, or seeded.
  Ride rideById(String id) {
    final live = _liveRide;
    if (live != null && live.id == id) return live;
    for (final ride in _sessionRides) {
      if (ride.id == id) return ride;
    }
    for (final ride in DemoHistory.rides) {
      if (ride.id == id) return ride;
    }
    throw const ApiException(
      statusCode: 404,
      message: 'Ride not found',
      code: 'RIDE_NOT_FOUND',
    );
  }

  /// Cancels the live ride. The reason id must be one of the four seeded
  /// cancellation reasons (the same set the rider app's cancel sheet uses);
  /// anything else is rejected with the live API's VALIDATION_FAILED shape.
  void cancelRide({
    required String rideId,
    required String reasonId,
    required String canceledByUserId,
    required String actorType,
  }) {
    if (!DemoSeed.cancellationReasonIds.contains(reasonId)) {
      throw const ApiException(
        statusCode: 422,
        message: 'Cancellation reason not found or inactive.',
        code: 'VALIDATION_FAILED',
      );
    }
    final live = _liveRide;
    final cancellable = _transitions.containsKey((
      _phase,
      WorldEventType.rideCancelled,
    ));
    if (live == null || live.id != rideId || !cancellable) {
      throw const ApiException(
        statusCode: 409,
        message: 'This ride can no longer be cancelled.',
        code: 'CANNOT_CANCEL',
      );
    }
    _apply(WorldEventType.rideCancelled, () {
      _liveRide = live.copyWith(
        status: RideStatus.cancelled,
        updatedAt: _virtualNow,
      );
      // No ghost state: any pending offer dies with the trip and the row
      // moves straight into session history, ready for immediate rebooking.
      _currentOffer = null;
      _archiveLiveRide();
    });
  }

  /// Rates a completed ride (1-5 stars).
  void rateRide({
    required String rideId,
    required int score,
    String? comments,
  }) {
    if (score < 1 || score > 5) {
      throw const ApiException(
        statusCode: 422,
        message: 'Rating must be between 1 and 5.',
        code: 'VALIDATION_FAILED',
      );
    }
    rideById(rideId); // rejects unknown rides with the 404 shape
    _apply(
      WorldEventType.rideRated,
      () => _ratings[rideId] = (score: score, comments: comments),
    );
  }

  /// Applies a promo code to the live ride. Only the seeded HOPPIN20 exists;
  /// unknown codes raise the PROMO_NOT_FOUND shape the friendly-error path
  /// already renders. The stored result flows into the final receipt.
  PromoResult applyPromoCode({
    required String rideId,
    required String promoCode,
  }) {
    final live = _liveRide;
    if (live == null || live.id != rideId) {
      throw const ApiException(
        statusCode: 404,
        message: 'Ride not found',
        code: 'RIDE_NOT_FOUND',
      );
    }
    final route = _liveRoute ?? _scriptedRoute;
    final quote = quoteBetween(
      pickupLat: route.pickupLat,
      pickupLng: route.pickupLng,
      dropoffLat: route.dropoffLat,
      dropoffLng: route.dropoffLng,
    );
    final result = promoResultFor(code: promoCode, originalFare: quote.total);
    if (result == null) {
      throw const ApiException(
        statusCode: 404,
        message: 'Promo code not found',
        code: 'PROMO_NOT_FOUND',
      );
    }
    _apply(WorldEventType.promoApplied, () => _promo = result);
    return result;
  }

  /// The itemised receipt for a completed ride — session or seeded.
  Receipt receiptFor(String rideId) {
    final receipt =
        _sessionReceipts[rideId] ?? DemoHistory.receiptsByRideId[rideId];
    if (receipt == null) {
      throw const ApiException(
        statusCode: 404,
        message: 'Receipt not found',
        code: 'RECEIPT_NOT_FOUND',
      );
    }
    return receipt;
  }

  /// Capability seam (DEMO-07): driver identity + live-trip telemetry for
  /// [rideId] — the demo's answer to the null the live
  /// `RidesRepository.driverInfo` returns.
  ///
  /// - The live scripted ride serves [DemoPersonas.driver] + the demo Prius,
  ///   the clock-delta [etaSecondsRemaining] (non-null only in accepted /
  ///   arrivingHold), and journey labels resolved from the ride's route by
  ///   exact-coordinate match against the picker presets.
  /// - Archived session rides keep the identity and the journey labels
  ///   captured at the archive beat, but drop telemetry (ETA); after a
  ///   reload the labels degrade to null (they are not snapshotted).
  /// - Seeded history rides resolve their historyCast driver + vehicle and
  ///   the trip's pickup/dropoff place labels.
  /// - Pre-match rides (driverId null) and unknown ids answer null.
  ///
  /// NEVER throws — a missing identity is a valid, renderable state.
  RideDriverInfo? driverInfoFor(String rideId) {
    final live = _liveRide;
    if (live != null && live.id == rideId) {
      if (live.driverId != DemoSeed.driverId) return null;
      final route = _liveRoute ?? _scriptedRoute;
      return _composeDriverInfo(
        persona: DemoPersonas.driver,
        vehicle: DemoPersonas.driverVehicle,
        etaSeconds: etaSecondsRemaining,
        originLabel: _presetLabelAt(route.pickupLat, route.pickupLng),
        destinationLabel: _presetLabelAt(route.dropoffLat, route.dropoffLng),
      );
    }
    for (final ride in _sessionRides) {
      if (ride.id == rideId) {
        if (ride.driverId != DemoSeed.driverId) return null;
        final labels = _sessionJourneyLabels[ride.id];
        return _composeDriverInfo(
          persona: DemoPersonas.driver,
          vehicle: DemoPersonas.driverVehicle,
          originLabel: labels?.origin,
          destinationLabel: labels?.destination,
        );
      }
    }
    for (final trip in DemoHistory.trips) {
      if (trip.ride.id == rideId) {
        final cast = _historyCastFor(trip.ride.driverId);
        if (cast == null) return null;
        return _composeDriverInfo(
          persona: cast.persona,
          vehicle: cast.vehicle,
          originLabel: trip.pickup.label,
          destinationLabel: trip.dropoff.label,
        );
      }
    }
    return null;
  }

  /// The historyCast member whose persona matches [driverId], if any.
  ({DemoPersona persona, DemoVehicle vehicle})? _historyCastFor(
    String? driverId,
  ) {
    if (driverId == null) return null;
    for (final member in DemoPersonas.historyCast) {
      if (member.persona.userId == driverId) return member;
    }
    return null;
  }

  /// The preset place label sitting EXACTLY at ([lat], [lng]) — the preset
  /// coords are copied verbatim from the rider app's picker, so exact
  /// equality is the honest match. Custom pins resolve to null.
  String? _presetLabelAt(double lat, double lng) {
    for (final place in DemoPlaces.presets) {
      if (place.lat == lat && place.lng == lng) return place.label;
    }
    return null;
  }

  /// Materializes the seam payload from a seeded persona + vehicle pair.
  RideDriverInfo _composeDriverInfo({
    required DemoPersona persona,
    required DemoVehicle vehicle,
    int? etaSeconds,
    String? originLabel,
    String? destinationLabel,
  }) =>
      RideDriverInfo(
        fullName: persona.fullName,
        rating: persona.rating,
        ratingCount: persona.tripsCount > 0 ? 12 : 0,
        tripsCount: persona.tripsCount,
        vehicleMake: vehicle.make,
        vehicleModel: vehicle.model,
        vehicleColour: vehicle.colour,
        plate: vehicle.plate,
        etaSeconds: etaSeconds,
        originLabel: originLabel,
        destinationLabel: destinationLabel,
      );

  // ---- Driver-facing -------------------------------------------------------

  /// Whether the demo driver is online.
  bool get online => _online;

  /// Goes online. In the driver scenario this arms the scripted incoming
  /// request beat.
  void goOnline() {
    if (_online) return;
    _apply(WorldEventType.wentOnline, () {
      _online = true;
      _onlineSince = clock.now();
    });
  }

  /// Goes offline. Cancels any pending scripted request or re-offer — no
  /// ghost offer can fire afterwards.
  void goOffline() {
    if (!_online) return;
    _apply(WorldEventType.wentOffline, () {
      _accrueOnlineTime();
      _online = false;
      _onlineSince = null;
      _currentOffer = null;
      final live = _liveRide;
      if (live != null && live.status == RideStatus.matching) {
        // The virtual rider's un-accepted request dies with the shift.
        _liveRide = live.copyWith(
          status: RideStatus.cancelled,
          updatedAt: _virtualNow,
        );
        _archiveLiveRide();
      }
    });
  }

  /// The pending offer, if one is waiting for the presenter's tap.
  List<RideOffer> pendingOffers() => List.unmodifiable([?_currentOffer]);

  /// Accepts the pending offer: the ride becomes accepted, the ETA starts.
  /// A stale or unknown offer id is ignored outright.
  void acceptOffer(String offerId) {
    final offer = _currentOffer;
    if (offer == null || offer.offerId != offerId) return;
    _apply(WorldEventType.offerAccepted, () {
      _currentOffer = null;
      _liveRide = _liveRide?.copyWith(
        status: RideStatus.accepted,
        driverId: DemoSeed.driverId,
        vehicleId: DemoSeed.vehicleId,
        updatedAt: _virtualNow,
      );
    });
  }

  /// Declines the pending offer. The same trip is re-offered with a fresh
  /// offer id after the scripted delay — the demo always continues.
  void declineOffer(String offerId) {
    final offer = _currentOffer;
    if (offer == null || offer.offerId != offerId) return;
    _apply(WorldEventType.offerDeclined, () => _currentOffer = null);
  }

  /// The driver's Arrived tap (scripted for the rider composition).
  void markArrived(String rideId) {
    if (_liveRide?.id != rideId) return;
    _apply(WorldEventType.driverArrived, _markArrivedState);
  }

  /// The driver's Start trip tap (scripted for the rider composition).
  void startRide(String rideId) {
    if (_liveRide?.id != rideId) return;
    _apply(WorldEventType.rideStarted, _markStartedState);
  }

  /// The driver's Complete tap (scripted for the rider composition).
  void completeRide(String rideId, {int? actualDistanceMeters}) {
    if (_liveRide?.id != rideId) return;
    _apply(
      WorldEventType.rideCompleted,
      () => _completeState(actualDistanceMeters: actualDistanceMeters),
    );
  }

  // ---- Seeded reads --------------------------------------------------------

  /// The rider's saved places (seeded Home and Work plus session additions).
  List<SavedLocation> savedLocations() => List.unmodifiable(_savedLocations);

  /// Adds a saved place and returns the stored row.
  SavedLocation addSavedLocation({
    required String label,
    required double lat,
    required double lng,
  }) {
    final location = SavedLocation(
      id: _nextId('c1'),
      userId: DemoSeed.riderId,
      label: label,
      lat: lat,
      lng: lng,
    );
    _apply(
      WorldEventType.savedLocationAdded,
      () => _savedLocations = [..._savedLocations, location],
    );
    return location;
  }

  /// Removes a saved place by id (unknown ids are a quiet no-op).
  void deleteSavedLocation(String id) {
    _apply(
      WorldEventType.savedLocationDeleted,
      () => _savedLocations = [
        for (final location in _savedLocations)
          if (location.id != id) location,
      ],
    );
  }

  /// Payment transactions newest first: session completions, then seeded.
  List<Transaction> transactions({int limit = 50}) {
    final rows = <Transaction>[..._sessionTransactions, ..._seededTransactions];
    return List.unmodifiable(rows.take(limit));
  }

  // ---- Live-trip telemetry ---------------------------------------------------

  /// Seconds until the driver reaches the pickup. Null when no ride is en
  /// route; clamps at 0 and NEVER goes negative. Computed as a clock delta,
  /// not a tick count, so a throttled timer still renders the right value.
  int? get etaSecondsRemaining {
    switch (_phase) {
      case WorldPhase.accepted:
        final started = _etaStartedAt;
        if (started == null) return _script.etaTotalSeconds;
        final elapsedMs = clock.now().difference(started).inMilliseconds;
        final remainingMs = _script.etaTotalSeconds * 1000 - elapsedMs;
        return math.max(0, (remainingMs / 1000).ceil());
      case WorldPhase.arrivingHold:
        return 0;
      case WorldPhase.idle:
      case WorldPhase.matching:
      case WorldPhase.arrived:
      case WorldPhase.inTrip:
      case WorldPhase.completed:
        return null;
    }
  }

  /// True while the world sits in the calm "Arriving now" hold.
  bool get arrivingNow => _phase == WorldPhase.arrivingHold;

  // ---- Geo track (MAP-03) ----------------------------------------------------
  //
  // DERIVED getters only: the car's position is a pure function of state the
  // snapshot already persists (etaSecondsRemaining during the approach;
  // _startedAtVirtual + the script's inTripSeconds on-trip), so it is
  // seed-stable, F5-resume-safe, and provable under fake_async with ZERO
  // codec changes. No new fields, no new timers.

  /// The trip polyline as seam-shaped points, converted once.
  static final List<GeoPoint> _tripRoutePoints = List.unmodifiable([
    for (final point in GeoTrack.trip.points)
      GeoPoint(lat: point.lat, lng: point.lng),
  ]);

  /// The approach polyline as seam-shaped points, converted once.
  static final List<GeoPoint> _approachRoutePoints = List.unmodifiable([
    for (final point in GeoTrack.approach.points)
      GeoPoint(lat: point.lat, lng: point.lng),
  ]);

  /// The demo driver's live position for [rideId] — the world's answer to
  /// the null the live [RidesRepository.driverPosition] returns (gap #41).
  ///
  /// Pure function of already-persisted state, per phase:
  /// - matching: parked at the Molineux spawn while [rideId] is the offered
  ///   ride (approach t=0 — feeds the MAP-04 offer inset); null otherwise.
  /// - accepted/arrivingHold: along the approach leg at
  ///   `1 − etaRemaining/etaTotal` — the SAME clock-delta the ETA hero
  ///   counts down, so the car reaching the pin and "Arriving now" coincide
  ///   by construction.
  /// - arrived: parked exactly on the pickup (approach t=1).
  /// - inTrip: along the trip leg at virtual-elapsed / inTripSeconds.
  /// - completed: parked exactly on the dropoff (trip t=1).
  /// - idle, unknown or non-live ride ids: null. NEVER throws.
  DriverPosition? driverPositionFor(String rideId) {
    switch (_phase) {
      case WorldPhase.matching:
        if (_currentOffer?.rideId != rideId) return null;
        return _positionAlong(GeoTrack.approach, 0);
      case WorldPhase.accepted:
      case WorldPhase.arrivingHold:
        if (_liveRide?.id != rideId) return null;
        final remaining = etaSecondsRemaining ?? 0;
        return _positionAlong(
          GeoTrack.approach,
          1 - remaining / _script.etaTotalSeconds,
        );
      case WorldPhase.arrived:
        if (_liveRide?.id != rideId) return null;
        return _positionAlong(GeoTrack.approach, 1);
      case WorldPhase.inTrip:
        if (_liveRide?.id != rideId) return null;
        final started = _startedAtVirtual;
        final t = started == null
            ? 0.0
            : _virtualNow.difference(started).inMilliseconds /
                (_script.inTripSeconds * 1000);
        return _positionAlong(GeoTrack.trip, t);
      case WorldPhase.completed:
        if (_liveRide?.id != rideId) return null;
        return _positionAlong(GeoTrack.trip, 1);
      case WorldPhase.idle:
        return null;
    }
  }

  /// Static route geometry for [rideId] — the world's answer to the null
  /// the live [RidesRepository.rideGeo] returns (gap #17). Serves the live
  /// ride and the matching-phase offered ride (so the driver's offer inset
  /// can draw driver→pickup context pre-accept); null otherwise.
  RideGeo? rideGeoFor(String rideId) {
    final live = _liveRide;
    final isLive = live != null && live.id == rideId;
    final isOffered =
        _phase == WorldPhase.matching && _currentOffer?.rideId == rideId;
    if (!isLive && !isOffered) return null;
    final route = _liveRoute ?? _scriptedRoute;
    return RideGeo(
      pickupLat: route.pickupLat,
      pickupLng: route.pickupLng,
      dropoffLat: route.dropoffLat,
      dropoffLng: route.dropoffLng,
      route: _tripRoutePoints,
      approach: _approachRoutePoints,
    );
  }

  /// Materializes the seam payload for fraction [t] of [leg]: interpolated
  /// lat/lng, the segment's bearing as the heading, and the VIRTUAL clock
  /// as the update instant (never the wall clock).
  DriverPosition _positionAlong(TrackLeg leg, double t) {
    final (lat, lng, bearing) = GeoTrack.pointAlong(leg, t);
    return DriverPosition(
      lat: lat,
      lng: lng,
      heading: bearing,
      updatedAt: _virtualNow,
    );
  }

  // ---- Driver earnings -------------------------------------------------------

  /// Today's earnings in pence — seeded morning plus session completions.
  int get todayEarningsPence => _earningsPence;

  /// Completed trips today — seeded morning plus session completions.
  int get todayTripCount => _tripCount;

  /// Time online today — the seeded morning stretch plus session time.
  Duration get todayOnlineTime {
    var sessionMs = _onlineAccumulatedMs;
    final since = _onlineSince;
    if (since != null) {
      sessionMs += clock.now().difference(since).inMilliseconds;
    }
    return DemoHistory.morningEarnings.onlineDuration +
        Duration(milliseconds: sessionMs);
  }

  // ---- Core mechanics --------------------------------------------------------

  /// THE single entry point for every mutation.
  ///
  /// Lifecycle events look up (phase, event) in the transition table; a miss
  /// is ignored outright — release-style guard, the world never corrupts and
  /// never throws mid-demo. On a hit, every pending timer is cancelled FIRST
  /// so nothing stale can double-fire, then state mutates, the next beat is
  /// armed, the snapshot persists, and the event is logged.
  void _apply(WorldEventType type, void Function() mutate) {
    final previous = _phase;
    final WorldPhase next;
    if (_neutralEvents.contains(type)) {
      next = previous;
    } else {
      final target = _transitions[(previous, type)];
      if (target == null) return;
      _cancelPendingTimers();
      next = target;
    }
    _phase = next;
    mutate();
    if (!_neutralEvents.contains(type)) {
      _armTimersFor(next, type);
    }
    _persistSnapshot();
    _revision++;
    _eventLog.add('${previous.name}>${type.name}>${next.name}');
  }

  /// Cancels every armed script timer and the ETA ticker.
  void _cancelPendingTimers() {
    for (final pending in _timers.values) {
      pending.timer.cancel();
    }
    _timers.clear();
    _etaTicker?.cancel();
    _etaTicker = null;
  }

  /// Arms the scripted beat(s) owed to the state just entered.
  void _armTimersFor(WorldPhase next, WorldEventType type) {
    switch (next) {
      case WorldPhase.idle:
        // The driver's shift continues: a fresh scripted request follows
        // going online, and another follows a completed trip.
        if (_scenario == DemoScenario.driver &&
            _online &&
            (type == WorldEventType.wentOnline ||
                type == WorldEventType.worldIdled)) {
          _armScript(
            ScriptTimerKind.incomingRequest,
            Duration(milliseconds: _script.offerArrivalDelayMs),
          );
        }
      case WorldPhase.matching:
        if (_scenario == DemoScenario.rider &&
            type == WorldEventType.rideRequested) {
          _armScript(
            ScriptTimerKind.match,
            Duration(milliseconds: _script.matchDelayMs),
          );
        } else if (_scenario == DemoScenario.driver &&
            type == WorldEventType.offerDeclined) {
          _armScript(
            ScriptTimerKind.reoffer,
            Duration(milliseconds: _script.reofferDelayMs),
          );
        }
      // offerArrived / reofferFired: the offer waits for the tap.
      case WorldPhase.accepted:
        _etaStartedAt = clock.now();
        _startEtaTicker();
      case WorldPhase.arrivingHold:
        // Driver scenario: NEVER auto-advances — only markArrived moves on.
        if (_scenario == DemoScenario.rider) {
          _armScript(
            ScriptTimerKind.virtualArrive,
            Duration(milliseconds: _script.virtualArriveHoldMs),
          );
        }
      case WorldPhase.arrived:
        if (_scenario == DemoScenario.rider) {
          _armScript(
            ScriptTimerKind.virtualStart,
            Duration(milliseconds: _script.virtualStartDelayMs),
          );
        }
      case WorldPhase.inTrip:
        if (_scenario == DemoScenario.rider) {
          _armScript(
            ScriptTimerKind.virtualComplete,
            Duration(seconds: _script.inTripSeconds),
          );
        }
      case WorldPhase.completed:
        _armScript(
          ScriptTimerKind.postComplete,
          Duration(milliseconds: _script.postCompleteMs),
        );
    }
  }

  /// Arms one script timer, keyed in the registry the world owns.
  void _armScript(ScriptTimerKind kind, Duration duration) {
    final safe = duration.isNegative ? Duration.zero : duration;
    _timers[kind] = (
      timer: Timer(safe, () => _fireScript(kind)),
      firesAt: clock.now().add(safe),
    );
  }

  /// Routes an elapsed script timer to its lifecycle event.
  void _fireScript(ScriptTimerKind kind) {
    _timers.remove(kind);
    switch (kind) {
      case ScriptTimerKind.match:
        _apply(WorldEventType.rideMatched, _materializeMatch);
      case ScriptTimerKind.incomingRequest:
        _apply(WorldEventType.offerArrived, _materializeIncomingRequest);
      case ScriptTimerKind.reoffer:
        _apply(WorldEventType.reofferFired, _materializeReoffer);
      case ScriptTimerKind.virtualArrive:
        _apply(WorldEventType.driverArrived, _markArrivedState);
      case ScriptTimerKind.virtualStart:
        _apply(WorldEventType.rideStarted, _markStartedState);
      case ScriptTimerKind.virtualComplete:
        _apply(WorldEventType.rideCompleted, _completeState);
      case ScriptTimerKind.postComplete:
        _apply(WorldEventType.worldIdled, _archiveLiveRide);
    }
  }

  /// The 1Hz housekeeping ticker for the en-route countdown. It only bumps
  /// the revision (the remaining time is a clock delta, so a late tick still
  /// renders correctly) and fires the floor transition exactly once.
  void _startEtaTicker() {
    _etaTicker?.cancel();
    _etaTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      final remaining = etaSecondsRemaining;
      if (remaining != null && remaining <= 0) {
        _apply(WorldEventType.etaFloored, () {});
        return;
      }
      _revision++;
      _persistSnapshot();
    });
  }

  // ---- State mutations -------------------------------------------------------

  /// The match beat: the requested ride materializes in history, already
  /// accepted by the demo driver.
  void _materializeMatch() {
    final route = _pendingRequest ?? _scriptedRoute;
    _pendingRequest = null;
    _liveRoute = route;
    final now = _virtualNow;
    _liveRide = Ride(
      id: _nextId('f0'),
      riderId: DemoSeed.riderId,
      driverId: DemoSeed.driverId,
      vehicleId: DemoSeed.vehicleId,
      rideCategory: 'standard',
      status: RideStatus.accepted,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// The scripted incoming request: the virtual rider asks for the demo
  /// route and the offer lands on the driver's screen.
  void _materializeIncomingRequest() {
    _liveRoute = _scriptedRoute;
    final now = _virtualNow;
    _liveRide = Ride(
      id: _nextId('f0'),
      riderId: DemoSeed.riderId,
      rideCategory: 'standard',
      status: RideStatus.matching,
      createdAt: now,
      updatedAt: now,
    );
    _currentOffer = _buildOffer();
  }

  /// Re-offers the same trip with a fresh offer id after a decline.
  void _materializeReoffer() {
    if (_liveRide == null) return;
    _currentOffer = _buildOffer();
  }

  /// Builds an offer for the live ride's route.
  RideOffer _buildOffer() {
    final route = _liveRoute ?? _scriptedRoute;
    final estimate = estimateBetween(
      pickupLat: route.pickupLat,
      pickupLng: route.pickupLng,
      dropoffLat: route.dropoffLat,
      dropoffLng: route.dropoffLng,
    );
    final now = _virtualNow;
    return RideOffer(
      offerId: _nextId('d2'),
      rideId: _liveRide!.id,
      pickupLat: route.pickupLat,
      pickupLng: route.pickupLng,
      dropoffLat: route.dropoffLat,
      dropoffLng: route.dropoffLng,
      fare: estimate.estimate.total,
      estimatedMiles: estimate.distanceMeters / 1609.344,
      expiresAt: now.add(const Duration(seconds: 45)),
      offeredAt: now,
    );
  }

  /// The driver is at the pickup: ride status moves to arriving.
  void _markArrivedState() {
    _etaStartedAt = null;
    _liveRide = _liveRide?.copyWith(
      status: RideStatus.arriving,
      updatedAt: _virtualNow,
    );
  }

  /// The trip starts.
  void _markStartedState() {
    final now = _virtualNow;
    _startedAtVirtual = now;
    _liveRide = _liveRide?.copyWith(status: RideStatus.started, updatedAt: now);
  }

  /// The trip completes: the receipt is built from the route's quote (with
  /// any applied promo), a payment row lands, and today's earnings tick up.
  void _completeState({int? actualDistanceMeters}) {
    final live = _liveRide;
    if (live == null) return;
    final route = _liveRoute ?? _scriptedRoute;
    final estimate = estimateBetween(
      pickupLat: route.pickupLat,
      pickupLng: route.pickupLng,
      dropoffLat: route.dropoffLat,
      dropoffLng: route.dropoffLng,
    );
    // RIDER-04/07: an applied promo must stay VISIBLE on the receipt —
    // farePence carries the PRE-discount quote and totalPence the discounted
    // amount actually charged, so the view derives the discount line as
    // fare + waiting − total. Commission follows totalPence (the money
    // actually taken), and so do the transaction row and earnings below.
    final quotePounds = estimate.estimate.total;
    final farePence = (quotePounds * 100).round();
    final totalPence = ((_promo?.newFare ?? quotePounds) * 100).round();
    final now = _virtualNow;
    final meters = actualDistanceMeters ?? estimate.distanceMeters;
    final receipt = Receipt(
      rideId: live.id,
      rideCategory: live.rideCategory,
      farePence: farePence,
      totalPence: totalPence,
      platformCommissionPence: (totalPence * 0.20).round(),
      status: 'paid',
      distanceMiles: (meters / 1609.344 * 10).round() / 10,
      pickupTime: _startedAtVirtual ?? now,
      dropoffTime: now,
    );
    _sessionReceipts[live.id] = receipt;
    _sessionTransactions.insert(
      0,
      Transaction(
        id: _nextId('d3'),
        rideId: live.id,
        amountPence: receipt.totalPence,
        status: 'paid',
        createdAt: now,
      ),
    );
    _earningsPence += receipt.totalPence;
    _tripCount += 1;
    _etaStartedAt = null;
    _liveRide = live.copyWith(status: RideStatus.completed, updatedAt: now);
  }

  /// Moves the finished live ride into this session's history rows,
  /// capturing its journey labels before the route is dropped.
  void _archiveLiveRide() {
    final live = _liveRide;
    if (live == null) return;
    final route = _liveRoute;
    if (route != null) {
      _sessionJourneyLabels[live.id] = (
        origin: _presetLabelAt(route.pickupLat, route.pickupLng),
        destination: _presetLabelAt(route.dropoffLat, route.dropoffLng),
      );
    }
    _sessionRides.insert(0, live);
    _liveRide = null;
    _liveRoute = null;
    _promo = null;
    _startedAtVirtual = null;
    _etaStartedAt = null;
  }

  // ---- Support ---------------------------------------------------------------

  /// Rebuilds the fresh seeded world (also the constructor body).
  void _seedFreshState() {
    _cancelPendingTimers();
    _phase = WorldPhase.idle;
    _signedIn = false;
    _online = false;
    _liveRide = null;
    _liveRoute = null;
    _pendingRequest = null;
    _currentOffer = null;
    _promo = null;
    _sessionRides.clear();
    _sessionReceipts.clear();
    _sessionTransactions.clear();
    _sessionJourneyLabels.clear();
    _ratings.clear();
    _savedLocations = [...DemoPlaces.savedLocations];
    _earningsPence = DemoHistory.morningEarnings.totalPence;
    _tripCount = DemoHistory.morningEarnings.tripCount;
    _onlineAccumulatedMs = 0;
    _onlineSince = null;
    _idCounter = 0;
    _eventLog.clear();
    _etaStartedAt = null;
    _startedAtVirtual = null;
    _bootAt = clock.now();
    _virtualBaseMs = 0;
  }

  /// Persists the current world state — called on every applied event and
  /// every ETA tick, so the stored snapshot is never more than a beat stale.
  void _persistSnapshot() {
    _store.write(_toSnapshot().encode());
  }

  /// Captures the full session state, including the single pending script
  /// timer's REMAINING duration and the clock-delta ETA.
  WorldSnapshot _toSnapshot() {
    final pending = _timers.entries.isEmpty ? null : _timers.entries.first;
    final since = _onlineSince;
    return WorldSnapshot(
      seed: _seed,
      scenario: _scenario,
      signedIn: _signedIn,
      phase: _phase,
      online: _online,
      liveRide: _liveRide,
      sessionRides: _sessionRides,
      receipts: _sessionReceipts,
      transactions: _sessionTransactions,
      ratings: _ratings,
      savedLocations: _savedLocations,
      promo: _promo,
      currentOffer: _currentOffer,
      liveRoute: _liveRoute,
      pendingRequest: _pendingRequest,
      etaRemainingSeconds: _phase == WorldPhase.accepted
          ? etaSecondsRemaining
          : null,
      pendingTimerKind: pending?.key,
      pendingTimerRemainingMs: pending == null
          ? null
          : math.max(
              0,
              pending.value.firesAt.difference(clock.now()).inMilliseconds,
            ),
      earningsPence: _earningsPence,
      tripCount: _tripCount,
      onlineMs:
          _onlineAccumulatedMs +
          (since == null ? 0 : clock.now().difference(since).inMilliseconds),
      startedAtVirtualMs: _startedAtVirtual
          ?.difference(DemoSeed.anchor)
          .inMilliseconds,
      virtualMs: _virtualElapsedMs,
      idCounter: _idCounter,
    );
  }

  /// Rebuilds the seed state, overlays the snapshot's session fields, and
  /// re-arms exactly what was pending: the ETA countdown resumes from its
  /// remaining seconds and the single script timer from its remaining
  /// milliseconds — never from the top.
  void _restoreFrom(WorldSnapshot snapshot) {
    _seedFreshState();
    _signedIn = snapshot.signedIn;
    _phase = snapshot.phase;
    _online = snapshot.online;
    _liveRide = snapshot.liveRide;
    _sessionRides.addAll(snapshot.sessionRides);
    _sessionReceipts.addAll(snapshot.receipts);
    _sessionTransactions.addAll(snapshot.transactions);
    _ratings.addAll(snapshot.ratings);
    _savedLocations = [...snapshot.savedLocations];
    _promo = snapshot.promo;
    _currentOffer = snapshot.currentOffer;
    _liveRoute = snapshot.liveRoute;
    _pendingRequest = snapshot.pendingRequest;
    _earningsPence = snapshot.earningsPence;
    _tripCount = snapshot.tripCount;
    _onlineAccumulatedMs = snapshot.onlineMs;
    _onlineSince = _online ? clock.now() : null;
    _idCounter = snapshot.idCounter;
    _virtualBaseMs = snapshot.virtualMs;
    final startedMs = snapshot.startedAtVirtualMs;
    _startedAtVirtual = startedMs == null
        ? null
        : DemoSeed.anchor.add(Duration(milliseconds: startedMs));
    if (_phase == WorldPhase.accepted) {
      final remaining = snapshot.etaRemainingSeconds ?? _script.etaTotalSeconds;
      _etaStartedAt = clock.now().subtract(
        Duration(seconds: _script.etaTotalSeconds - remaining),
      );
      _startEtaTicker();
    }
    final kind = snapshot.pendingTimerKind;
    if (kind != null) {
      _armScript(
        kind,
        Duration(milliseconds: snapshot.pendingTimerRemainingMs ?? 0),
      );
    }
  }

  /// Rolls the current online stretch into the accumulated total.
  void _accrueOnlineTime() {
    final since = _onlineSince;
    if (since != null) {
      _onlineAccumulatedMs += clock.now().difference(since).inMilliseconds;
    }
  }

  /// The virtual "now" the fakes stamp session data with — the seeded
  /// anchor plus elapsed run time, never the wall clock. Public so
  /// world-adjacent in-memory state (scheduled rides, document confirms)
  /// stays on the same deterministic timeline as the world's own rows.
  DateTime get virtualNow => _virtualNow;

  /// The virtual "now": the seeded anchor plus elapsed run time. Data
  /// timestamps only ever derive from this — never from the wall clock.
  DateTime get _virtualNow =>
      DemoSeed.anchor.add(Duration(milliseconds: _virtualElapsedMs));

  int get _virtualElapsedMs =>
      _virtualBaseMs + clock.now().difference(_bootAt).inMilliseconds;

  /// Deterministic hex-uuid ids: one counter, distinct prefixes per row
  /// kind (rides f0, requests d1, offers d2, saved locations c1).
  String _nextId(String prefix) {
    _idCounter++;
    final tail = _idCounter.toRadixString(16).padLeft(12, '0');
    return '${prefix}000000-0000-4000-8000-$tail';
  }
}
