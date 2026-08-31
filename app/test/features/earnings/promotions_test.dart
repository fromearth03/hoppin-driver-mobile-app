import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_client.dart';
import 'package:hoppin_driver/core/result.dart';
import 'package:hoppin_driver/features/earnings/data/earnings_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockApi extends Mock implements ApiClient {}

/// The endpoint returns the shared promo record — most of it describes the
/// rider's discount, and only driver_bonus_amount concerns the driver.
Map<String, dynamic> promo({
  String title = 'Weekend surge',
  double? driverBonus,
  String? expiresAt,
}) =>
    {
      'promo_code': 'WKND',
      'title': title,
      'description': 'Complete 5 trips this weekend',
      'discount_type': 'percentage',
      'discount_value': 10.0,
      'new_users_only': false,
      if (driverBonus != null) 'driver_bonus_amount': driverBonus,
      'expires_at': expiresAt,
    };

void main() {
  late MockApi api;
  late EarningsRepository repo;

  setUp(() {
    api = MockApi();
    repo = EarningsRepository(api);
  });

  void answer(List<Map<String, dynamic>> promos) {
    when(() => api.get<Map<String, dynamic>>(any()))
        .thenAnswer((_) async => Ok({'promotions': promos}));
  }

  test('reads the driver bonus, not the rider discount', () async {
    answer([promo(driverBonus: 12.5, expiresAt: '2026-09-07T23:59:59Z')]);

    final list = (await repo.promotions()).valueOrNull!;

    expect(list.single.title, 'Weekend surge');
    expect(list.single.bonus!.pence, 1250);
    expect(list.single.expiresAt, DateTime.utc(2026, 9, 7, 23, 59, 59));
  });

  test('hides a campaign that pays the driver nothing', () async {
    // A rider-discount promo listed under the driver's earnings would
    // promise money that is never coming.
    answer([promo(), promo(driverBonus: 0)]);

    expect((await repo.promotions()).valueOrNull, isEmpty);
  });

  test('no campaigns reads as an empty list, not an error', () async {
    answer([]);

    final result = await repo.promotions();

    expect(result.isOk, isTrue);
    expect(result.valueOrNull, isEmpty);
  });
}
