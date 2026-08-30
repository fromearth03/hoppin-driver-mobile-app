import 'dart:convert';

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
    _dio.interceptors
        .add(InterceptorsWrapper(onRequest: (options, handler) async {
      final token = await _tokens.read();
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
      handler.next(options);
    }));
  }

  Future<Result<T>> get<T>(String path, {Map<String, dynamic>? query}) =>
      _send<T>(() => _dio.get(path, queryParameters: query));

  Future<Result<T>> post<T>(String path,
          {Map<String, dynamic>? body, Map<String, dynamic>? query}) =>
      _send<T>(() => _dio.post(path, data: body, queryParameters: query));

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
