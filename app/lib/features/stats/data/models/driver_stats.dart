/// The window `/drivers/me/stats` was asked for.
///
/// The service accepts exactly these three and rejects anything else, so the
/// picker offers exactly these three — no arbitrary date range.
enum StatsPeriod {
  week('week', 'This Week'),
  month('month', 'This Month'),
  all('all', 'All Time');

  final String code;
  final String label;
  const StatsPeriod(this.code, this.label);

  static StatsPeriod fromCode(String? code) => switch (code) {
        'month' => StatsPeriod.month,
        'all' => StatsPeriod.all,
        _ => StatsPeriod.week,
      };
}

class DriverStats {
  /// Echoed back by the service, along with the window it resolved to. We
  /// render the server's own dates rather than computing a range locally —
  /// the service applies the driver's timezone and owns where a week starts.
  final StatsPeriod period;
  final DateTime? from;
  final DateTime? to;

  final double? averageRating;
  final int ratingCount;
  final int tripsCompleted;

  /// Only cancels the driver themselves made. Rider cancels, admin
  /// force-cancels and watchdog timeouts are excluded server-side, so this
  /// figure is one the driver is fairly accountable for.
  final int tripsCancelled;

  final int acceptedTrips;
  final int offersReceived;
  final int offersAccepted;
  final int offersDeclined;

  /// How many penalties are currently live against the account.
  final int penaltiesActive;

  /// Null until there is anything to compute from. The service omits the
  /// field entirely rather than sending 0 for an empty denominator.
  final double? acceptanceRate;
  final double? completionRate;
  final double? cancellationRate;

  const DriverStats({
    this.period = StatsPeriod.week,
    this.from,
    this.to,
    this.averageRating,
    this.ratingCount = 0,
    this.tripsCompleted = 0,
    this.tripsCancelled = 0,
    this.acceptedTrips = 0,
    this.offersReceived = 0,
    this.offersAccepted = 0,
    this.offersDeclined = 0,
    this.penaltiesActive = 0,
    this.acceptanceRate,
    this.completionRate,
    this.cancellationRate,
  });

  /// "94%", or an em dash when the rate is unknown. Rendering 0% for a
  /// driver who has simply had no offers would misrepresent them.
  String ratePercent(double? rate) =>
      rate == null ? '—' : '${(rate * 100).round()}%';

  factory DriverStats.fromJson(Map<String, dynamic> json) {
    DateTime? at(String key) {
      final raw = json[key];
      return raw is String ? DateTime.tryParse(raw) : null;
    }

    int count(String key) => (json[key] as num?)?.toInt() ?? 0;

    return DriverStats(
      period: StatsPeriod.fromCode(json['period'] as String?),
      from: at('from'),
      to: at('to'),
      // The service calls it `rating`. `average_rating` is the key
      // `/drivers/me/today` uses for the same figure, read as a fallback so
      // either payload parses rather than silently showing an em dash.
      averageRating: (json['rating'] as num?)?.toDouble() ??
          (json['average_rating'] as num?)?.toDouble(),
      ratingCount: count('rating_count'),
      tripsCompleted: count('trips_completed'),
      tripsCancelled: count('trips_cancelled'),
      acceptedTrips: count('accepted_trips'),
      offersReceived: count('offers_received'),
      offersAccepted: count('offers_accepted'),
      offersDeclined: count('offers_declined'),
      penaltiesActive: count('penalties_active'),
      acceptanceRate: (json['acceptance_rate'] as num?)?.toDouble(),
      completionRate: (json['completion_rate'] as num?)?.toDouble(),
      cancellationRate: (json['cancellation_rate'] as num?)?.toDouble(),
    );
  }
}
