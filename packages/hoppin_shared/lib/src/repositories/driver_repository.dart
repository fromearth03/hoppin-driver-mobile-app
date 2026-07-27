import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../models/cancellation_reason_option.dart';
import '../models/destination_filter.dart';
import '../models/driver_document.dart';
import '../models/payout_account.dart';
import '../models/ride_offer.dart';

/// Capability-seam payload: the driver's day so far plus live-trip
/// telemetry. The live API has no telemetry endpoint yet (docs/04), so
/// the base implementation answers null and the UI degrades gracefully;
/// the demo fake overrides it from the world.
typedef DriverDayStats = ({
  bool online,
  int earningsPence,
  int tripCount,
  Duration onlineTime,
  int? pickupEtaSeconds, // null unless a trip is en route to pickup; 0 == arriving now
  String? activeRideId, // a ride THIS driver accepted and is running, else null
});

/// Capability-seam payload: who the rider is and where pickup is, for the
/// offer takeover + trip runner context row.
///
/// [rating] is null by design — `rider_profiles.average_rating` defaults to
/// 5.00 but nothing maintains it, so serving it would render a fabricated 5.0
/// for every rider. Render the absence.
/// [pickupLabel] and [pickupEtaSeconds] are null on first ship (no address
/// column in the schema; live-map decision pending).
typedef TripRiderContext = ({
  String name,
  double? rating,
  String? pickupLabel,
  int? pickupEtaSeconds,
});

/// One completed payout run, as `GET /drivers/me/wallet` reports it in its
/// `recent_payouts` array (the last 10, newest first).
///
/// [amountPence] is converted at this boundary — see [DriverWallet].
/// [status] is the server's own token (`paid`, `failed`, `pending`, …). It is
/// rendered verbatim and never mapped to a friendlier word: the payout
/// vocabulary is unpublished, so a token we do not recognise must not be
/// silently relabelled into one we do.
typedef DriverPayout = ({
  String id,
  int amountPence,
  String status,
  DateTime? transferredAt,
});

/// Capability payload: the driver's wallet balances and recent payout runs,
/// from `GET /drivers/me/wallet`.
///
/// 🔴 UNIT BOUNDARY — READ BEFORE TOUCHING THE ARITHMETIC.
///
/// The two driver money endpoints disagree about units, and the disagreement
/// is invisible at the call site because both are just numbers:
///
///   `GET /drivers/me/today`  → `earnings_pence`, an **int in PENCE**
///   `GET /drivers/me/wallet` → `available_balance`, a **float in POUNDS**
///     (straight off `driver_wallets.available_balance DECIMAL(10,2)`, no ×100)
///
/// So this typedef normalises to **pence at the repository boundary** and the
/// whole client speaks one unit above it. Getting this backwards under-reports
/// a driver's balance by 100× — £245.80 rendered as £2.45 — and a driver who
/// believes they have been paid £2.45 will act on that. Money crossing a
/// boundary in the wrong unit is not a formatting bug.
///
/// The conversion uses `.round()` on `pounds * 100` rather than `.toInt()`:
/// binary floating point cannot hold 245.80 exactly (it is 245.7999…), and
/// `.toInt()` truncates toward zero, so `.toInt()` would render £245.79. One
/// penny, every time, always in the platform's favour, on a self-employed
/// person's pay.
typedef DriverWallet = ({
  int availableBalancePence,
  int pendingBalancePence,
  String currency,
  DateTime? lastPayoutAt,
  List<DriverPayout> recentPayouts,
});

/// The presigned upload slot `POST /drivers/me/documents/upload-url` issues:
/// PUT the raw bytes to [uploadUrl] with exactly [contentType], then confirm
/// with [key]. The URL expires 5 minutes out; uploads cap at [maxBytes]
/// (10 MB).
typedef DocumentUploadSlot = ({
  String uploadUrl,
  String key,
  String contentType,
  DateTime urlExpiresAt,
  int maxBytes,
});

/// Typed bindings for the driver-only endpoints on `:8080` (docs/04 · Driver
/// operations). The driver identity comes from the JWT subject — bodies never
/// carry the driver id, except `accept` which the doc requires.
class DriverRepository {
  DriverRepository(this._api);

  final ApiClient _api;

  // ── Offers loop ──────────────────────────────────────────────────────────

  /// `GET /drivers/me/offers` — pending offers dispatched to this driver.
  Future<List<RideOffer>> offers() async {
    final res = await _api.get<List<dynamic>>('/drivers/me/offers');
    return (res.data ?? [])
        .map((e) => RideOffer.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `POST /offers/:id/accept` — accept an offer (ride → accepted, pre-auth).
  Future<void> acceptOffer(String offerId) =>
      _api.post<Map<String, dynamic>>('/offers/$offerId/accept');

  /// `POST /offers/:id/decline` — decline; ride is re-dispatched.
  Future<void> declineOffer(String offerId) =>
      _api.post<Map<String, dynamic>>('/offers/$offerId/decline');

  // ── Presence & availability ──────────────────────────────────────────────

  /// `POST /drivers/me/online` — enter the dispatch pool (compliance-gated).
  Future<void> goOnline() =>
      _api.post<Map<String, dynamic>>('/drivers/me/online');

  /// `POST /drivers/me/offline` — leave the pool.
  Future<void> goOffline() =>
      _api.post<Map<String, dynamic>>('/drivers/me/offline');

  /// `POST /drivers/me/location` — location heartbeat. Drives admin
  /// Active/Offline presence — a driver is "Active" only if pinged within the
  /// last 5 minutes, so send this well more often than that while online.
  Future<void> heartbeat({required double lat, required double lng}) =>
      _api.post<Map<String, dynamic>>(
        '/drivers/me/location',
        body: {'lat': lat, 'lng': lng},
      );

  // ── Ride lifecycle transitions (assigned driver only) ────────────────────

  /// `PATCH /rides/:id/accept` — driver accepts a matching ride.
  Future<void> acceptRide({required String rideId, required String driverId}) =>
      _api.patch<Map<String, dynamic>>(
        '/rides/$rideId/accept',
        body: {'driver_id': driverId},
      );

  /// `PATCH /rides/:id/arrive` — mark arrival at pickup.
  Future<void> markArrived(String rideId) =>
      _api.patch<Map<String, dynamic>>('/rides/$rideId/arrive');

  /// `PATCH /rides/:id/start` — start the trip.
  Future<void> startRide(String rideId) =>
      _api.patch<Map<String, dynamic>>('/rides/$rideId/start');

  /// `PATCH /rides/:id/complete` — complete; triggers the final charge +
  /// driver credit. `actualDistanceMeters` uses metered GPS if provided.
  Future<void> completeRide(
    String rideId, {
    int? actualDistanceMeters,
  }) =>
      _api.patch<Map<String, dynamic>>(
        '/rides/$rideId/complete',
        body: {
          'actual_distance_meters': ?actualDistanceMeters,
        },
      );

  /// `GET /cancellation-reasons` — the seeded reasons, filtered to the ones a
  /// DRIVER may cite. The endpoint is live; `reason_id` must be one of these
  /// real uuids or the cancel 400s.
  Future<List<CancellationReasonOption>> driverCancellationReasons() async {
    final res = await _api.get<Map<String, dynamic>>('/cancellation-reasons');
    final rows =
        (res.data?['cancellation_reasons'] as List<dynamic>?) ?? const [];
    return rows
        .whereType<Map<String, dynamic>>()
        .map(CancellationReasonOption.fromJson)
        .where((r) => r.actorType == 'driver')
        .toList();
  }

  /// `PATCH /rides/:id/cancel` — the driver cancels an accepted ride.
  ///
  /// Scope Lock §4.2: "Drivers may cancel trips after acceptance or arrival
  /// according to platform rules." This is bound: the reasons endpoint serves
  /// driver-actor rows and the server accepts `actor_type: "driver"`. A driver
  /// at a no-show is no longer trapped in a live trip.
  Future<void> cancelRide({
    required String rideId,
    required String reasonId,
    required String driverId,
  }) =>
      _api.patch<Map<String, dynamic>>(
        '/rides/$rideId/cancel',
        body: {
          'reason_id': reasonId,
          'canceled_by_user_id': driverId,
          'actor_type': 'driver',
        },
      );

  // ── Capability seams (DEMO-07 pattern) ───────────────────────────────────

  /// `GET /drivers/me/today` — today's earnings, trips, online time, and
  /// live-trip telemetry. `[driver]` — identity from JWT subject (docs/04).
  ///
  /// The dashboard MUST NOT gate its online-state on this seam. Presence is
  /// authoritative from `goOnline()`/`goOffline()`; these stats are decoration.
  ///
  /// SEAM(#7, state: WIRED, ledgerRef: row:28, feature: Driver day stats, unavailable: driver=DriverStatsUnavailable)
  Future<DriverDayStats?> todayStats() async {
    final res =
        await _api.get<Map<String, dynamic>>('/drivers/me/today');
    final body = res.data!;
    return (
      online: body['online'] as bool,
      earningsPence: body['earnings_pence'] as int,
      tripCount: body['trip_count'] as int,
      onlineTime:
          Duration(seconds: body['online_seconds'] as int),
      pickupEtaSeconds: body['pickup_eta_seconds'] as int?,
      activeRideId: body['active_ride_id'] as String?,
    );
  }

  /// `GET /drivers/me/wallet` — the driver's balances and their last 10 payout
  /// runs. `[driver]` — identity from the JWT subject.
  ///
  /// 🔴 POUNDS IN, PENCE OUT. The endpoint answers pounds as floats (the
  /// columns are `DECIMAL(10,2)`); every field is converted here so the client
  /// above this line speaks pence only. See [DriverWallet] for why the
  /// rounding mode is load-bearing.
  ///
  /// WHAT THIS ENDPOINT IS NOT. It reports two balances and a payout list.
  /// It does NOT carry per-trip earnings, a fare breakdown, a commission or
  /// VAT split, a next-payout date, a threshold, or any owed/owing figure —
  /// there is no endpoint for any of those (#47), and the Figma earnings
  /// frames draw all of them. A screen built over this method may render the
  /// balances and the payout rows and MUST disclose the rest as unavailable.
  /// Do not fill the gap by deriving figures from these two numbers: a
  /// breakdown inferred client-side is an invented breakdown.
  ///
  /// SEAM(#47, state: WIRED, ledgerRef: row:47, feature: Driver wallet, unavailable: driver=DriverEarningsUnavailable)
  Future<DriverWallet?> wallet() async {
    final res = await _api.get<Map<String, dynamic>>('/drivers/me/wallet');
    final body = res.data!;

    int toPence(num? pounds) => ((pounds ?? 0) * 100).round();

    final payouts = (body['recent_payouts'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map<DriverPayout>(
          (p) => (
            id: p['id'] as String,
            amountPence: toPence(p['amount'] as num?),
            status: p['status'] as String,
            transferredAt: p['transferred_at'] == null
                ? null
                : DateTime.parse(p['transferred_at'] as String),
          ),
        )
        .toList(growable: false);

    return (
      availableBalancePence: toPence(body['available_balance'] as num?),
      pendingBalancePence: toPence(body['pending_balance'] as num?),
      currency: body['currency'] as String? ?? 'GBP',
      lastPayoutAt: body['last_payout_at'] == null
          ? null
          : DateTime.parse(body['last_payout_at'] as String),
      recentPayouts: payouts,
    );
  }

  /// `GET /rides/:id/rider-context` — who the rider is and where pickup is,
  /// for the offer takeover and the trip-runner context row. `[driver]` —
  /// assigned driver only (docs/04). Returns null when the ride exists but the
  /// caller is not the assigned driver (403), so callers never learn a rider's
  /// identity by guessing ride ids.
  ///
  /// [rating], [pickupLabel], and [pickupEtaSeconds] are deliberately null on
  /// first ship — see [TripRiderContext] field docs.
  ///
  /// SEAM(#6, state: WIRED, ledgerRef: row:29, feature: Trip rider context, unavailable: driver=RiderContextUnavailable)
  Future<TripRiderContext?> tripRiderContext(String rideId) async {
    try {
      final res = await _api.get<Map<String, dynamic>>(
        '/rides/$rideId/rider-context',
      );
      final body = res.data!;
      return (
        name: body['name'] as String,
        rating: (body['rating'] as num?)?.toDouble(),
        pickupLabel: body['pickup_label'] as String?,
        pickupEtaSeconds: body['pickup_eta_seconds'] as int?,
      );
    } on ApiException catch (e) {
      // 403 FORBIDDEN — caller is not the assigned driver; return null so the
      // UI degrades gracefully without revealing that the ride exists.
      if (e.statusCode == 403) return null;
      rethrow;
    }
  }

  // ── Destination filter (heading-home) ────────────────────────────────────

  /// `PUT /drivers/me/destination-filter` — set a 2-hour heading-home filter.
  Future<void> setDestinationFilter({
    required double lat,
    required double lng,
  }) =>
      _api.put<Map<String, dynamic>>(
        '/drivers/me/destination-filter',
        body: {'lat': lat, 'lng': lng},
      );

  /// `GET /drivers/me/destination-filter` — the current filter, or the honest
  /// inactive state.
  ///
  /// The counter and the expiry come back from the SERVER — see
  /// [DestinationFilter]. This returns a typed value rather than a raw map
  /// precisely so that no caller can reach for a key, find it missing, and
  /// invent a number to put in its place.
  Future<DestinationFilter> getDestinationFilter() async {
    final res = await _api
        .get<Map<String, dynamic>>('/drivers/me/destination-filter');
    // An empty body reads `active` as absent → inactive. Never a crash.
    return DestinationFilter.fromJson(res.data ?? const {});
  }

  /// `DELETE /drivers/me/destination-filter` — clear it.
  Future<void> clearDestinationFilter() =>
      _api.delete<Map<String, dynamic>>('/drivers/me/destination-filter');

  // ── Compliance documents ─────────────────────────────────────────────────
  // Two-step upload (docs/04): documentUploadUrl → PUT the raw bytes to the
  // presigned url with the same Content-Type (screen-side, plain HTTP — not
  // a `:8080` call) → confirmDocument with the returned key.

  /// The eight compliance document types the platform accepts (docs/04) —
  /// the exact `document_type` vocabulary of every documents endpoint.
  static const List<String> documentTypes = [
    'dvla_license',
    'wolverhampton_taxi_badge',
    'nr3s_background_check',
    'right_to_work',
    'mot_certificate',
    'insurance_policy',
    'v5c_logbook',
    'caz_compliance_proof',
  ];

  /// The three upload content types the presigned flow accepts (docs/04).
  static const List<String> documentContentTypes = [
    'application/pdf',
    'image/jpeg',
    'image/png',
  ];

  /// `POST /drivers/me/documents/upload-url` — a presigned PUT slot for one
  /// compliance document. `503 STORAGE_DISABLED` when storage is off.
  Future<DocumentUploadSlot> documentUploadUrl({
    required String documentType,
    required String contentType,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/drivers/me/documents/upload-url',
      body: {'document_type': documentType, 'content_type': contentType},
    );
    final data = res.data!;
    return (
      uploadUrl: data['upload_url'] as String,
      key: data['key'] as String,
      contentType: data['content_type'] as String,
      urlExpiresAt: DateTime.parse(data['url_expires_at'] as String),
      maxBytes: data['max_bytes'] as int,
    );
  }

  /// `POST /drivers/me/documents` — confirm an uploaded document. The server
  /// verifies the object exists, replaces any current document of that type,
  /// and marks it `pending_review`.
  Future<DriverDocument> confirmDocument({
    required String documentType,
    required String key,
    DateTime? expiresAt,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/drivers/me/documents',
      body: {
        'document_type': documentType,
        'key': key,
        'expires_at': ?expiresAt?.toUtc().toIso8601String(),
      },
    );
    return DriverDocument.fromJson(res.data!);
  }

  /// `GET /drivers/me/documents` — my documents + review status, newest
  /// first.
  Future<List<DriverDocument>> documents() async {
    final res =
        await _api.get<Map<String, dynamic>>('/drivers/me/documents');
    final list = res.data?['documents'] as List<dynamic>? ?? [];
    return list
        .map((e) => DriverDocument.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Stripe Connect payouts `[driver]` ────────────────────────────────────

  /// `GET /me/payout-account` — am I set up to be PAID?
  ///
  /// Distinguishes "no Stripe account yet" from "account exists but Stripe has
  /// not cleared payouts". Returns a not-started status on failure rather than
  /// throwing: the earnings screen must still render its balance if this read
  /// is the only thing that broke.
  Future<PayoutStatus> payoutStatus() async {
    try {
      final res = await _api.get<Map<String, dynamic>>('/me/payout-account');
      final data = res.data;
      if (data == null) return const PayoutStatus();
      return PayoutStatus.fromJson(data);
    } on ApiException {
      return const PayoutStatus();
    }
  }

  /// `POST /me/payout-account` — start (or resume) Stripe Connect onboarding.
  ///
  /// Idempotent server-side: an existing account is reused and a FRESH hosted
  /// link is minted, so a driver who abandoned onboarding halfway can resume.
  ///
  /// 🔴 The returned link is single-use and short-lived. Mint it on tap and
  /// open it immediately — never cache it, or the driver gets a dead Stripe
  /// page and no way to tell why.
  ///
  /// Throws [ApiException] — unlike the read above, a failure here MUST surface:
  /// the driver pressed a button and is waiting for a browser to open.
  Future<PayoutOnboarding> startPayoutOnboarding() async {
    final res = await _api.post<Map<String, dynamic>>('/me/payout-account');
    final data = res.data;
    if (data == null) return const PayoutOnboarding();
    return PayoutOnboarding.fromJson(data);
  }
}
