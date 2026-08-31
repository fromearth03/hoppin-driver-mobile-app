import '../../../../core/money.dart';

/// The period figures behind `GET /drivers/me/ledger/summary`.
///
/// The four numbers are the only line-item breakdown the backend actually
/// publishes for a driver's account, so the design's itemised panel is bound
/// to these rather than to invented rows.
///
/// `debits` arrives already NEGATIVE — the handler sums `amount < 0` — so it
/// is stored as received and never re-signed here. Closing is the server's own
/// signed balance: negative means the driver owes.
class LedgerSummary {
  /// 'week' or 'month' — the only two the handler accepts.
  final String period;
  final Pence opening;
  final Pence credits;
  final Pence debits;
  final Pence closing;
  final String currency;

  const LedgerSummary({
    this.period = 'week',
    this.opening = const Pence(0),
    this.credits = const Pence(0),
    this.debits = const Pence(0),
    this.closing = const Pence(0),
    this.currency = 'GBP',
  });

  /// True when the driver is in debt at the close of the period.
  bool get owes => closing.isNegative;

  factory LedgerSummary.fromJson(Map<String, dynamic> json) => LedgerSummary(
        period: (json['period'] as String?) ?? 'week',
        opening: Pence((json['opening_pence'] as num?)?.toInt() ?? 0),
        credits: Pence((json['credits_pence'] as num?)?.toInt() ?? 0),
        debits: Pence((json['debits_pence'] as num?)?.toInt() ?? 0),
        closing: Pence((json['closing_pence'] as num?)?.toInt() ?? 0),
        currency: (json['currency'] as String?) ?? 'GBP',
      );
}
