import '../../../../core/money.dart';

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

  static Pence _p(Map<String, dynamic> json, String key) =>
      Pence((json[key] as num?)?.toInt() ?? 0);

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
  final Pence total;
  final int tripCount;

  const EarningsSummary({required this.total, this.tripCount = 0});

  factory EarningsSummary.fromJson(Map<String, dynamic> json) =>
      EarningsSummary(
        total: Pence((json['total_pence'] as num?)?.toInt() ?? 0),
        tripCount: (json['trip_count'] as num?)?.toInt() ?? 0,
      );
}
