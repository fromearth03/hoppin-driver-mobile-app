import '../../../../core/money.dart';

enum TripFilter { all, completed, cancelled }

class DriverTrip {
  final String id;
  final String? ref;
  final DateTime? completedAt;
  final String status;
  final String pickupLabel;
  final String dropoffLabel;
  final double? distanceMiles;
  final Pence earnings;
  final Pence penalty;

  /// `driver` | `rider` | `admin` | `system`, null on a completed trip.
  final String? cancelledBy;

  /// Server-owned prose. Rendered verbatim when present.
  final String? cancelReason;

  const DriverTrip({
    required this.id,
    required this.status,
    required this.pickupLabel,
    required this.dropoffLabel,
    required this.earnings,
    required this.penalty,
    this.ref,
    this.completedAt,
    this.distanceMiles,
    this.cancelledBy,
    this.cancelReason,
  });

  bool get isCancelled => status == 'cancelled' || status == 'canceled';

  /// Who cancelled, in words. This is the first question a driver has about
  /// a cancelled trip — and `system` matters most, because a matching
  /// timeout is explicitly not their fault even though it appears in their
  /// history.
  String? get cancelledByLabel => switch (cancelledBy) {
        'driver' => 'You cancelled',
        'rider' => 'Cancelled by rider',
        'admin' => 'Cancelled by Hoppin',
        'system' => 'Cancelled automatically',
        _ => null,
      };

  factory DriverTrip.fromJson(Map<String, dynamic> json) => DriverTrip(
        id: json['id'] as String,
        ref: json['ref'] as String?,
        completedAt: json['completed_at'] == null
            ? null
            : DateTime.tryParse(json['completed_at'] as String),
        status: (json['status'] as String?) ?? '',
        pickupLabel: (json['pickup_label'] as String?) ?? '',
        dropoffLabel: (json['dropoff_label'] as String?) ?? '',
        distanceMiles: (json['distance_miles'] as num?)?.toDouble(),
        earnings: Pence((json['driver_earnings_pence'] as num?)?.toInt() ?? 0),
        penalty: Pence((json['penalty_pence'] as num?)?.toInt() ?? 0),
        cancelledBy: json['cancelled_by'] as String?,
        cancelReason: json['cancel_reason'] as String?,
      );
}

class TripsPage {
  final List<DriverTrip> trips;
  final String? nextCursor;
  final bool hasMore;

  const TripsPage({
    required this.trips,
    this.nextCursor,
    this.hasMore = false,
  });

  factory TripsPage.fromJson(Map<String, dynamic> json) => TripsPage(
        trips: ((json['trips'] as List?) ?? const [])
            .map(
                (e) => DriverTrip.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        nextCursor: json['next_cursor'] as String?,
        hasMore: json['has_more'] as bool? ?? false,
      );
}
