import 'dart:async';

import 'package:dio/dio.dart';

import '../auth/auth_service.dart';
import '../config/env.dart';
import 'api_exception.dart';

/// The single HTTP entry point to the ride-service app API (`:8080`).
///
/// Responsibilities:
///  * Base URL = [Env.rideServiceUrl] (already includes `/api/v1`).
///  * Attach `Authorization: Bearer <supabase access token>` on every request
///    (docs/04: every endpoint requires it; there are no public routes).
///  * Normalise the `{ error, code }` failure envelope into [ApiException].
///
/// Feature repositories (rides, drivers, payments, ...) are built on top of
/// this — they never touch Dio or headers directly.
class ApiClient {
  ApiClient({required this._auth, Dio? dio}) : _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = Env.rideServiceUrl
      ..connectTimeout = const Duration(seconds: 10)
      ..receiveTimeout = const Duration(seconds: 20)
      ..headers['Content-Type'] = 'application/json';

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _auth.accessToken;
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: _onError,
      ),
    );
  }

  final Dio _dio;
  final AuthService _auth;

  /// The single in-flight refresh. All 401s that arrive while a refresh is
  /// running await THIS future, so N concurrent 401s trigger exactly ONE
  /// `refreshSession()` — no refresh-token-reuse storm (docs/04 token handling).
  Completer<void>? _refreshing;

  static const _retryFlag = '__retry';

  /// The self-healing bearer (AUTH-03).
  ///
  /// On a `401` that is not already a retry: refresh the Supabase session ONCE
  /// (concurrent 401s share the in-flight refresh), then re-issue the original
  /// request with the fresh bearer and resolve with its response. If the
  /// refresh fails, sign out (the router redirect handles re-login) and surface
  /// the original error. Every other error keeps the untouched reject path.
  Future<void> _onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final isRetry = err.requestOptions.extra[_retryFlag] == true;
    if (err.response?.statusCode != 401 || isRetry) {
      return handler.reject(_translate(err));
    }

    try {
      await _refresh();
    } on Object {
      // Refresh failed — send the rider back to login and surface the 401.
      await _auth.signOut();
      return handler.reject(_translate(err));
    }

    try {
      final retried = await _dio.fetch<dynamic>(
        err.requestOptions..extra[_retryFlag] = true,
      );
      return handler.resolve(retried);
    } on DioException catch (retryErr) {
      return handler.reject(_translate(retryErr));
    }
  }

  /// Shares one refresh across all concurrent 401s via a [Completer]. The
  /// completer is cleared the instant the refresh settles, so a LATER expiry
  /// (after this batch healed) still gets its own fresh refresh.
  Future<void> _refresh() {
    final existing = _refreshing;
    if (existing != null) return existing.future;

    final completer = Completer<void>();
    _refreshing = completer;
    _auth.refreshSession().then(
      (_) {
        _refreshing = null;
        completer.complete();
      },
      onError: (Object e, StackTrace s) {
        _refreshing = null;
        completer.completeError(e, s);
      },
    );
    return completer.future;
  }

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? query}) =>
      _run(() => _dio.get<T>(path, queryParameters: query));

  Future<Response<T>> post<T>(String path, {Object? body}) =>
      _run(() => _dio.post<T>(path, data: body));

  Future<Response<T>> put<T>(String path, {Object? body}) =>
      _run(() => _dio.put<T>(path, data: body));

  Future<Response<T>> patch<T>(String path, {Object? body}) =>
      _run(() => _dio.patch<T>(path, data: body));

  Future<Response<T>> delete<T>(String path) =>
      _run(() => _dio.delete<T>(path));

  /// Unwraps the [ApiException] planted by the error interceptor so callers
  /// (repositories → screens) catch a typed [ApiException], never a raw
  /// [DioException].
  Future<Response<T>> _run<T>(Future<Response<T>> Function() send) async {
    try {
      return await send();
    } on DioException catch (e) {
      final inner = e.error;
      if (inner is ApiException) throw inner;
      rethrow;
    }
  }

  /// Turn a Dio error into an [ApiException] carrying the backend's
  /// `{ error, code }`. On a bare `{ error }` (e.g. /rides/estimate) `code`
  /// stays null; on a transport failure we synthesise a 0 status.
  DioException _translate(DioException err) {
    final res = err.response;
    if (res != null) {
      final data = res.data;
      String message = 'Request failed';
      String? code;
      if (data is Map) {
        message = (data['error'] as String?) ?? message;
        code = data['code'] as String?;
      }
      return err.copyWith(
        error: ApiException(
          statusCode: res.statusCode ?? 0,
          message: message,
          code: code,
        ),
      );
    }
    return err.copyWith(
      error: ApiException(
        statusCode: 0,
        message: err.message ?? 'Network error',
        code: 'NETWORK_ERROR',
      ),
    );
  }
}
