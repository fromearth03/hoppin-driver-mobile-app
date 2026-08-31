import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/result.dart';
import 'models/driver_promotion.dart';
import 'models/ride_earnings.dart';
import 'models/wallet.dart';

class EarningsRepository {
  final ApiClient _api;
  EarningsRepository(this._api);

  Future<Result<Wallet>> wallet() async {
    final r = await _api.get<Map<String, dynamic>>('/drivers/me/wallet');
    return r.when(ok: (json) => Ok(Wallet.fromJson(json)), err: (e) => Err(e));
  }

  /// `period` is one of today | week | month | all.
  Future<Result<EarningsSummary>> summary(String period) async {
    final r = await _api.get<Map<String, dynamic>>(
        '/drivers/me/earnings/summary',
        query: {'period': period});
    return r.when(
      ok: (json) => Ok(EarningsSummary.fromJson(json)),
      err: (e) => Err(e),
    );
  }

  /// Live bonus campaigns. Only the ones that actually pay the driver: the
  /// endpoint returns the shared promo record, and a rider-discount campaign
  /// listed on a driver's earnings screen promises money that is not coming.
  Future<Result<List<DriverPromotion>>> promotions() async {
    final r = await _api.get<Map<String, dynamic>>('/drivers/me/promotions');
    return r.when(
      ok: (json) => Ok(((json['promotions'] as List?) ?? const [])
          .map((e) =>
              DriverPromotion.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((p) => p.paysDriver)
          .toList()),
      err: (e) => Err(e),
    );
  }

  Future<Result<RideEarnings>> rideEarnings(String rideId) async {
    final r = await _api.get<Map<String, dynamic>>('/rides/$rideId/earnings');
    return r.when(
      ok: (json) => Ok(RideEarnings.fromJson(json)),
      err: (e) => Err(e),
    );
  }
}

final earningsRepositoryProvider = Provider<EarningsRepository>(
    (ref) => EarningsRepository(ref.watch(apiClientProvider)));
