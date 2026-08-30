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

  /// Live OSRM ETA from the driver's position to the pickup. Null when the
  /// server has no position to compute from.
  final int? pickupEtaSeconds;

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
    this.pickupEtaSeconds,
    this.expiresAt,
  });

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
        pickupEtaSeconds: (json['pickup_eta_seconds'] as num?)?.toInt(),
        expiresInSec: (json['expires_in_sec'] as num?)?.toInt() ?? 60,
        expiresAt: json['expires_at'] == null
            ? null
            : DateTime.tryParse(json['expires_at'] as String),
        receivedAt: receivedAt ?? DateTime.now(),
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
