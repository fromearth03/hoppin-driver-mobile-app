import '../../../../core/money.dart';

/// The waiting terms for one ride, from `GET /rides/:id/waiting-policy`.
///
/// `billableFrom` is the important field: it is the instant charging starts,
/// computed server-side. A bare count-up timer would leave the driver
/// guessing when the free period ends.
class WaitingPolicy {
  final DateTime? arrivedAt;
  final int freeWaitSeconds;
  final Pence perMinutePence;
  final int? noShowAfterSeconds;
  final Pence noShowFeePence;
  final DateTime? billableFrom;
  final String currency;

  const WaitingPolicy({
    required this.freeWaitSeconds,
    required this.perMinutePence,
    required this.noShowFeePence,
    this.arrivedAt,
    this.noShowAfterSeconds,
    this.billableFrom,
    this.currency = 'GBP',
  });

  factory WaitingPolicy.fromJson(Map<String, dynamic> json) => WaitingPolicy(
        arrivedAt: json['arrived_at'] == null
            ? null
            : DateTime.tryParse(json['arrived_at'] as String),
        freeWaitSeconds: (json['free_wait_seconds'] as num?)?.toInt() ?? 0,
        perMinutePence: Pence((json['per_minute_pence'] as num?)?.toInt() ?? 0),
        noShowAfterSeconds: (json['no_show_after_seconds'] as num?)?.toInt(),
        noShowFeePence: Pence((json['no_show_fee_pence'] as num?)?.toInt() ?? 0),
        billableFrom: json['billable_from'] == null
            ? null
            : DateTime.tryParse(json['billable_from'] as String),
        currency: (json['currency'] as String?) ?? 'GBP',
      );

  bool get isBillable =>
      billableFrom != null && DateTime.now().toUtc().isAfter(billableFrom!);

  /// Seconds of free waiting left, or 0 once charging has started.
  int get freeSecondsRemaining {
    if (billableFrom == null) return freeWaitSeconds;
    final left = billableFrom!.difference(DateTime.now().toUtc()).inSeconds;
    return left < 0 ? 0 : left;
  }
}
