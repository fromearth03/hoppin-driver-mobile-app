import '../../../../core/money.dart';

/// A dispatch offer, exactly as `GET /drivers/me/offers` returns it.
///
/// There is deliberately no rider name, photo, rating or comment. The
/// payload does not carry them and the app must not ask: showing identity
/// before accept/decline turns every decline into a data point tied to a
/// protected characteristic. See spec section 6.1.
class PendingOffer {
  final String id;
  final String rideId;
  final Pence fare;
  final String pickupLabel;
  final String dropoffLabel;
  final String? rideCategory;
  final int? estimatedDurationSeconds;

  /// Trip length in miles, as `repository.PendingOffer.EstimatedMiles`. The
  /// design labels this "Distance". Null when the service sends 0 — a
  /// zero-length trip is not a real measurement, and "0.0 mi" beside a fare
  /// reads as a bug rather than as missing data.
  final double? estimatedMiles;

  /// Live OSRM ETA from the driver's position to the pickup. Null when the
  /// server has no position to compute from.
  final int? pickupEtaSeconds;

  /// Where the trip starts and ends, for the design's route-preview map.
  /// Null when the service sent (0,0) — the handler convention repo-wide is
  /// that a zero coordinate means absent, not a point off the Gulf of
  /// Guinea.
  final ({double lat, double lng})? pickup;
  final ({double lat, double lng})? dropoff;

  final int expiresInSec;

  /// When this app received the offer. The countdown runs from here when the
  /// server sends only a relative window.
  final DateTime receivedAt;

  /// Absolute expiry, which is what the service actually sends. Preferred
  /// over [expiresInSec] when present: a relative default would tell the
  /// driver they had longer than they do.
  final DateTime? expiresAt;

  const PendingOffer({
    required this.id,
    required this.rideId,
    required this.fare,
    required this.pickupLabel,
    required this.dropoffLabel,
    required this.expiresInSec,
    required this.receivedAt,
    this.rideCategory,
    this.estimatedDurationSeconds,
    this.estimatedMiles,
    this.pickupEtaSeconds,
    this.pickup,
    this.dropoff,
    this.expiresAt,
  });

  static ({double lat, double lng})? _point(
      Map<String, dynamic> json, String latKey, String lngKey) {
    final lat = (json[latKey] as num?)?.toDouble() ?? 0;
    final lng = (json[lngKey] as num?)?.toDouble() ?? 0;
    if (lat == 0 && lng == 0) return null;
    return (lat: lat, lng: lng);
  }

  factory PendingOffer.fromJson(Map<String, dynamic> json,
          {DateTime? receivedAt}) =>
      PendingOffer(
        // The service keys this `offer_id`; `id` is a fallback only. A hard
        // cast here threw on every offer the server sent, which meant no
        // offer could ever be displayed.
        id: (json['offer_id'] ?? json['id']) as String? ?? '',
        // Defaulted rather than cast: a missing ride_id would otherwise
        // throw inside the repository, escaping Result entirely and
        // surfacing as an unhandled async error instead of an Err.
        rideId: (json['ride_id'] ?? json['rideId']) as String? ?? '',
        // fare_pence is authoritative; the float `fare` is deprecated and
        // only read if the integer is somehow absent.
        fare: json['fare_pence'] != null
            ? Pence((json['fare_pence'] as num).toInt())
            : Pence.fromPounds(((json['fare'] as num?) ?? 0).toDouble()),
        pickupLabel: (json['pickup_label'] as String?) ?? '',
        dropoffLabel: (json['dropoff_label'] as String?) ?? '',
        // Empty string normalised to null so the badge is simply omitted
        // rather than crashing on category[0].
        rideCategory: (json['ride_category'] as String?)?.trim().isEmpty ?? true
            ? null
            : json['ride_category'] as String?,
        estimatedDurationSeconds:
            (json['estimated_duration_seconds'] as num?)?.toInt(),
        estimatedMiles: switch ((json['estimated_miles'] as num?)?.toDouble()) {
          null || 0 => null,
          final m => m,
        },
        pickupEtaSeconds: (json['pickup_eta_seconds'] as num?)?.toInt(),
        pickup: _point(json, 'pickup_lat', 'pickup_lng'),
        dropoff: _point(json, 'dropoff_lat', 'dropoff_lng'),
        expiresInSec: (json['expires_in_sec'] as num?)?.toInt() ?? 60,
        expiresAt: json['expires_at'] == null
            ? null
            : DateTime.tryParse(json['expires_at'] as String),
        receivedAt: receivedAt ?? DateTime.now(),
      );

  /// A copy with the address labels filled in — used when the service sends
  /// them blank (dispatch creates the ride from coordinates alone, and the
  /// backend only reverse-geocodes on the post-accept endpoints).
  PendingOffer withLabels({String? pickupLabel, String? dropoffLabel}) =>
      PendingOffer(
        id: id,
        rideId: rideId,
        fare: fare,
        pickupLabel: pickupLabel ?? this.pickupLabel,
        dropoffLabel: dropoffLabel ?? this.dropoffLabel,
        expiresInSec: expiresInSec,
        receivedAt: receivedAt,
        rideCategory: rideCategory,
        estimatedDurationSeconds: estimatedDurationSeconds,
        estimatedMiles: estimatedMiles,
        pickupEtaSeconds: pickupEtaSeconds,
        pickup: pickup,
        dropoff: dropoff,
        expiresAt: expiresAt,
      );

  int get secondsRemaining {
    final left = expiresAt != null
        ? expiresAt!.difference(DateTime.now().toUtc()).inSeconds
        : expiresInSec - DateTime.now().difference(receivedAt).inSeconds;
    return left < 0 ? 0 : left;
  }

  bool get hasExpired => secondsRemaining <= 0;

  @override
  String toString() => 'PendingOffer($id, ${fare.format()})';
}
