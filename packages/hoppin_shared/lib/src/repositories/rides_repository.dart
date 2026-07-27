import 'dart:async';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../models/app_status.dart';
import '../models/cancellation_reason_option.dart';
import '../models/driver_position.dart';
import '../models/fare_estimate.dart';
import '../models/place_suggestion.dart';
import '../models/platform_contacts.dart';
import '../models/promo_offer.dart';
import '../models/promo_result.dart';
import '../models/receipt.dart';
import '../models/ride.dart';
import '../models/ride_driver_info.dart';
import '../models/ride_geo.dart';
import '../models/ride_message.dart';
import '../models/scheduled_ride.dart';
import '../models/vehicle_type.dart';

/// Typed bindings for the ride lifecycle endpoints on `:8080`.
///
/// Each method maps 1:1 to an endpoint in docs/04. The `[rider]`/`[driver]`
/// tags note who may call it; the backend also enforces the role from the JWT.
class RidesRepository {
  RidesRepository(this._api);

  final ApiClient _api;

  /// `POST /rides/estimate` — fare quote from the live pricing engine. `[rider]`
  Future<FareEstimate> estimate({
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
    String? vehicleCategoryId,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/rides/estimate',
      body: {
        'pickup_lat': pickupLat,
        'pickup_lng': pickupLng,
        'dropoff_lat': dropoffLat,
        'dropoff_lng': dropoffLng,
        'vehicle_category_id': ?vehicleCategoryId,
      },
    );
    return FareEstimate.fromJson(res.data!);
  }

  /// `POST /rides/request` — on-demand booking with guards + dispatch. `[rider]`
  /// Returns the `request_id` (202) — no ride row exists yet.
  Future<String> requestRide({
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
    String? vehicleCategoryId,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/rides/request',
      body: {
        'pickup_lat': pickupLat,
        'pickup_lng': pickupLng,
        'dropoff_lat': dropoffLat,
        'dropoff_lng': dropoffLng,
        'vehicle_category_id': ?vehicleCategoryId,
      },
    );
    return res.data!['request_id'] as String;
  }

  /// `GET /rides/:id` — one ride. `[either]`
  Future<Ride> getRide(String id) async {
    final res = await _api.get<Map<String, dynamic>>('/rides/$id');
    return Ride.fromJson(res.data!);
  }

  /// `GET /rides` — trip history, newest first, scoped to the caller. `[either]`
  Future<List<Ride>> history({int limit = 50}) async {
    final res = await _api.get<List<dynamic>>('/rides', query: {'limit': limit});
    return (res.data ?? [])
        .map((e) => Ride.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `PATCH /rides/:id/cancel` — cancel a ride. `[either]`
  /// `actorType` must be "rider" or "driver" and match the caller.
  Future<void> cancel({
    required String rideId,
    required String reasonId,
    required String canceledByUserId,
    required String actorType,
  }) async {
    await _api.patch<Map<String, dynamic>>(
      '/rides/$rideId/cancel',
      body: {
        'reason_id': reasonId,
        'canceled_by_user_id': canceledByUserId,
        'actor_type': actorType,
      },
    );
  }

  /// `GET /geocode/reverse?lat=&lng=` — name a coordinate the rider dropped a
  /// pin on, via the self-hosted Nominatim. Returns `{label, lat, lng}`; the
  /// server always supplies a label (a trimmed coordinate string if Nominatim
  /// has no name), so this never returns null on a 200. Returns null only on
  /// error so the picker can keep the raw pin.
  Future<({String label, double lat, double lng})?> reverseGeocode(
    double lat,
    double lng,
  ) async {
    try {
      final res = await _api.get<Map<String, dynamic>>(
        '/geocode/reverse',
        query: {'lat': lat, 'lng': lng},
      );
      final data = res.data;
      if (data == null) return null;
      final label = (data['label'] as String?)?.trim();
      return (
        label: (label == null || label.isEmpty) ? 'Pinned location' : label,
        lat: (data['lat'] as num?)?.toDouble() ?? lat,
        lng: (data['lng'] as num?)?.toDouble() ?? lng,
      );
    } on ApiException {
      return null;
    }
  }

  /// `GET /geocode/search?q=&lat=&lng=&limit=` — address type-ahead, served by
  /// the ride-service fronting our own Photon instance. `[either]`
  ///
  /// Pass the caller's current position as [lat]/[lng] when known: it **biases**
  /// ranking toward them without bounding it, so someone in Wolverhampton can
  /// still search a Manchester address. Omit rather than send a fabricated
  /// centre — a wrong bias is worse than none.
  ///
  /// Queries under two characters are answered locally with an empty list: the
  /// server returns nothing for them anyway, so there is no point spending a
  /// request per keystroke on the first letter.
  ///
  /// Returns an empty list (never throws) when the geocoder is unreachable —
  /// the picker still has the map pin and the caller's saved places, so a dead
  /// search box must not take the booking flow down with it.
  Future<List<PlaceSuggestion>> searchPlaces(
    String query, {
    double? lat,
    double? lng,
    int limit = 8,
  }) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    try {
      final res = await _api.get<Map<String, dynamic>>(
        '/geocode/search',
        query: {
          'q': q,
          'limit': limit,
          'lat': ?lat,
          'lng': ?lng,
        },
      );
      final rows = (res.data?['results'] as List<dynamic>?) ?? const <dynamic>[];
      return rows
          .whereType<Map<String, dynamic>>()
          .map(PlaceSuggestion.fromJson)
          // A hit with no label is unrenderable; drop it rather than show a
          // blank row the rider can tap.
          .where((s) => s.label.isNotEmpty)
          .toList();
    } on ApiException {
      return const [];
    }
  }

  /// `GET /promotions` — the public promotion CATALOGUE. `[rider]`
  ///
  /// 🔴 These are offers that EXIST and are open to riders — active, in-window,
  /// rider-audience. The server does NOT filter by who is asking, so this is
  /// **not** the caller's own wallet of codes. There is no `GET /me/promos`; the
  /// rider's personal codes stay unknowable, and a UI must not relabel this list
  /// as "your codes".
  ///
  /// Returns an empty list on failure rather than throwing: an offers strip is
  /// additive, and a promotions outage must not break the screen that carries it.
  Future<List<PromoOffer>> promotions() async {
    try {
      final res = await _api.get<Map<String, dynamic>>('/promotions');
      final rows =
          (res.data?['promotions'] as List<dynamic>?) ?? const <dynamic>[];
      return rows
          .whereType<Map<String, dynamic>>()
          .map(PromoOffer.fromJson)
          // A row with no code cannot be applied, so it is not an offer.
          .where((p) => p.promoCode.isNotEmpty)
          .toList();
    } on ApiException {
      return const [];
    }
  }

  /// `GET /api/v1/app-status?platform=&version=` — the launch gate. `[either]`,
  /// PUBLIC (no JWT — it runs before login).
  ///
  /// [platform] must be `ios` or `android`; the server rejects anything else, so
  /// callers on an ungated platform (web) should skip this and treat the status
  /// as [AppStatus.unknown] rather than sending a value that 400s.
  ///
  /// 🔴 Returns [AppStatus.unknown] (proceed) on ANY failure — offline, timeout,
  /// 4xx, 5xx. A launch check that cannot reach the server must never lock a user
  /// out of a working app: the operator's kill switch is a deliberate positive
  /// signal, never the absence of one. A 2-second timeout caps how long launch
  /// can block on it.
  Future<AppStatus> appStatus({
    required String platform,
    required String version,
  }) async {
    try {
      final res = await _api.get<Map<String, dynamic>>(
        '/app-status',
        query: {'platform': platform, 'version': version},
      ).timeout(const Duration(seconds: 2));
      final data = res.data;
      if (data == null) return AppStatus.unknown;
      return AppStatus.fromJson(data);
    } on ApiException {
      return AppStatus.unknown;
    } on TimeoutException {
      return AppStatus.unknown;
    }
  }

  /// `GET /api/v1/contacts` — the operator's real support/emergency numbers.
  /// `[either]`, and PUBLIC: no JWT, deliberately, because a rider in trouble
  /// may not be signed in.
  ///
  /// Returns an empty [PlatformContacts] on failure so the caller falls back to
  /// its honest "tickets only" copy rather than showing a broken row.
  ///
  /// Registered on the router ROOT as `/api/v1/contacts` (not inside the `v1`
  /// group), but `ApiClient`'s base URL already ends in `/api/v1`, so the
  /// relative path below resolves to the same URL.
  Future<PlatformContacts> contacts() async {
    try {
      final res = await _api.get<Map<String, dynamic>>('/contacts');
      final data = res.data;
      if (data == null) return const PlatformContacts();
      return PlatformContacts.fromJson(data);
    } on ApiException {
      return const PlatformContacts();
    }
  }

  /// `GET /vehicle-types` — the bookable vehicle classes with their REAL ids.
  /// `[rider]`
  ///
  /// Rows with no id are dropped: a class the client cannot send as
  /// `vehicle_category_id` is not bookable, and rendering it as if it were
  /// produces a picker option that 400s on submit.
  ///
  /// Returns an empty list on failure; the caller keeps its static fallback
  /// rather than showing a rider an empty vehicle picker.
  Future<List<VehicleType>> vehicleTypes() async {
    try {
      final res = await _api.get<Map<String, dynamic>>('/vehicle-types');
      final rows =
          (res.data?['vehicle_types'] as List<dynamic>?) ?? const <dynamic>[];
      return rows
          .whereType<Map<String, dynamic>>()
          .map(VehicleType.fromJson)
          .where((v) => v.id.isNotEmpty && v.name.isNotEmpty)
          .toList();
    } on ApiException {
      return const [];
    }
  }

  /// `GET /service-areas/check?lat=&lng=` — is this pickup inside a licensed
  /// area? `[rider]` This is the SERVER-AUTHORITATIVE geofence (admin-configured
  /// licensed areas + regulatory audit log), fired on Confirm Pickup.
  ///
  /// Returns:
  ///  * `true`  — server confirms in-area.
  ///  * `false` — server DEFINITIVELY says out-of-area (a hard, honest block).
  ///  * `null`  — the check could not be made: offline, 4xx/5xx, or slower than
  ///    the 2-second cap.
  ///
  /// 🔴 Null must NEVER be treated as "out of area". The client already ran its
  /// approximate polygon pre-filter before this call, and `POST /rides/request`
  /// runs the definitive geofence again with the audit log — so a failed or slow
  /// pre-check must fail OPEN and let the rider proceed, with the booking request
  /// itself as the real gate. Blocking on a dropped request would tell a rider in
  /// a genuine coverage area "we don't serve you", which is both wrong and the
  /// worst possible message. The 2-second timeout caps how long Confirm Pickup
  /// can wait on it.
  Future<bool?> isServiceable(double lat, double lng) async {
    try {
      final res = await _api
          .get<Map<String, dynamic>>(
            '/service-areas/check',
            query: {'lat': lat, 'lng': lng},
          )
          .timeout(const Duration(seconds: 2));
      return res.data?['in_service'] as bool?;
    } on ApiException {
      return null;
    } on TimeoutException {
      return null;
    }
  }

  /// `GET /cancellation-reasons` — the seeded reasons a rider/driver may pick
  /// when cancelling. The `PATCH /rides/:id/cancel` endpoint validates the
  /// `reason_id` against these rows, so the app MUST use these real ids (not a
  /// fabricated placeholder, which 400s). `[either]`
  Future<List<CancellationReasonOption>> cancellationReasons() async {
    final res = await _api.get<Map<String, dynamic>>('/cancellation-reasons');
    final rows = (res.data?['cancellation_reasons'] as List<dynamic>?) ??
        const <dynamic>[];
    return rows
        .whereType<Map<String, dynamic>>()
        .map(CancellationReasonOption.fromJson)
        .toList();
  }

  /// `POST /rides/:id/rating` — rate the other party after completion. `[either]`
  Future<void> rate({
    required String rideId,
    required int score,
    String? comments,
  }) async {
    await _api.post<Map<String, dynamic>>(
      '/rides/$rideId/rating',
      body: {'score': score, 'comments': ?comments},
    );
  }

  /// `POST /rides/:id/promo` — apply a promo code, discounting the fare. `[rider]`
  /// Rich error codes: `PROMO_NOT_FOUND`, `PROMO_EXHAUSTED`, `PROMO_USED`,
  /// `PROMO_MIN_RIDE`, `PROMO_BUDGET_EXHAUSTED`, … (docs/04).
  Future<PromoResult> applyPromo({
    required String rideId,
    required String promoCode,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/rides/$rideId/promo',
      body: {'promo_code': promoCode},
    );
    return PromoResult.fromJson(res.data!);
  }

  /// `GET /rides/:id/receipt` — itemised receipt for a completed ride,
  /// amounts in integer pence. `[rider]`
  Future<Receipt> receipt(String rideId) async {
    final res = await _api.get<Map<String, dynamic>>('/rides/$rideId/receipt');
    return Receipt.fromJson(res.data!);
  }

  /// `GET /rides/:id/messages` — in-trip chat. Pass [since] (the newest
  /// message's timestamp) for incremental polling. `[either]`
  Future<List<RideMessage>> messages(String rideId, {DateTime? since}) async {
    final res = await _api.get<Map<String, dynamic>>(
      '/rides/$rideId/messages',
      query: {
        if (since != null) 'since': since.toUtc().toIso8601String(),
      },
    );
    final list = res.data?['messages'] as List<dynamic>? ?? [];
    return list
        .map((e) => RideMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `POST /rides/:id/messages` — send a chat message. Participants only;
  /// `409 CHAT_CLOSED` after completion. `[either]`
  Future<RideMessage> sendMessage({
    required String rideId,
    required String body,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/rides/$rideId/messages',
      body: {'body': body},
    );
    return RideMessage.fromJson(res.data!);
  }

  // ── Scheduled rides ────────────────────────────────────────────────────────

  /// `POST /scheduled-rides` — book a future ride, ≥30 minutes out. A
  /// server-side watchdog converts it to an active ride near pickup time
  /// (docs/04). `[rider]`
  Future<ScheduledRide> createScheduledRide({
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
    required DateTime requestedPickupTime,
    String? estimatedFareId,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/scheduled-rides',
      body: {
        'pickup_lat': pickupLat,
        'pickup_lng': pickupLng,
        'dropoff_lat': dropoffLat,
        'dropoff_lng': dropoffLng,
        'requested_pickup_time':
            requestedPickupTime.toUtc().toIso8601String(),
        'estimated_fare_id': ?estimatedFareId,
      },
    );
    return ScheduledRide.fromJson(res.data!);
  }

  /// `GET /scheduled-rides` — the caller's scheduled rides. `[rider]`
  Future<List<ScheduledRide>> scheduledRides() async {
    final res = await _api.get<List<dynamic>>('/scheduled-rides');
    return (res.data ?? [])
        .map((e) => ScheduledRide.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `GET /scheduled-rides/:id` — one scheduled ride. Note: a not-found id
  /// currently surfaces as `500 INTERNAL` on live (docs/04, gap #22). `[rider]`
  Future<ScheduledRide> scheduledRide(String id) async {
    final res = await _api.get<Map<String, dynamic>>('/scheduled-rides/$id');
    return ScheduledRide.fromJson(res.data!);
  }

  // ── Capability seam (DEMO-07 pattern) ─────────────────────────────────────

  /// `GET /rides/:id/driver-info` — the matched driver's identity, vehicle, and
  /// live-trip telemetry for [rideId]. `[rider]` — also readable by the
  /// assigned driver and admin (docs/04). Returns null on `409 NO_DRIVER_ASSIGNED`
  /// (ride still requesting/matching — not an error). NOTE: implementers of this
  /// class's implicit interface must override this member too.
  ///
  /// SEAM(#5, state: WIRED, ledgerRef: relayed-seamed, feature: driver-info, unavailable: rider=DriverUnavailableCard)
  Future<RideDriverInfo?> driverInfo(String rideId) async {
    try {
      final res = await _api.get<Map<String, dynamic>>(
        '/rides/$rideId/driver-info',
      );
      return RideDriverInfo.fromJson(res.data!);
    } on ApiException catch (e) {
      // 409 NO_DRIVER_ASSIGNED — ride exists but is still matching; not an
      // error from the app's perspective. All other errors propagate.
      if (e.statusCode == 409) return null;
      rethrow;
    }
  }

  /// Capability seam: pre-ride promo-code check for entry-time feedback.
  /// `:8080` can only validate a promo against an existing ride
  /// (`POST /rides/:id/promo`), so live answers null — "cannot check" —
  /// and the booking flow stages the code for the match beat. The demo
  /// fake answers true/false from the seeded promo table. NOTE:
  /// implementers of this class's implicit interface must override this
  /// member too.
  ///
  /// SEAM(#46, state: SEAMED, ledgerRef: row:24, feature: Promotions, unavailable: PromoUnavailableState)
  Future<bool?> isPromoValid(String promoCode) async => null;

  /// Capability seam: the driver's live position for the active [rideId].
  /// No rider-facing driver-location read exists on `:8080` — heartbeats
  /// via `POST /drivers/me/location` are write-only (CODE-GRAPH §6 #41 /
  /// DOCS/06 P1) — so live deliberately returns null and the map degrades
  /// to route-only. The demo fake overrides this from the world's
  /// deterministic geo-track. [DriverPosition] is shaped for the asked
  /// `GET /rides/:id/driver-location`, so a straight deserialization fills
  /// this seam when the endpoint ships. NOTE: implementers of this class's
  /// implicit interface must override this member too.
  ///
  /// TWO SURFACES CONSUME THIS SEAM (v3.0 Phase 0). The rider's map degrades to
  /// route-only (`RouteOnlyMapState`). The DRIVER also calls it — at
  /// `apps/driver/lib/features/trip/map/map_interactor.dart:92` and
  /// `apps/driver/lib/features/offer_takeover/offer_takeover_interactor.dart:99`
  /// — and disclosed nothing at all until this milestone: the driver's canvas
  /// collapsed to `SizedBox.shrink()` on every live trip. One gap, N
  /// disclosures.
  ///
  /// SEAM(#41, state: BOUND) — `GET /rides/:id/driver-location`. The endpoint
  /// is live: it returns the assigned driver's last-known position from the
  /// Redis hash telemetry writes on every heartbeat, e.g.
  /// `{lat, lng, heading, updated_at, age_seconds}`. Returns null only when the
  /// server has no fresh position (409 NO_DRIVER_ASSIGNED / RIDE_NOT_ACTIVE /
  /// POSITION_UNAVAILABLE) so the map degrades gracefully rather than erroring.
  Future<DriverPosition?> driverPosition(String rideId) async {
    try {
      final res = await _api.get<Map<String, dynamic>>(
        '/rides/$rideId/driver-location',
      );
      final data = res.data;
      if (data == null) return null;
      return DriverPosition.fromJson(data);
    } on ApiException {
      // No fresh position yet — honest degrade, not an error.
      return null;
    }
  }

  /// Capability seam: static route geometry (pickup, dropoff, polylines)
  /// for [rideId]. `GET /rides/:id` carries no coordinates (CODE-GRAPH §6
  /// #17 / DOCS/06 P1), so live deliberately returns null and the map pane
  /// hides; the demo serves the scripted Wolverhampton track. NOTE:
  /// implementers of this class's implicit interface must override this
  /// member too.
  ///
  /// TWO SURFACES CONSUME THIS SEAM (v3.0 Phase 0) — the rider's map and the
  /// DRIVER's nav canvas (`apps/driver/lib/features/trip/map/
  /// map_interactor.dart:98`), which disclosed nothing until this milestone.
  ///
  /// SEAM(#17, state: BOUND) — `GET /rides/:id/geo`. The endpoint is live: it
  /// returns `{pickup_lat, pickup_lng, dropoff_lat, dropoff_lng, route[],
  /// approach}` (pickup/dropoff from the ride's stored coordinates; route is
  /// currently the straight pickup→dropoff pair until road-polyline geometry is
  /// persisted). Returns null on any error so the map degrades to the
  /// handoff-coord fallback rather than throwing.
  Future<RideGeo?> rideGeo(String rideId) async {
    try {
      final res = await _api.get<Map<String, dynamic>>('/rides/$rideId/geo');
      final data = res.data;
      if (data == null) return null;
      return RideGeo.fromJson(data);
    } on ApiException {
      return null;
    }
  }

  // Driver-side lifecycle transitions (all `[driver]`, assigned driver only):
  //   PATCH /rides/:id/accept   { driver_id }
  //   PATCH /rides/:id/arrive
  //   PATCH /rides/:id/start
  //   PATCH /rides/:id/complete { actual_distance_meters? }
  // Implemented in DriverRepository to keep rider/driver surfaces separate.
}
