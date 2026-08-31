import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/result.dart';
import 'models/ledger_entry.dart';
import 'models/ledger_summary.dart';

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

  /// The period breakdown. `period` is only ever 'week' or 'month' — the
  /// handler falls back to 'week' for anything else, so the caller does not
  /// get to invent one.
  Future<Result<LedgerSummary>> summary(String period) async {
    final r = await _api.get<Map<String, dynamic>>('/drivers/me/ledger/summary',
        query: {'period': period});
    return r.when(
      ok: (json) => Ok(LedgerSummary.fromJson(json)),
      err: (e) => Err(e),
    );
  }
}

final ledgerRepositoryProvider = Provider<LedgerRepository>(
    (ref) => LedgerRepository(ref.watch(apiClientProvider)));
