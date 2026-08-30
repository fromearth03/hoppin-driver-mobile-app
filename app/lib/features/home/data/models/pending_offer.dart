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

  /// When this app received the offer — the countdown runs from here, not
  /// from an absolute server timestamp we would have to trust the clock for.
  final DateTime receivedAt;

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
  });

  factory PendingOffer.fromJson(Map<String, dynamic> json,
          {DateTime? receivedAt}) =>
      PendingOffer(
        id: json['id'] as String,
        rideId: (json['ride_id'] ?? json['rideId']) as String,
        // fare_pence is authoritative; the float `fare` is deprecated and
        // only read if the integer is somehow absent.
        fare: json['fare_pence'] != null
            ? Pence((json['fare_pence'] as num).toInt())
            : Pence.fromPounds(((json['fare'] as num?) ?? 0).toDouble()),
        pickupLabel: (json['pickup_label'] as String?) ?? '',
        dropoffLabel: (json['dropoff_label'] as String?) ?? '',
        rideCategory: json['ride_category'] as String?,
        estimatedDurationSeconds:
            (json['estimated_duration_seconds'] as num?)?.toInt(),
        pickupEtaSeconds: (json['pickup_eta_seconds'] as num?)?.toInt(),
        expiresInSec: (json['expires_in_sec'] as num?)?.toInt() ?? 60,
        receivedAt: receivedAt ?? DateTime.now(),
      );

  int get secondsRemaining {
    final elapsed = DateTime.now().difference(receivedAt).inSeconds;
    final left = expiresInSec - elapsed;
    return left < 0 ? 0 : left;
  }

  bool get hasExpired => secondsRemaining <= 0;

  @override
  String toString() => 'PendingOffer($id, ${fare.format()})';
}
