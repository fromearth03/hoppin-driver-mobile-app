import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/result.dart';
import 'models/driver_status.dart';
import 'models/driver_today.dart';

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

  /// The day so far: earnings, trips, online time, and any ride still in
  /// progress.
  Future<Result<DriverToday>> today() async {
    final r = await _api.get<Map<String, dynamic>>('/drivers/me/today');
    return r.when(
      ok: (json) => Ok(DriverToday.fromJson(json)),
      err: (e) => Err(e),
    );
  }

  /// A refusal arrives as 403 with `reason` + `blocking_document_types`;
  /// ApiException.fields carries both through untouched.
  ///
  /// The success body is an acknowledgement — {"message","status"} with no
  /// `presence` key. It must NOT be parsed as a [DriverStatus]: the missing
  /// presence reads as offline, which painted the toggle off on the very
  /// call that turned the driver online. The caller re-reads /status.
  Future<Result<void>> goOnline() async {
    // post<dynamic>: the ack's shape is not ours to depend on — a typed
    // decode failing on a 204 would surface a successful go-online as an
    // error, the exact bug class this method was rewritten to remove.
    final r = await _api.post<dynamic>('/drivers/me/online');
    return r.when(ok: (_) => const Ok(null), err: (e) => Err(e));
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
