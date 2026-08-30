import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/result.dart';
import 'models/driver_trip.dart';

class TripsRepository {
  final ApiClient _api;
  TripsRepository(this._api);

  /// Filtering is server-side: doing it in the client would fetch fifty rows
  /// and display twelve, and paging would then be meaningless.
  Future<Result<TripsPage>> page({
    TripFilter filter = TripFilter.all,
    String? cursor,
    String? cancelledBy,
    int limit = 50,
  }) async {
    final r = await _api.get<Map<String, dynamic>>('/drivers/me/trips', query: {
      'limit': limit,
      if (filter == TripFilter.completed) 'status': 'completed',
      if (filter == TripFilter.cancelled) 'status': 'cancelled',
      if (cursor != null) 'cursor': cursor,
      if (cancelledBy != null) 'cancelled_by': cancelledBy,
    });
    return r.when(
      ok: (json) => Ok(TripsPage.fromJson(json)),
      err: (e) => Err(e),
    );
  }
}

final tripsRepositoryProvider = Provider<TripsRepository>(
    (ref) => TripsRepository(ref.watch(apiClientProvider)));
