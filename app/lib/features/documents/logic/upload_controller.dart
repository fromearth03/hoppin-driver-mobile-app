import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/result.dart';
import '../data/documents_repository.dart';
import '../data/models/driver_document.dart';

/// PUTs bytes to a presigned URL. Separate from [ApiClient] because the
/// destination is object storage, not the ride service — no auth header, no
/// error envelope.
abstract class FileUploader {
  Future<Result<void>> put(String url, Uint8List bytes, String contentType);
}

class DioFileUploader implements FileUploader {
  final Dio _dio;
  DioFileUploader(this._dio);

  @override
  Future<Result<void>> put(
      String url, Uint8List bytes, String contentType) async {
    try {
      final response = await _dio.put<void>(
        url,
        data: Stream.fromIterable([bytes]),
        options: Options(
          headers: {
            Headers.contentTypeHeader: contentType,
            Headers.contentLengthHeader: bytes.length,
          },
          validateStatus: (_) => true,
        ),
      );
      final status = response.statusCode ?? 500;
      if (status >= 200 && status < 300) return const Ok(null);
      return Err(ApiException('INTERNAL', 'storage rejected the file', status));
    } on DioException catch (e) {
      return Err(ApiException('INTERNAL', e.message ?? 'upload failed', 0));
    }
  }
}

final fileUploaderProvider =
    Provider<FileUploader>((ref) => DioFileUploader(Dio()));

class UploadState {
  final bool isUploading;
  final ApiException? error;
  const UploadState({this.isUploading = false, this.error});
}

class UploadController extends Notifier<UploadState> {
  bool _disposed = false;

  @override
  UploadState build() {
    ref.onDispose(() => _disposed = true);
    return const UploadState();
  }

  static String _contentType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    return 'image/jpeg';
  }

  /// Presign, PUT, then confirm — strictly in that order.
  ///
  /// Confirming before the bytes have landed would mark the driver compliant
  /// with nothing in storage, so a failed PUT stops the sequence.
  Future<Result<DriverDocument>> upload(
    String documentType,
    Uint8List bytes,
    String filename, {
    DateTime? expiresAt,
  }) async {
    if (!_disposed) state = const UploadState(isUploading: true);
    final repo = ref.read(documentsRepositoryProvider);

    final presigned = await repo.uploadUrl(documentType);
    if (!presigned.isOk) {
      if (!_disposed) state = UploadState(error: presigned.errorOrNull);
      return Err(presigned.errorOrNull!);
    }

    final urls = presigned.valueOrNull!;
    // Read nullably: a hard cast on a key the server renamed or omitted
    // would throw inside this method and escape Result entirely, reaching
    // the driver as an unhandled async error rather than a failure the
    // documents screen can render.
    final uploadUrl = (urls['upload_url'] ?? urls['url']) as String?;
    final fileUrl = (urls['file_url'] ?? urls['bucket_file_url']) as String?;
    if (uploadUrl == null || fileUrl == null) {
      final failure =
          ApiException('INTERNAL', 'upload destination missing', 0);
      state = UploadState(error: failure);
      return Err(failure);
    }

    final put = await ref
        .read(fileUploaderProvider)
        .put(uploadUrl, bytes, _contentType(filename));
    if (!put.isOk) {
      if (!_disposed) state = UploadState(error: put.errorOrNull);
      return Err(put.errorOrNull!);
    }

    final confirmed = await repo.confirm(
      documentType: documentType,
      fileUrl: fileUrl,
      expiresAt: expiresAt,
    );
    if (!_disposed) state = UploadState(error: confirmed.errorOrNull);
    return confirmed;
  }
}

final uploadControllerProvider =
    NotifierProvider<UploadController, UploadState>(UploadController.new);
