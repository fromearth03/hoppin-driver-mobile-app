import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/result.dart';
import 'models/driver_status.dart';

class DriverStatusRepository {
  final ApiClient _api;
  DriverStatusRepository(this._api);

  Future<Result<DriverStatus>> status() async {
    final r = await _api.get<Map<String, dynamic>>('/drivers/me/status');
    return r.when(
      ok: (json) => Ok(DriverStatus.fromJson(json)),
      err: (e) => Err(e),
    );
  }

  /// A refusal arrives as 403 with `reason` + `blocking_document_types`;
  /// ApiException.fields carries both through untouched.
  Future<Result<DriverStatus>> goOnline() async {
    final r = await _api.post<Map<String, dynamic>>('/drivers/me/online');
    return r.when(
      ok: (json) => Ok(DriverStatus.fromJson(json)),
      err: (e) => Err(e),
    );
  }

  Future<Result<void>> goOffline() async {
    final r = await _api.post<dynamic>('/drivers/me/offline');
    return r.when(ok: (_) => const Ok(null), err: (e) => Err(e));
  }

  Future<Result<void>> updateLocation(double lat, double lng) async {
    final r = await _api
        .post<dynamic>('/drivers/me/location', body: {'lat': lat, 'lng': lng});
    return r.when(ok: (_) => const Ok(null), err: (e) => Err(e));
  }
}

final driverStatusRepositoryProvider = Provider<DriverStatusRepository>(
    (ref) => DriverStatusRepository(ref.watch(apiClientProvider)));
