import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/result.dart';
import 'models/cancel_reason.dart';

class CancelReasonRepository {
  final ApiClient _api;
  CancelReasonRepository(this._api);

  /// Only `pickable` reasons reach the picker.
  Future<Result<List<CancelReason>>> forDriver() async {
    final r = await _api
        .get<dynamic>('/cancellation-reasons', query: {'actor': 'driver'});
    return r.when(
      ok: (data) {
        final list = data is Map
            ? ((data['reasons'] as List?) ?? const [])
            : (data as List? ?? const []);
        return Ok(list
            .map((e) =>
                CancelReason.fromJson(Map<String, dynamic>.from(e as Map)))
            .where((r) => r.pickable)
            .toList());
      },
      err: (e) => Err(e),
    );
  }
}

final cancelReasonRepositoryProvider = Provider<CancelReasonRepository>(
    (ref) => CancelReasonRepository(ref.watch(apiClientProvider)));
