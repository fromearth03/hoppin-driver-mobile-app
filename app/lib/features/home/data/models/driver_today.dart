import '../../../../core/money.dart';

/// The driver's day so far, from `GET /drivers/me/today`.
///
/// "Today" is the Europe/London local day, resolved server-side — the app
/// never derives the boundary itself, so a driver working past midnight in
/// BST sees the same day the server bills.
class DriverToday {
  final bool online;
  final Pence earnings;
  final int tripCount;
  final Duration onlineTime;

  /// Set while a trip is in progress. A driver who force-quits mid-job is
  /// otherwise stranded: the trip screen is reachable only from the offer
  /// they already accepted.
  final String? activeRideId;

  const DriverToday({
    this.online = false,
    this.earnings = const Pence(0),
    this.tripCount = 0,
    this.onlineTime = Duration.zero,
    this.activeRideId,
  });

  bool get hasActiveRide => activeRideId != null;

  factory DriverToday.fromJson(Map<String, dynamic> json) => DriverToday(
        online: json['online'] as bool? ?? false,
        earnings: Pence((json['earnings_pence'] as num?)?.toInt() ?? 0),
        tripCount: (json['trip_count'] as num?)?.toInt() ?? 0,
        onlineTime:
            Duration(seconds: (json['online_seconds'] as num?)?.toInt() ?? 0),
        activeRideId: json['active_ride_id'] as String?,
      );

  /// `2h 15m`, or `45m` under the hour. Seconds are noise at this scale.
  String get onlineLabel {
    final hours = onlineTime.inHours;
    final minutes = onlineTime.inMinutes % 60;
    return hours == 0 ? '${minutes}m' : '${hours}h ${minutes}m';
  }
}
