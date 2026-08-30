import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/earnings/data/models/wallet.dart';

/// One entry of `recent_bonuses` exactly as the service builds it
/// (repository.DriverBonusSummary). Amounts on this endpoint are float
/// pounds, not pence — it predates the integer convention.
Map<String, dynamic> liveBonus() => {
      'id': 'b1',
      'amount': 12.50,
      'title': 'Weekend surge bonus',
      'promo_code': 'WKND',
      'ride_id': 'r1',
      'granted_at': '2026-08-29T18:30:00Z',
    };

void main() {
  test('reads the title and grant time the service sends', () {
    final b = DriverBonus.fromJson(liveBonus());

    // The app read `label` and `awarded_at`. The service sends `title` and
    // `granted_at`, so every bonus rendered as the placeholder "Bonus" with
    // no date — the driver could not tell what they had been paid for.
    expect(b.label, 'Weekend surge bonus');
    expect(b.awardedAt, DateTime.utc(2026, 8, 29, 18, 30));
    expect(b.amount.pence, 1250);
  });

  test('a bonus with no title still names itself', () {
    final b = DriverBonus.fromJson({'id': 'b2', 'amount': 5.0, 'title': ''});

    // An empty title is not a usable label, so fall back rather than
    // rendering a blank row.
    expect(b.label, 'Bonus');
    expect(b.awardedAt, isNull);
  });

  test('the wallet reads its bonuses through the same shape', () {
    final w = Wallet.fromJson({
      'available_balance': 40.0,
      'pending_balance': 0.0,
      'currency': 'GBP',
      'recent_payouts': const [],
      'recent_bonuses': [liveBonus()],
    });

    expect(w.recentBonuses.single.label, 'Weekend surge bonus');
  });
}
