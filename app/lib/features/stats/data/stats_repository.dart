import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/result.dart';
import 'models/driver_stats.dart';
import 'models/penalty.dart';

class StatsRepository {
  final ApiClient _api;
  StatsRepository(this._api);

  /// [period] is one of the three windows the service accepts; anything
  /// else is rejected server-side, so the enum is the whole vocabulary.
  ///
  /// [timeZone] decides where a week and a month begin. The service defaults
  /// to Europe/London when it is omitted, which is right for this fleet, so
  /// we only send one when a caller has a better answer.
  Future<Result<DriverStats>> stats({
    StatsPeriod period = StatsPeriod.week,
    String? timeZone,
  }) async {
    final r = await _api.get<Map<String, dynamic>>(
      '/drivers/me/stats',
      query: {
        'period': period.code,
        if (timeZone != null) 'tz': timeZone,
      },
    );
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
