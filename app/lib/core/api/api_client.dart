import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_lost.dart';
import '../auth/token_store.dart';
import '../device/device_identity.dart';
import '../result.dart';
import 'api_exception.dart';

/// Every call to the ride service goes through here. Returns [Result] rather
/// than throwing, so callers handle failure where it happens.
class ApiClient {
  static const baseUrl = 'https://api.hoppin.tech/api/v1';

  final Dio _dio;
  final TokenStore _tokens;

  /// Raised when the account signs in somewhere else and this device loses
  /// the single live session. Optional so the client stays constructible in
  /// tests that care about nothing else.
  final void Function()? onSessionLost;

  ApiClient(this._dio, this._tokens, {this.onSessionLost}) {
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
        // The blacklist gate reads this on every call; requests without it
        // simply aren't gated, so it costs nothing and buys enforcement.
        if (DeviceIdentity.id.isNotEmpty) {
          options.headers['X-Hoppin-Device-ID'] = DeviceIdentity.id;
        }
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
      return Err(ApiException('INTERNAL', _describe(e), 0));
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
      final error = parseError(response);
      // Every call from here answers the same way, so the app has to say so
      // once rather than let each failure become its own snackbar.
      if (error.code == 'SESSION_REPLACED') onSessionLost?.call();
      return Err<T>(error);
    } on DioException catch (e) {
      // Timeouts and connection failures are transient; INTERNAL is
      // retryable, which is the honest classification for "no network".
      //
      // 🔴 KEEP THE CAUSE. `e.message` is frequently null on a connection
      // failure, and collapsing every DioException into "network error"
      // threw away the one fact needed to tell a dead radio from a DNS
      // failure from a rejected certificate — which left a driver on a
      // generic banner and nobody able to say why.
      return Err<T>(ApiException('INTERNAL', _describe(e), 0));
    }
  }

  /// A cause a human can act on, for a failure that never reached the API.
  ///
  /// The type is what matters: a timeout means the server was found and did
  /// not answer, a connection error means it was never reached at all, and a
  /// certificate failure means it was reached and refused. Those are three
  /// different problems and they were all reported identically.
  static String _describe(DioException e) {
    final detail = e.message ?? e.error?.toString() ?? '';
    final kind = switch (e.type) {
      DioExceptionType.connectionTimeout => 'connect timed out',
      DioExceptionType.sendTimeout => 'send timed out',
      DioExceptionType.receiveTimeout => 'server did not answer in time',
      DioExceptionType.badCertificate => 'certificate rejected',
      DioExceptionType.connectionError => 'could not reach the server',
      DioExceptionType.cancel => 'cancelled',
      DioExceptionType.badResponse => 'bad response',
      DioExceptionType.unknown => 'network error',
      _ => 'network error',
    };
    return detail.isEmpty ? kind : '$kind: $detail';
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
      return ApiException(_codeForStatus(status), '', status);
    }
    final map = Map<String, dynamic>.from(data);
    final extras = Map<String, dynamic>.from(map)
      ..remove('code')
      ..remove('error');
    return ApiException(
      (map['code'] as String?) ?? _codeForStatus(status),
      (map['error'] as String?) ?? '',
      status,
      fields: extras,
    );
  }

  /// The code to assume when the body did not carry one.
  ///
  /// 🔴 EVERY NON-500 USED TO BECOME `NOT_FOUND`. A 401 whose body was empty,
  /// truncated or HTML (a gateway, a proxy, a cold start) was therefore
  /// reported as "That record no longer exists" — an answer that is not only
  /// wrong but points the driver AWAY from the fix, which is to sign in
  /// again. The status line is the one thing we always have; a 401/403 says
  /// what it is regardless of what the body did or did not contain.
  static String _codeForStatus(int status) {
    if (status >= 500) return 'INTERNAL';
    if (status == 401) return 'AUTH_REQUIRED';
    if (status == 403) return 'FORBIDDEN';
    return 'NOT_FOUND';
  }
}

final dioProvider = Provider<Dio>((ref) => Dio());

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(
      ref.watch(dioProvider),
      ref.watch(tokenStoreProvider),
      // The client itself never navigates — it raises the fact, and the app
      // root decides what to show for it.
      onSessionLost: () => ref.read(sessionLostProvider.notifier).raise(),
    ));
