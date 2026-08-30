import '../../../../core/money.dart';

class DriverStats {
  final double? averageRating;
  final int ratingCount;
  final int tripsCompleted;

  /// Only cancels the driver themselves made. Rider cancels, admin
  /// force-cancels and watchdog timeouts are excluded server-side, so this
  /// figure is one the driver is fairly accountable for.
  final int tripsCancelled;

  final int onlineMinutes;
  final int penaltiesCount;
  final Pence balance;
  final Pence totalEarnings;
  final Pence weekEarnings;
  final Pence monthEarnings;

  /// Null until there is anything to compute from.
  final double? acceptanceRate;
  final double? completionRate;

  const DriverStats({
    this.averageRating,
    this.ratingCount = 0,
    this.tripsCompleted = 0,
    this.tripsCancelled = 0,
    this.onlineMinutes = 0,
    this.penaltiesCount = 0,
    this.balance = const Pence(0),
    this.totalEarnings = const Pence(0),
    this.weekEarnings = const Pence(0),
    this.monthEarnings = const Pence(0),
    this.acceptanceRate,
    this.completionRate,
  });

  /// "94%", or an em dash when the rate is unknown. Rendering 0% for a
  /// driver who has simply had no offers would misrepresent them.
  String ratePercent(double? rate) =>
      rate == null ? '—' : '${(rate * 100).round()}%';

  String get onlineHours {
    final hours = onlineMinutes ~/ 60;
    final minutes = onlineMinutes % 60;
    return hours == 0 ? '${minutes}m' : '${hours}h ${minutes}m';
  }

  factory DriverStats.fromJson(Map<String, dynamic> json) {
    final earnings = (json['earnings'] as Map?) ?? const {};
    Pence pence(dynamic v) => Pence((v as num?)?.toInt() ?? 0);

    return DriverStats(
      averageRating: (json['average_rating'] as num?)?.toDouble(),
      ratingCount: (json['rating_count'] as num?)?.toInt() ?? 0,
      tripsCompleted: (json['trips_completed'] as num?)?.toInt() ?? 0,
      tripsCancelled: (json['trips_cancelled'] as num?)?.toInt() ?? 0,
      onlineMinutes: (json['online_minutes'] as num?)?.toInt() ?? 0,
      penaltiesCount: (json['penalties_count'] as num?)?.toInt() ?? 0,
      balance: pence(json['balance_pence']),
      totalEarnings: pence(earnings['total_pence']),
      weekEarnings: pence(earnings['this_week_pence']),
      monthEarnings: pence(earnings['this_month_pence']),
      acceptanceRate: (json['acceptance_rate'] as num?)?.toDouble(),
      completionRate: (json['completion_rate'] as num?)?.toDouble(),
    );
  }
}
