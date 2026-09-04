import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/result.dart';
import 'models/demand_cell.dart';

class HeatmapRepository {
  final ApiClient _api;
  HeatmapRepository(this._api);

  /// Recent pickup demand, optionally clipped to the visible map.
  ///
  /// [hours] is the look-back window. The service defaults to 2 and caps at
  /// 168; we ask for a day, because a two-hour window over a launch-sized
  /// city is routinely empty and an empty map reads as a broken one.
  ///
  /// [bbox] is `minLng,minLat,maxLng,maxLat`. Sending the viewport keeps the
  /// response to the cells that can actually be drawn.
  Future<Result<DemandHeatmap>> demand({
    int hours = 24,
    String? bbox,
  }) async {
    final r = await _api.get<Map<String, dynamic>>('/demand-heatmap', query: {
      'hours': hours,
      if (bbox != null) 'bbox': bbox,
    });
    return r.when(
      ok: (json) => Ok(DemandHeatmap.fromJson(json)),
      err: (e) => Err(e),
    );
  }
}

final heatmapRepositoryProvider = Provider<HeatmapRepository>(
    (ref) => HeatmapRepository(ref.watch(apiClientProvider)));
