import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/token_store.dart';
import '../result.dart';
import 'api_exception.dart';

/// Every call to the ride service goes through here. Returns [Result] rather
/// than throwing, so callers handle failure where it happens.
class ApiClient {
  static const baseUrl = 'https://api.hoppin.tech/api/v1';

  final Dio _dio;
  final TokenStore _tokens;

  ApiClient(this._dio, this._tokens) {
    _dio.options.baseUrl = baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 15);
    _dio.options.receiveTimeout = const Duration(seconds: 20);
    // Let non-2xx through so the envelope can be parsed rather than thrown.
    _dio.options.validateStatus = (_) => true;
    final apiOrigin = Uri.parse(baseUrl).origin;
    _dio.interceptors
        .add(InterceptorsWrapper(onRequest: (options, handler) async {
      // The token goes only to our own API. getBytes takes absolute URLs
      // from server data (avatar_url is a DB string, and a move to a CDN
      // host is anticipated) — a bearer token must never follow a URL to
      // some other host.
      if (options.uri.origin == apiOrigin) {
        final token = await _tokens.read();
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    }));
  }

  Future<Result<T>> get<T>(String path, {Map<String, dynamic>? query}) =>
      _send<T>(() => _dio.get(path, queryParameters: query));

  Future<Result<T>> post<T>(String path,
          {Map<String, dynamic>? body, Map<String, dynamic>? query}) =>
      _send<T>(() => _dio.post(path, data: body, queryParameters: query));

  /// Multipart POST — the avatar endpoint takes the image as a form field
  /// rather than a JSON body, so a [FormData] goes through untouched.
  Future<Result<T>> postMultipart<T>(String path, FormData form) =>
      _send<T>(() => _dio.post(path, data: form));

  /// Fetches raw bytes with the auth header attached. Stored images live in
  /// a private bucket behind `/images/...`, which refuses an unauthenticated
  /// request — and neither `NetworkImage` nor a browser `<img>` can carry a
  /// Bearer token, so image bytes have to come through here. [url] may be
  /// absolute (the API returns full URLs for avatars).
  Future<Result<Uint8List>> getBytes(String url) async {
    try {
      final response = await _dio.get<dynamic>(url,
          options: Options(responseType: ResponseType.bytes));
      final status = response.statusCode ?? 500;
      final data = response.data;
      if (status >= 200 && status < 300 && data is List<int>) {
        // ResponseType.bytes already yields a Uint8List; the copy is only
        // for the defensive case where an adapter hands back a plain list.
        return Ok(data is Uint8List ? data : Uint8List.fromList(data));
      }
      return Err(parseError(response));
    } on DioException catch (e) {
      return Err(ApiException('INTERNAL', e.message ?? 'network error', 0));
    }
  }

  Future<Result<T>> patch<T>(String path, {Map<String, dynamic>? body}) =>
      _send<T>(() => _dio.patch(path, data: body));

  Future<Result<T>> delete<T>(String path, {Map<String, dynamic>? body}) =>
      _send<T>(() => _dio.delete(path, data: body));

  Future<Result<T>> _send<T>(Future<Response> Function() call) async {
    try {
      final response = await call();
      final status = response.statusCode ?? 500;
      if (status >= 200 && status < 300) {
        return Ok<T>(response.data as T);
      }
      return Err<T>(parseError(response));
    } on DioException catch (e) {
      // Timeouts and connection failures are transient; INTERNAL is
      // retryable, which is the honest classification for "no network".
      return Err<T>(ApiException('INTERNAL', e.message ?? 'network error', 0));
    }
  }

  /// Reads `{"error": ..., "code": ...}`, keeping any extra top-level keys
  /// (`reason`, `blocking_document_types`, `seconds`) that specific codes add.
  static ApiException parseError(Response response) {
    final status = response.statusCode ?? 500;
    dynamic data = response.data;
    if (data is String) {
      try {
        data = jsonDecode(data);
      } catch (_) {
        data = null;
      }
    }
    if (data is! Map) {
      return ApiException(status >= 500 ? 'INTERNAL' : 'NOT_FOUND', '', status);
    }
    final map = Map<String, dynamic>.from(data);
    final extras = Map<String, dynamic>.from(map)
      ..remove('code')
      ..remove('error');
    return ApiException(
      (map['code'] as String?) ?? (status >= 500 ? 'INTERNAL' : 'NOT_FOUND'),
      (map['error'] as String?) ?? '',
      status,
      fields: extras,
    );
  }
}

final dioProvider = Provider<Dio>((ref) => Dio());

final apiClientProvider = Provider<ApiClient>(
    (ref) => ApiClient(ref.watch(dioProvider), ref.watch(tokenStoreProvider)));
