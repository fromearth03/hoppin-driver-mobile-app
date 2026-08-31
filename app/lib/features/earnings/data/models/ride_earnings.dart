import '../../../../core/money.dart';

/// Reads a `*_pence` field nullably: a money key the service renames or
/// omits must read as zero, never throw inside a parser.
Pence _p(Map<String, dynamic> json, String key) =>
    Pence((json[key] as num?)?.toInt() ?? 0);

class EarningsLine {
  final String label;
  final Pence amount;
  const EarningsLine(this.label, this.amount);
}

/// The per-trip breakdown from `GET /rides/:id/earnings`.
///
/// Nine fields come back, but settlement writes `tax_pence` and
/// `penalty_pence` as literal zero — VAT is not modelled and penalties are
/// separate ledger entries. Rendering "VAT £0.00" would assert a tax
/// treatment nobody has signed off, so [lines] omits any zero row. Net is
/// always shown, because a trip that earned nothing is still an answer.
class RideEarnings {
  final Pence base;
  final Pence distance;
  final Pence time;
  final Pence surge;
  final Pence waiting;
  final Pence commission;
  final Pence net;

  const RideEarnings({
    required this.base,
    required this.distance,
    required this.time,
    required this.surge,
    required this.waiting,
    required this.commission,
    required this.net,
  });

  factory RideEarnings.fromJson(Map<String, dynamic> json) => RideEarnings(
        base: _p(json, 'base_pence'),
        distance: _p(json, 'distance_pence'),
        time: _p(json, 'time_pence'),
        surge: _p(json, 'surge_pence'),
        waiting: _p(json, 'waiting_pence'),
        commission: _p(json, 'commission_pence'),
        net: _p(json, 'net_pence'),
      );

  List<EarningsLine> get lines => [
        if (!base.isZero) EarningsLine('Base fare', base),
        if (!distance.isZero) EarningsLine('Distance', distance),
        if (!time.isZero) EarningsLine('Time', time),
        if (!surge.isZero) EarningsLine('Surge', surge),
        if (!waiting.isZero) EarningsLine('Waiting', waiting),
        if (!commission.isZero) EarningsLine('Commission', commission),
        EarningsLine('Net', net),
      ];
}

class EarningsSummary {
  /// What the driver is actually paid for the period, after the platform's
  /// cut, tax and any penalties. This is the service's own figure — never
  /// re-derived from the parts, so the app can't disagree with the payout.
  final Pence net;
  final Pence gross;
  final Pence commission;
  final Pence tax;
  final Pence penalties;
  final int tripCount;

  /// The window the service actually summed, in its own words. The design
  /// prints a date range under each period card ("11 Aug - 17 Aug"); this
  /// is where that range comes from, rather than the app guessing at week
  /// boundaries the service computes in Europe/London.
  final DateTime? from;
  final DateTime? to;

  /// The service's own per-trip average. Not re-derived: `net / trips` in
  /// the app would round differently from the integer division the service
  /// does, and the two figures would disagree by a penny.
  final Pence avgNetPerTrip;

  const EarningsSummary({
    required this.net,
    this.gross = const Pence(0),
    this.commission = const Pence(0),
    this.tax = const Pence(0),
    this.penalties = const Pence(0),
    this.tripCount = 0,
    this.from,
    this.to,
    this.avgNetPerTrip = const Pence(0),
  });

  factory EarningsSummary.fromJson(Map<String, dynamic> json) =>
      EarningsSummary(
        net: _p(json, 'net_pence'),
        gross: _p(json, 'gross_pence'),
        commission: _p(json, 'commission_pence'),
        tax: _p(json, 'tax_pence'),
        penalties: _p(json, 'penalties_pence'),
        tripCount: (json['trips'] as num?)?.toInt() ?? 0,
        from: _date(json['from']),
        to: _date(json['to']),
        avgNetPerTrip: _p(json, 'avg_net_per_trip_pence'),
      );

  static DateTime? _date(Object? v) =>
      v is String ? DateTime.tryParse(v)?.toLocal() : null;

  /// The deductions between gross and net, in the order a payslip reads.
  /// Omits whatever didn't apply rather than showing a row of zeroes.
  List<EarningsLine> get deductions => [
        if (!commission.isZero) EarningsLine('Commission', commission),
        if (!tax.isZero) EarningsLine('Tax', tax),
        if (!penalties.isZero) EarningsLine('Penalties', penalties),
      ];
}
