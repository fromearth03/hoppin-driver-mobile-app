import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/result.dart';
import 'models/driver_stats.dart';
import 'models/penalty.dart';

class StatsRepository {
  final ApiClient _api;
  StatsRepository(this._api);

  Future<Result<DriverStats>> stats() async {
    final r = await _api.get<Map<String, dynamic>>('/drivers/me/stats');
    return r.when(
      ok: (json) => Ok(DriverStats.fromJson(json)),
      err: (e) => Err(e),
    );
  }

  Future<Result<PenaltyList>> penalties() async {
    final r = await _api.get<Map<String, dynamic>>('/drivers/me/penalties');
    return r.when(
      ok: (json) => Ok(PenaltyList.fromJson(json)),
      err: (e) => Err(e),
    );
  }
}

final statsRepositoryProvider = Provider<StatsRepository>(
    (ref) => StatsRepository(ref.watch(apiClientProvider)));
