import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/result.dart';

/// `POST /me/sos` — the platform's own alarm. The server derives
/// `triggered_by: driver` from the token; ride id and note are optional and
/// the dispatcher already holds the driver's last reported position, so an
/// alert with no coordinates is still actionable.
class SosRepository {
  final ApiClient _api;
  SosRepository(this._api);

  Future<Result<String>> raise({String? rideId, String? note}) async {
    final r = await _api.post<Map<String, dynamic>>('/me/sos', body: {
      if (rideId != null) 'ride_id': rideId,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
    return r.when(
      ok: (json) => Ok((json['id'] as String?) ?? ''),
      err: (e) => Err(e),
    );
  }
}

final sosRepositoryProvider =
    Provider<SosRepository>((ref) => SosRepository(ref.watch(apiClientProvider)));
