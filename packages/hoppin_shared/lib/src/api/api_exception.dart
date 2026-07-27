/// A typed error from the ride-service.
///
/// Every failure from `:8080` is `{ "error": "<message>", "code": "<CODE>" }`
/// at a 4xx/5xx status (docs/04 · Global conventions). Show [message] to the
/// user; branch on [code] for logic (e.g. `PROMO_BUDGET_EXHAUSTED`,
/// `ACTIVE_TRIP_EXISTS`, `AUTH_REQUIRED`).
class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.message,
    this.code,
  });

  /// HTTP status (401, 403, 409, 422, 500, ...).
  final int statusCode;

  /// Human-readable message from the `error` field — safe to display.
  final String message;

  /// Machine code from the `code` field — branch on this. May be null on the
  /// few endpoints that return a bare `{ error }` (e.g. /rides/estimate).
  final String? code;

  /// 401 AUTH_REQUIRED — token bad/absent/expired. Refresh + retry, else re-login.
  bool get isAuth => statusCode == 401;

  /// 403 FORBIDDEN — wrong role, not your resource, or not eligible.
  bool get isForbidden => statusCode == 403;

  @override
  String toString() => 'ApiException($statusCode, $code): $message';
}
