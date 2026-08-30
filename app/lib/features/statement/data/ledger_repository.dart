import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/result.dart';
import 'models/ledger_entry.dart';

class LedgerRepository {
  final ApiClient _api;
  LedgerRepository(this._api);

  Future<Result<LedgerPage>> page({String? cursor, int limit = 50}) async {
    final r =
        await _api.get<Map<String, dynamic>>('/drivers/me/ledger', query: {
      'limit': limit,
      if (cursor != null) 'cursor': cursor,
    });
    return r.when(
      ok: (json) => Ok(LedgerPage.fromJson(json)),
      err: (e) => Err(e),
    );
  }

  Future<Result<Map<String, dynamic>>> summary(String period) =>
      _api.get<Map<String, dynamic>>('/drivers/me/ledger/summary',
          query: {'period': period});
}

final ledgerRepositoryProvider = Provider<LedgerRepository>(
    (ref) => LedgerRepository(ref.watch(apiClientProvider)));
