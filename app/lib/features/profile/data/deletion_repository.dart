import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/result.dart';

class DeletionRepository {
  final ApiClient _api;
  DeletionRepository(this._api);

  /// Irreversible. Returns 200 when the erasure ran, or 409
  /// `DELETION_BLOCKED` with a `blockers` array.
  Future<Result<void>> requestDeletion() async {
    final r = await _api.post<dynamic>('/me/delete-account');
    return r.when(ok: (_) => const Ok(null), err: (e) => Err(e));
  }
}

final deletionRepositoryProvider = Provider<DeletionRepository>(
    (ref) => DeletionRepository(ref.watch(apiClientProvider)));
