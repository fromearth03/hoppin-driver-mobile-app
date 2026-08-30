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

  /// The MIME types the service will presign for, keyed by extension. It
  /// rejects anything else, and derives the stored key's extension from the
  /// value we send — so guessing a default for an unknown extension would
  /// store a mislabelled object under a name that lies about its contents.
  static const _contentTypes = {
    'pdf': 'application/pdf',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
  };

  static String? _contentType(String filename) {
    final dot = filename.lastIndexOf('.');
    if (dot < 0) return null;
    return _contentTypes[filename.substring(dot + 1).toLowerCase()];
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
    final contentType = _contentType(filename);
    if (contentType == null) {
      final failure = ApiException('VALIDATION_FAILED',
          'Only PDF, JPG and PNG files can be uploaded.', 0);
      if (!_disposed) state = UploadState(error: failure);
      return Err(failure);
    }

    if (!_disposed) state = const UploadState(isUploading: true);
    final repo = ref.read(documentsRepositoryProvider);

    // The same content type goes to the presign, the PUT header and the
    // stored extension. Sending a different one on the PUT than the URL was
    // signed for makes storage reject the bytes.
    final presigned = await repo.uploadUrl(documentType, contentType);
    if (!presigned.isOk) {
      if (!_disposed) state = UploadState(error: presigned.errorOrNull);
      return Err(presigned.errorOrNull!);
    }

    final destination = presigned.valueOrNull!;
    // Read nullably: a hard cast on a key the server renamed or omitted
    // would throw inside this method and escape Result entirely, reaching
    // the driver as an unhandled async error rather than a failure the
    // documents screen can render.
    final uploadUrl = destination['upload_url'] as String?;
    final key = destination['key'] as String?;
    if (uploadUrl == null || key == null) {
      final failure =
          ApiException('INTERNAL', 'upload destination missing', 0);
      if (!_disposed) state = UploadState(error: failure);
      return Err(failure);
    }

    final put = await ref
        .read(fileUploaderProvider)
        .put(uploadUrl, bytes, contentType);
    if (!put.isOk) {
      if (!_disposed) state = UploadState(error: put.errorOrNull);
      return Err(put.errorOrNull!);
    }

    final confirmed = await repo.confirm(
      documentType: documentType,
      key: key,
      expiresAt: expiresAt,
    );
    if (!_disposed) state = UploadState(error: confirmed.errorOrNull);
    return confirmed;
  }
}

final uploadControllerProvider =
    NotifierProvider<UploadController, UploadState>(UploadController.new);
