import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/result.dart';
import '../data/documents_repository.dart';
import '../data/models/driver_document.dart';

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

  /// The largest file the service accepts. Checked here so a driver who
  /// photographs a document at full resolution is told why before waiting
  /// out the upload of bytes the server will refuse.
  static const _maxBytes = 10 * 1024 * 1024;

  /// Post the bytes in one call and let the service store them.
  ///
  /// Previously this presigned a URL, PUT the bytes to object storage, then
  /// confirmed. The presigned host was only resolvable inside the server's
  /// Docker network, so the PUT could never connect from a real device.
  Future<Result<DriverDocument>> upload(
    String documentType,
    Uint8List bytes,
    String filename, {
    DateTime? expiresAt,
  }) async {
    final contentType = _contentType(filename);
    if (contentType == null) {
      return _fail(ApiException('VALIDATION_FAILED',
          'Only PDF, JPG and PNG files can be uploaded.', 0));
    }
    if (bytes.length > _maxBytes) {
      return _fail(ApiException('FILE_TOO_LARGE',
          'That file is over 10 MB. Try a smaller photo.', 0));
    }

    if (!_disposed) state = const UploadState(isUploading: true);

    final result = await ref.read(documentsRepositoryProvider).upload(
          documentType: documentType,
          bytes: bytes,
          filename: filename,
          contentType: contentType,
          expiresAt: expiresAt,
        );
    if (!_disposed) state = UploadState(error: result.errorOrNull);
    return result;
  }

  Result<DriverDocument> _fail(ApiException failure) {
    if (!_disposed) state = UploadState(error: failure);
    return Err(failure);
  }
}

final uploadControllerProvider =
    NotifierProvider<UploadController, UploadState>(UploadController.new);
