import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/result.dart';
import 'models/appeal.dart';

class AppealsRepository {
  final ApiClient _api;
  AppealsRepository(this._api);

  Future<Result<List<Appeal>>> mine() async {
    final r = await _api.get<dynamic>('/drivers/me/compliance-appeals');
    return r.when(
      ok: (data) {
        final list = data is Map
            ? ((data['appeals'] as List?) ?? const [])
            : (data as List? ?? const []);
        return Ok(list
            .map((e) => Appeal.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList());
      },
      err: (e) => Err(e),
    );
  }

  Future<Result<Appeal>> file({
    String? documentType,
    required String reason,
  }) async {
    final r = await _api
        .post<Map<String, dynamic>>('/drivers/me/compliance-appeals', body: {
      'reason': reason,
      if (documentType != null) 'document_type': documentType,
    });
    return r.when(
      ok: (json) => Ok(Appeal.fromJson(json)),
      err: (e) => Err(e),
    );
  }
}

final appealsRepositoryProvider = Provider<AppealsRepository>(
    (ref) => AppealsRepository(ref.watch(apiClientProvider)));
