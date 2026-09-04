import 'dart:typed_data';

import 'package:dio/dio.dart';
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

  /// Post the bytes straight to the ride service, which stores them itself.
  ///
  /// This replaces the older presign → PUT → confirm sequence. That flow
  /// handed the client a URL on MinIO's internal Docker hostname, which no
  /// device outside the server can resolve, so every upload failed at the
  /// PUT. The service now takes the bytes and keeps object storage private.
  ///
  /// The filename matters: the service derives the stored extension from it
  /// when the multipart part carries no content type of its own.
  Future<Result<DriverDocument>> upload({
    required String documentType,
    required Uint8List bytes,
    required String filename,
    required String contentType,
    DateTime? expiresAt,
  }) async {
    final form = FormData.fromMap({
      'document_type': documentType,
      if (expiresAt != null)
        'expires_at': expiresAt.toUtc().toIso8601String(),
      'file': MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: DioMediaType.parse(contentType),
      ),
    });
    final r = await _api.postMultipart<Map<String, dynamic>>(
        '/drivers/me/documents/upload', form);
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
