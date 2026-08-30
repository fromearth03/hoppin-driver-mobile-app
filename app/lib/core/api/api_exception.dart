/// A failed API call, keyed on the server's `code`. The `message` is the
/// server's `error` string — for logs only; user-facing copy comes from
/// `error_codes.dart`, never from here.
class ApiException implements Exception {
  final String code;
  final String message;
  final int statusCode;

  /// Extra top-level keys from the error body. `POST /drivers/me/online`
  /// adds `reason` and `blocking_document_types` on NOT_ELIGIBLE;
  /// `NO_SHOW_TOO_EARLY` adds `seconds`.
  final Map<String, dynamic> fields;

  ApiException(this.code, this.message, this.statusCode,
      {this.fields = const {}});

  /// Codes where the same request may succeed shortly, unchanged. Everything
  /// else needs the underlying state to change first, so retrying is noise.
  static const _retryable = {
    'INTERNAL',
    'STORAGE_DISABLED',
    'NO_DRIVER_ASSIGNED',
    'POSITION_UNAVAILABLE',
  };

  bool get isRetryable => _retryable.contains(code);

  @override
  String toString() => 'ApiException($code, $statusCode): $message';
}
