import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/result.dart';
import 'models/driver_document.dart';

class DocumentsRepository {
  final ApiClient _api;
  DocumentsRepository(this._api);

  Future<Result<List<DocumentType>>> types() async {
    final r = await _api.get<dynamic>('/document-types');
    return r.when(
      ok: (data) => Ok(_list(data, 'document_types')
          .map((e) => DocumentType.fromJson(e))
          .toList()),
      err: (e) => Err(e),
    );
  }

  Future<Result<List<DriverDocument>>> mine() async {
    final r = await _api.get<dynamic>('/drivers/me/documents');
    return r.when(
      ok: (data) => Ok(_list(data, 'documents')
          .map((e) => DriverDocument.fromJson(e))
          .toList()),
      err: (e) => Err(e),
    );
  }

  /// Every known type, paired with the driver's upload for it.
  Future<Result<List<DocumentSlot>>> slots() async {
    final typesResult = await types();
    if (!typesResult.isOk) return Err(typesResult.errorOrNull!);
    final mineResult = await mine();
    if (!mineResult.isOk) return Err(mineResult.errorOrNull!);

    final byType = {
      for (final d in mineResult.valueOrNull!) d.documentType: d,
    };
    return Ok(typesResult.valueOrNull!
        .map((t) => DocumentSlot(type: t, document: byType[t.code]))
        .toList());
  }

  /// Step one of the upload: ask for a presigned destination.
  ///
  /// [contentType] is not optional on the service — the handler rejects the
  /// request outright without it, and the extension of the storage key it
  /// mints is derived from it, so the PUT must send the same value back.
  Future<Result<Map<String, dynamic>>> uploadUrl(
          String documentType, String contentType) =>
      _api.post<Map<String, dynamic>>('/drivers/me/documents/upload-url',
          body: {
            'document_type': documentType,
            'content_type': contentType,
          });

  /// Step two: tell the server the file landed.
  ///
  /// [key] is the storage key from step one, echoed back verbatim. The service
  /// checks it starts with `driver-docs/{driver}/{type}/` so one driver can
  /// never confirm a document sitting under another's prefix; anything else,
  /// a bucket URL included, is refused.
  Future<Result<DriverDocument>> confirm({
    required String documentType,
    required String key,
    DateTime? expiresAt,
  }) async {
    final r =
        await _api.post<Map<String, dynamic>>('/drivers/me/documents', body: {
      'document_type': documentType,
      'key': key,
      if (expiresAt != null) 'expires_at': expiresAt.toUtc().toIso8601String(),
    });
    return r.when(
      ok: (json) => Ok(DriverDocument.fromJson(json)),
      err: (e) => Err(e),
    );
  }

  List<Map<String, dynamic>> _list(dynamic data, String key) {
    final raw = data is Map
        ? ((data[key] as List?) ?? const [])
        : (data as List? ?? const []);
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}

final documentsRepositoryProvider = Provider<DocumentsRepository>(
    (ref) => DocumentsRepository(ref.watch(apiClientProvider)));
