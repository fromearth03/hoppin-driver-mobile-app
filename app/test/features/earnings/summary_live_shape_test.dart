import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/earnings/data/models/ride_earnings.dart';

/// The summary the deployed service sends, field for field
/// (service.EarningsSummary in driver_earnings_service.go).
Map<String, dynamic> liveSummary() => {
      'period': 'week',
      'from': '2026-08-24T00:00:00Z',
      'to': '2026-08-30T23:59:59Z',
      'trips': 14,
      'gross_pence': 21050,
      'commission_pence': 4210,
      'tax_pence': 0,
      'penalties_pence': 500,
      'net_pence': 16340,
      'avg_net_per_trip_pence': 1167,
      'currency': 'GBP',
    };

void main() {
  test('reads the net and trip count the service actually sends', () {
    final s = EarningsSummary.fromJson(liveSummary());

    // The app read total_pence and trip_count — neither exists on the
    // response, so every driver saw exactly £0.00 and 0 trips no matter
    // how much they had earned.
    expect(s.net.pence, 16340);
    expect(s.tripCount, 14);
  });

  test('keeps the deductions that explain the net', () {
    final s = EarningsSummary.fromJson(liveSummary());

    expect(s.gross.pence, 21050);
    expect(s.commission.pence, 4210);
    expect(s.penalties.pence, 500);
    // Net is the service's own figure, never re-derived here: the two must
    // agree, and if they ever diverge the service is right.
    expect(s.gross.pence - s.commission.pence - s.tax.pence - s.penalties.pence,
        s.net.pence);
  });

  test('a driver with no trips reads zero, not a crash', () {
    final s = EarningsSummary.fromJson({
      'period': 'today',
      'trips': 0,
      'gross_pence': 0,
      'net_pence': 0,
      'currency': 'GBP',
    });

    expect(s.net.pence, 0);
    expect(s.tripCount, 0);
  });
}
