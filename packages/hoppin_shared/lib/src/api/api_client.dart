import 'dart:async';
import 'dart:convert';

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
///  * Claim this GoTrue session (`POST /me/session`) before other calls so
///    rider/driver accounts stay on one device.
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

    // Own Dio (same adapter, no interceptors) so claiming cannot re-enter
    // the 401 interceptor and deadlock Dio 5.
    _claimDio = Dio()
      ..options.baseUrl = _dio.options.baseUrl
      ..options.connectTimeout = _dio.options.connectTimeout
      ..options.receiveTimeout = _dio.options.receiveTimeout
      ..httpClientAdapter = _dio.httpClientAdapter;

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (!options.path.endsWith('/me/session')) {
            try {
              await _ensureSessionClaimed();
            } catch (_) {}
          }
          final token = _auth.accessToken;
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          final deviceID = _deviceHardwareId;
          if (deviceID != null) {
            options.headers['X-Hoppin-Device-ID'] = deviceID;
          }
          handler.next(options);
        },
        onError: _onError,
      ),
    );
  }

  final Dio _dio;
  late final Dio _claimDio;
  final AuthService _auth;
  String? _deviceHardwareId;

  /// Sets the per-install identity sent with subsequent authenticated calls.
  void setDeviceHardwareId(String deviceHardwareId) {
    final value = deviceHardwareId.trim();
    _deviceHardwareId = value.isEmpty ? null : value;
  }

  /// The single in-flight refresh. All 401s that arrive while a refresh is
  /// running await THIS future, so N concurrent 401s trigger exactly ONE
  /// `refreshSession()` — no refresh-token-reuse storm (docs/04 token handling).
  Completer<void>? _refreshing;

  Completer<void>? _claiming;
  String? _claimedSessionId;

  static const _retryFlag = '__retry';

  /// The self-healing bearer (AUTH-03).
  ///
  /// On a `401` that is not already a retry: refresh the Supabase session ONCE
  /// (concurrent 401s share the in-flight refresh), then re-issue the original
  /// request with the fresh bearer and resolve with its response. If the
  /// refresh fails, sign out (the router redirect handles re-login) and surface
  /// the original error. Every other error keeps the untouched reject path.
  ///
  /// `SESSION_REPLACED` means another device stole this login — sign out
  /// immediately, do NOT refresh (refresh keeps the dead session_id).
  Future<void> _onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final isRetry = err.requestOptions.extra[_retryFlag] == true;
    if (err.response?.statusCode != 401 || isRetry) {
      return handler.reject(_translate(err));
    }

    if (_responseCode(err) == 'SESSION_REPLACED') {
      await _auth.signOut();
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

  /// Marks this GoTrue session as the only live rider/driver login. No-op when
  /// the token has no `session_id` (tests / old GoTrue). Same session_id after
  /// refresh does not re-POST.
  Future<void> _ensureSessionClaimed() {
    final sid = _jwtSessionId();
    if (sid == null || sid.isEmpty) return Future<void>.value();
    if (_claimedSessionId == sid) return Future<void>.value();

    final existing = _claiming;
    if (existing != null) return existing.future;

    final completer = Completer<void>();
    _claiming = completer;
    final token = _auth.accessToken;
    _claimDio
        .post<Map<String, dynamic>>(
      '/me/session',
      options: Options(
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ),
    )
        .then(
      (_) {
        _claimedSessionId = sid;
        _claiming = null;
        completer.complete();
      },
      onError: (Object e, StackTrace s) {
        _claiming = null;
        if (e is DioException && _responseCode(e) == 'SESSION_REPLACED') {
          completer.completeError(e, s);
          return;
        }
        // Network / 5xx: fail-open so a blip does not block the app.
        completer.complete();
      },
    );
    return completer.future;
  }

  String? _jwtSessionId() {
    final token = _auth.accessToken;
    if (token == null) return null;
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map<String, dynamic>;
      final sid = payload['session_id'] ?? payload['sessionId'] ?? payload['sid'];
      return sid is String && sid.isNotEmpty ? sid : null;
    } catch (_) {
      return null;
    }
  }

  static String? _responseCode(DioException err) {
    final data = err.response?.data;
    if (data is Map) return data['code'] as String?;
    return null;
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
