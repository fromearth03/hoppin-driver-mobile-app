import 'package:hoppin_shared/hoppin_shared.dart';

import '../seed/demo_seed.dart';
import '../seed/fares.dart';
import '../world/demo_world.dart';

/// The rider lifecycle surface over [DemoWorld] — every method is pure
/// delegation; any behavior belongs in the world, never here.
///
/// Honors the BookingController id-diff contract end-to-end: [requestRide]
/// returns only a `request_id` (the 202 shape) and the ride row surfaces in
/// [history] 3.6-4.8s later, newest-first — exactly what the controller's
/// snapshot-then-poll loop expects.
class FakeRidesRepository implements RidesRepository {
  FakeRidesRepository(this._world);

  final DemoWorld _world;

  /// The seeded future booking: tomorrow 08:30 to New Cross Hospital — a
  /// plausible outpatient-appointment run. The `/scheduled-rides` row shape
  /// carries no coordinates (docs/04), so the destination lives here only
  /// as intent; timestamps derive from [DemoSeed.anchor] like all seed data.
  static final ScheduledRide _seededScheduledRide = ScheduledRide(
    id: 'e1000000-0000-4000-8000-000000000001',
    riderId: DemoSeed.riderId,
    requestedPickupTime: DateTime(
      DemoSeed.anchor.year,
      DemoSeed.anchor.month,
      DemoSeed.anchor.day + 1,
      8,
      30,
    ),
  );

  /// Session-scoped scheduled rides: the seed plus this run's creations.
  /// Deliberately in-memory (not world/snapshot state) — no screen consumes
  /// scheduled rides yet, so the snapshot codec stays untouched.
  final List<ScheduledRide> _scheduledRides = [_seededScheduledRide];
  int _scheduledIdCounter = 1;

  @override
  Future<FareEstimate> estimate({
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
    String? vehicleCategoryId,
  }) async =>
      _world.estimateFor(
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        dropoffLat: dropoffLat,
        dropoffLng: dropoffLng,
      );

  @override
  Future<String> requestRide({
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
    String? vehicleCategoryId,
  }) async =>
      _world.submitRideRequest(
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        dropoffLat: dropoffLat,
        dropoffLng: dropoffLng,
      );

  @override
  Future<Ride> getRide(String id) async => _world.rideById(id);

  /// The seeded cancellation reasons. The live endpoint serves real uuids per
  /// actor; the demo serves a fixed set so a demo cancel takes the same path
  /// (pick a no-penalty rider reason) rather than a special-cased one.
  @override
  Future<List<CancellationReasonOption>> cancellationReasons() async => [
        // Seeded ids — DemoWorld.cancelRide validates against
        // DemoSeed.cancellationReasonIds and 422s on anything else.
        CancellationReasonOption(
          id: DemoSeed.cancellationReasonIds[0],
          reasonText: 'Changed my mind',
          appliesPenaltyFee: false,
          actorType: 'rider',
        ),
        CancellationReasonOption(
          id: DemoSeed.cancellationReasonIds[1],
          reasonText: 'Waiting too long',
          appliesPenaltyFee: false,
          actorType: 'rider',
        ),
        CancellationReasonOption(
          id: DemoSeed.cancellationReasonIds[2],
          reasonText: 'driver_declined',
          appliesPenaltyFee: false,
          actorType: 'driver',
        ),
      ];

  /// Names a dropped pin. The live path asks Nominatim; the demo answers a
  /// stable Wolverhampton-shaped label so the picker's confirm bar is never
  /// empty and the flow reads identically in both modes.
  @override
  Future<({String label, double lat, double lng})?> reverseGeocode(
    double lat,
    double lng,
  ) async => (
        label: 'Pinned location, Wolverhampton '
            '(${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})',
        lat: lat,
        lng: lng,
      );

  /// Demo autocomplete. The demo runs with no network, so this stands in for
  /// Photon by matching the rider's own saved places plus a small set of
  /// well-known Wolverhampton spots — enough for the picker to demonstrate
  /// real type-ahead behaviour (saved places ranked first, exactly as the
  /// server orders them) without inventing plausible-looking addresses that
  /// resolve nowhere.
  @override
  Future<List<PlaceSuggestion>> searchPlaces(
    String query, {
    double? lat,
    double? lng,
    int limit = 8,
  }) async {
    final q = query.trim().toLowerCase();
    if (q.length < 2) return const [];

    final hits = <PlaceSuggestion>[
      for (final s in _world.savedLocations())
        if (s.label.toLowerCase().contains(q))
          PlaceSuggestion(
            label: s.label,
            lat: s.lat,
            lng: s.lng,
            source: 'saved',
          ),
      for (final p in _demoPlaces)
        if (p.label.toLowerCase().contains(q)) p,
    ];
    return hits.take(limit).toList();
  }

  /// Well-known spots in the demo's service area (Wolverhampton).
  static const _demoPlaces = <PlaceSuggestion>[
    PlaceSuggestion(
      label: 'Molineux Stadium, Waterloo Road, Wolverhampton',
      lat: 52.5903,
      lng: -2.1306,
      postcode: 'WV1 4QR',
    ),
    PlaceSuggestion(
      label: 'Wolverhampton Rail Station',
      lat: 52.5877,
      lng: -2.1200,
      postcode: 'WV1 1LE',
    ),
    PlaceSuggestion(
      label: 'University of Wolverhampton, Wulfruna Street',
      lat: 52.5896,
      lng: -2.1276,
      postcode: 'WV1 1LY',
    ),
    PlaceSuggestion(
      label: 'New Cross Hospital, Wednesfield',
      lat: 52.6046,
      lng: -2.0930,
      postcode: 'WV10 0QP',
    ),
    PlaceSuggestion(
      label: 'Bentley Bridge Retail Park',
      lat: 52.6006,
      lng: -2.0868,
      postcode: 'WV11 1BP',
    ),
  ];

  /// The demo promotion catalogue.
  ///
  /// 🔴 Exactly ONE offer, and it is [DemoSeed.promoCode] — the only code
  /// `promoResultFor` honours. A catalogue listing codes the demo world would
  /// reject at booking would be decorative: the rider taps an offer, enters it,
  /// and gets PROMO_NOT_FOUND. Every offer shown here really applies.
  @override
  Future<List<PromoOffer>> promotions() async => const [
        PromoOffer(
          promoCode: DemoSeed.promoCode,
          title: 'Welcome to Hoppin',
          description: '20% off your next trip.',
          discountType: 'percentage',
          discountValue: 20,
        ),
      ];

  /// The operator's real contact details. Ofcom's reserved fictional ranges
  /// (`+44 7700 900xxx` / `020 7946 0xxx`), so a demo tap can never dial or
  /// email a real person.
  @override
  Future<PlatformContacts> contacts() async => const PlatformContacts(
        supportEmail: 'help@hoppin.app',
        supportPhone: '+44 20 7946 0000',
        emergencyPhone: '+44 20 7946 0999',
        whatsappNumber: '+44 7700 900000',
      );

  /// The bookable vehicle classes. The demo world prices one class, so exactly
  /// one is offered — a picker listing classes the fare engine cannot quote
  /// would 400 on submit.
  @override
  Future<List<VehicleType>> vehicleTypes() async => const [
        VehicleType(
          id: 'b1000000-0000-4000-8000-000000000001',
          name: 'Standard',
          seats: 4,
          bags: 2,
        ),
      ];

  /// Wolverhampton is in the demo service area; anywhere else is not, matching
  /// the single licensed area the seed models.
  @override
  Future<bool?> isServiceable(double lat, double lng) async =>
      lat > 52.4 && lat < 52.8 && lng > -2.4 && lng < -1.9;

  /// The demo is never gated: no maintenance, no forced update. The launch gate
  /// must wave the demo straight through to the app it is meant to show off.
  @override
  Future<AppStatus> appStatus({
    required String platform,
    required String version,
  }) async =>
      AppStatus.unknown;

  @override
  Future<List<Ride>> history({int limit = 50}) async =>
      _world.rideHistory(limit: limit);

  @override
  Future<void> cancel({
    required String rideId,
    required String reasonId,
    required String canceledByUserId,
    required String actorType,
  }) async =>
      _world.cancelRide(
        rideId: rideId,
        reasonId: reasonId,
        canceledByUserId: canceledByUserId,
        actorType: actorType,
      );

  @override
  Future<void> rate({
    required String rideId,
    required int score,
    String? comments,
  }) async =>
      _world.rateRide(rideId: rideId, score: score, comments: comments);

  @override
  Future<PromoResult> applyPromo({
    required String rideId,
    required String promoCode,
  }) async =>
      _world.applyPromoCode(rideId: rideId, promoCode: promoCode);

  @override
  Future<Receipt> receipt(String rideId) async => _world.receiptFor(rideId);

  /// Books a future ride into the in-memory list, mirroring the live
  /// contract: the pickup must sit ≥30 virtual minutes out or the call
  /// fails with the documented VALIDATION_FAILED shape.
  @override
  Future<ScheduledRide> createScheduledRide({
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
    required DateTime requestedPickupTime,
    String? estimatedFareId,
  }) async {
    final minimum = _world.virtualNow.add(const Duration(minutes: 30));
    if (requestedPickupTime.isBefore(minimum)) {
      throw const ApiException(
        statusCode: 400,
        message: 'Scheduled rides must be booked at least 30 minutes ahead.',
        code: 'VALIDATION_FAILED',
      );
    }
    _scheduledIdCounter++;
    final scheduled = ScheduledRide(
      id: 'e1000000-0000-4000-8000-'
          '${_scheduledIdCounter.toRadixString(16).padLeft(12, '0')}',
      riderId: DemoSeed.riderId,
      requestedPickupTime: requestedPickupTime,
      estimatedFareId: estimatedFareId,
    );
    _scheduledRides.add(scheduled);
    return scheduled;
  }

  @override
  Future<List<ScheduledRide>> scheduledRides() async =>
      List.unmodifiable(_scheduledRides);

  /// One scheduled ride by id. Live currently surfaces not-found as
  /// `500 INTERNAL` (gap #22); the demo serves the corrected 404 shape the
  /// backend was asked for.
  @override
  Future<ScheduledRide> scheduledRide(String id) async {
    for (final scheduled in _scheduledRides) {
      if (scheduled.id == id) return scheduled;
    }
    throw const ApiException(
      statusCode: 404,
      message: 'Scheduled ride not found',
      code: 'NOT_FOUND',
    );
  }

  /// Capability seam (DEMO-07): live returns null; the world assembles the
  /// seeded identity + telemetry. Assembly logic lives in the world.
  @override
  Future<RideDriverInfo?> driverInfo(String rideId) async =>
      _world.driverInfoFor(rideId);

  /// Capability seam (DEMO-07): live cannot pre-check a promo (needs a ride
  /// id); the demo answers definitively from the seeded promo table. The
  /// fare is nominal — validity depends only on the code.
  @override
  Future<bool?> isPromoValid(String promoCode) async =>
      promoResultFor(code: promoCode, originalFare: 10) != null;

  /// Capability seam (MAP-03): live returns null (no driver-location read,
  /// gap #41); the world derives this from its deterministic geo-track.
  @override
  Future<DriverPosition?> driverPosition(String rideId) async =>
      _world.driverPositionFor(rideId);

  /// Capability seam (MAP-03): live returns null (ride detail carries no
  /// coords, gap #17); the world serves the scripted Wolverhampton track.
  @override
  Future<RideGeo?> rideGeo(String rideId) async => _world.rideGeoFor(rideId);

  /// In-trip chat is a v2/stretch item — never part of the scripted demo.
  @override
  Future<List<RideMessage>> messages(String rideId, {DateTime? since}) async =>
      const [];

  @override
  Future<RideMessage> sendMessage({
    required String rideId,
    required String body,
  }) =>
      throw UnsupportedError('Not part of the demo');
}
