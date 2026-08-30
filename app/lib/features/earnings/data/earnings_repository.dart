import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/result.dart';
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
