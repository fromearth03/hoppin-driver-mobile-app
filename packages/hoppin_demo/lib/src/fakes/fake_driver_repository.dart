import 'package:hoppin_shared/hoppin_shared.dart';

import '../seed/demo_seed.dart';
import '../seed/personas.dart';
import '../seed/places.dart';
import '../world/demo_script.dart';
import '../world/demo_world.dart';

/// The driver-operations surface over [DemoWorld] — same-named delegations
/// for the offers loop and the ride lifecycle; presence telemetry and the
/// destination filter are calm no-ops (nothing in the demo consumes them).
class FakeDriverRepository implements DriverRepository {
  FakeDriverRepository(this._world);

  final DemoWorld _world;

  /// Gurpreet's seeded compliance wallet, newest-first like the live read:
  /// insurance renewed three weeks ago, DVLA licence verified with no
  /// tracked expiry (the nullable path), and an MOT certificate expiring
  /// 20 virtual days out — the renewal-reminder beat. All timestamps derive
  /// from [DemoSeed.anchor], never the wall clock.
  static final List<DriverDocument> _seededDocuments = [
    DriverDocument(
      id: 'e3000000-0000-4000-8000-000000000001',
      documentType: 'insurance_policy',
      verificationStatus: 'verified',
      uploadedAt: DemoSeed.anchor.subtract(const Duration(days: 21)),
      expiresAt: DemoSeed.anchor.add(const Duration(days: 344)),
    ),
    DriverDocument(
      id: 'e3000000-0000-4000-8000-000000000002',
      documentType: 'dvla_license',
      verificationStatus: 'verified',
      uploadedAt: DemoSeed.anchor.subtract(const Duration(days: 90)),
    ),
    DriverDocument(
      id: 'e3000000-0000-4000-8000-000000000003',
      documentType: 'mot_certificate',
      verificationStatus: 'verified',
      uploadedAt: DemoSeed.anchor.subtract(const Duration(days: 345)),
      expiresAt: DemoSeed.anchor.add(const Duration(days: 20)),
    ),
  ];

  /// Session document state: the seed plus this run's confirms. In-memory
  /// by design (no snapshot codec change) — no screen consumes it yet.
  final List<DriverDocument> _documents = [..._seededDocuments];
  int _documentIdCounter = 3;
  int _uploadKeyCounter = 0;

  @override
  Future<List<RideOffer>> offers() async => _world.pendingOffers();

  @override
  Future<void> acceptOffer(String offerId) async =>
      _world.acceptOffer(offerId);

  @override
  Future<void> declineOffer(String offerId) async =>
      _world.declineOffer(offerId);

  @override
  Future<void> goOnline() async => _world.goOnline();

  @override
  Future<void> goOffline() async => _world.goOffline();

  /// Location heartbeat — presence is a live-backend concept; no-op here.
  @override
  Future<void> heartbeat({required double lat, required double lng}) async {}

  /// Accepts via the pending offer for [rideId]. Tolerant by design: when no
  /// matching offer is pending (already accepted, or gone), it is a quiet
  /// no-op — the demo never dead-ends on a double tap.
  @override
  Future<void> acceptRide({
    required String rideId,
    required String driverId,
  }) async {
    for (final offer in _world.pendingOffers()) {
      if (offer.rideId == rideId) {
        _world.acceptOffer(offer.offerId);
        return;
      }
    }
  }

  @override
  Future<void> markArrived(String rideId) async => _world.markArrived(rideId);

  /// The driver-actor cancellation reasons. Mirrors the live endpoint's shape
  /// (it filters to `actor_type == 'driver'`) so the stuck-exit sheet takes the
  /// same "pick a no-penalty reason" path in demo as it does on live.
  @override
  Future<List<CancellationReasonOption>> driverCancellationReasons() async => [
        // Seeded ids — DemoWorld.cancelRide validates against
        // DemoSeed.cancellationReasonIds and 422s on anything else.
        CancellationReasonOption(
          id: DemoSeed.cancellationReasonIds[2],
          reasonText: 'driver_declined',
          appliesPenaltyFee: false,
          actorType: 'driver',
        ),
        CancellationReasonOption(
          id: DemoSeed.cancellationReasonIds[3],
          reasonText: 'offer_timeout',
          appliesPenaltyFee: false,
          actorType: 'driver',
        ),
      ];

  /// A driver-initiated cancel. Terminal for the demo ride, same as the live
  /// transition — the driver is released and the runner leaves the trip.
  @override
  Future<void> cancelRide({
    required String rideId,
    required String reasonId,
    required String driverId,
  }) async =>
      _world.cancelRide(
        rideId: rideId,
        reasonId: reasonId,
        canceledByUserId: driverId,
        actorType: 'driver',
      );

  @override
  Future<void> startRide(String rideId) async => _world.startRide(rideId);

  @override
  Future<void> completeRide(String rideId, {int? actualDistanceMeters}) async =>
      _world.completeRide(rideId, actualDistanceMeters: actualDistanceMeters);

  /// Capability seam (DEMO-07 pattern, driver-side): live answers null,
  /// the demo surfaces the world's telemetry getters verbatim.
  @override
  Future<DriverDayStats?> todayStats() async => (
        online: _world.online,
        earningsPence: _world.todayEarningsPence,
        tripCount: _world.todayTripCount,
        onlineTime: _world.todayOnlineTime,
        pickupEtaSeconds: _world.etaSecondsRemaining,
        activeRideId: _activeRideId,
      );

  /// The driver's wallet — `GET /drivers/me/wallet` (seam #47, WIRED).
  ///
  /// A ZEROED wallet, not null. `GET /drivers/me/wallet` is a real, live read,
  /// so returning null here forced the demo's own driver onto the
  /// "Balance unavailable" ERROR rung — a broken-looking state for a feature
  /// that works. A zeroed wallet is instead the TRUE state of a driver who has
  /// not earned yet: £0.00 available, £0.00 pending, no payout runs. It drives
  /// the real balance hero and the honest "No payouts yet" empty rung — the
  /// same screen a genuine new driver sees, which is exactly what the demo
  /// should show. No figure is fabricated: every number here is zero.
  @override
  Future<DriverWallet?> wallet() async => (
        availableBalancePence: 0,
        pendingBalancePence: 0,
        currency: 'GBP',
        lastPayoutAt: null,
        recentPayouts: const <DriverPayout>[],
      );

  /// The ride THIS driver accepted and is running, else null. The head of
  /// [DemoWorld.rideHistory] is the live ride when one exists; `matching`
  /// is the offer stage (not yet the driver's trip) and terminal rows are
  /// finished business — neither counts as active.
  String? get _activeRideId {
    final rides = _world.rideHistory(limit: 1);
    if (rides.isEmpty) return null;
    final ride = rides.first;
    return switch (ride.status) {
      RideStatus.accepted ||
      RideStatus.arriving ||
      RideStatus.started =>
        ride.id,
      _ => null,
    };
  }

  /// Capability seam: the scripted rider persona and pickup — seed data,
  /// zero logic (the demo always runs the one scripted route).
  @override
  Future<TripRiderContext?> tripRiderContext(String rideId) async => (
        name: DemoPersonas.rider.fullName,
        rating: DemoPersonas.rider.rating,
        pickupLabel: DemoPlaces.scriptedPickup.label,
        pickupEtaSeconds: DemoScript.fromSeed(DemoSeed.seed).etaTotalSeconds,
      );

  /// Heading-home filter — not a demo beat; set/clear are no-ops and the
  /// read always reports inactive (the live `{active: false}` shape).
  @override
  Future<void> setDestinationFilter({
    required double lat,
    required double lng,
  }) async {}

  @override
  Future<DestinationFilter> getDestinationFilter() async =>
      const DestinationFilter.inactive();

  @override
  Future<void> clearDestinationFilter() async {}

  // ── Compliance documents ─────────────────────────────────────────────────
  // The presigned two-step flow simulated wholly in memory: the slot is
  // shaped exactly like the live response (driver-scoped key prefix, 5-min
  // TTL, 10 MB cap), the bytes PUT is skipped (no storage in the demo), and
  // a confirm replaces the same-type document as pending_review — the live
  // contract, with the same VALIDATION_FAILED shapes on bad input.

  @override
  Future<DocumentUploadSlot> documentUploadUrl({
    required String documentType,
    required String contentType,
  }) async {
    _validateDocumentType(documentType);
    if (!DriverRepository.documentContentTypes.contains(contentType)) {
      throw const ApiException(
        statusCode: 400,
        message: 'unsupported file type (allowed: pdf, jpg, png)',
        code: 'VALIDATION_FAILED',
      );
    }
    _uploadKeyCounter++;
    final key =
        'driver-docs/${DemoSeed.driverId}/$documentType/$_uploadKeyCounter';
    return (
      uploadUrl: 'https://demo-storage.hoppin.invalid/$key',
      key: key,
      contentType: contentType,
      urlExpiresAt: _world.virtualNow.add(const Duration(minutes: 5)),
      maxBytes: 10485760,
    );
  }

  @override
  Future<DriverDocument> confirmDocument({
    required String documentType,
    required String key,
    DateTime? expiresAt,
  }) async {
    _validateDocumentType(documentType);
    if (!key.startsWith('driver-docs/${DemoSeed.driverId}/$documentType/')) {
      throw const ApiException(
        statusCode: 400,
        message: 'invalid document type',
        code: 'VALIDATION_FAILED',
      );
    }
    _documentIdCounter++;
    final confirmed = DriverDocument(
      id: 'e3000000-0000-4000-8000-'
          '${_documentIdCounter.toRadixString(16).padLeft(12, '0')}',
      documentType: documentType,
      verificationStatus: 'pending_review',
      uploadedAt: _world.virtualNow,
      expiresAt: expiresAt,
    );
    _documents
      ..removeWhere((d) => d.documentType == documentType)
      ..insert(0, confirmed);
    return confirmed;
  }

  @override
  Future<List<DriverDocument>> documents() async =>
      List.unmodifiable(_documents);

  // ── Payouts ──────────────────────────────────────────────────────────────
  //
  // The demo driver starts CONNECTED BUT UNVERIFIED, deliberately. That is the
  // state a real driver spends the longest in and the one the UI most needs to
  // get right — "ready" would hide the distinction the screen exists to make.
  // Onboarding then completes in-session so the transition is demonstrable.
  bool _payoutsEnabled = false;

  @override
  Future<PayoutStatus> payoutStatus() async => PayoutStatus(
        connected: true,
        payoutsEnabled: _payoutsEnabled,
        accountID: 'acct_demo000000000001',
      );

  @override
  Future<PayoutOnboarding> startPayoutOnboarding() async {
    if (_payoutsEnabled) {
      return const PayoutOnboarding(
        accountID: 'acct_demo000000000001',
        alreadyEnabled: true,
      );
    }
    // No hosted URL: the demo must never send anyone to a real Stripe page.
    // The status flips instead, so the screen demonstrates the completed
    // transition without leaving the app.
    _payoutsEnabled = true;
    return const PayoutOnboarding(
      accountID: 'acct_demo000000000001',
      alreadyEnabled: true,
    );
  }

  void _validateDocumentType(String documentType) {
    if (!DriverRepository.documentTypes.contains(documentType)) {
      throw const ApiException(
        statusCode: 400,
        message: 'invalid document type',
        code: 'VALIDATION_FAILED',
      );
    }
  }
}
