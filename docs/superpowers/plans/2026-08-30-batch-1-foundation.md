# Driver App — Batch 1: Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up the Flutter project with a working API client, error mapping, money type, theme and navigation shell — everything later batches build on, and nothing feature-specific.

**Architecture:** Feature-first folders. `core/` holds what no feature owns: the Dio client with an auth interceptor, the driver-reachable error-code map, a `Pence` value type, `Result<T>`, and theme tokens. Riverpod provides dependency injection and state. A nav shell wires four bottom tabs plus a side drawer with no screens behind them yet.

**Tech Stack:** Flutter (Dart 3.12), Riverpod 2.x, Dio 5.x, `flutter_secure_storage`, `go_router`, `mocktail` + `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-08-30-driver-app-phase1-design.md`

## Global Constraints

- **Base URL:** `https://api.hoppin.tech`, all routes under `/api/v1`.
- **Money is never a `double`.** Integer `Pence` only; format at render. `/drivers/me/wallet` returns `float64` — convert at the repository boundary.
- **Error envelope:** `{"error": "...", "code": "..."}`. Map on `code`; `error` is for logs, never displayed.
- **Nullable rates render "—", never "0%".**
- **Light mode only**, but colours are tokens (`AppColors.surface`) — never inline hex.
- **Models mirror Go structs exactly.** A field absent from the API is absent from the Dart model.
- **Server-owned copy** (`display_title`, `display_reason`, `review_note`, `cancel_reason`) renders verbatim, never synthesised.
- **Android FCM channel id must be exactly `ride_alerts`** (`IMPORTANCE_HIGH`).
- Package name: `tech.hoppin.driver`. Project name: `hoppin_driver`.

---

### Task 1: Project scaffold and dependencies

**Files:**
- Create: `pubspec.yaml`, `analysis_options.yaml`, `lib/main.dart`, `lib/app.dart`
- Create: `.gitignore`

**Interfaces:**
- Consumes: nothing
- Produces: a runnable Flutter app; `ProviderScope` at the root; `HoppinDriverApp` widget.

- [ ] **Step 1: Create the Flutter project**

Run from `C:/Users/Hp/c2o/Hoppin/New-driver-app`:

```bash
flutter create --org tech.hoppin --project-name hoppin_driver \
  --platforms=android,ios,web app
```

This creates `app/`. All subsequent paths in every batch are relative to `New-driver-app/app/`.

- [ ] **Step 2: Add dependencies**

Replace the `dependencies` and `dev_dependencies` blocks in `app/pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.5.1
  dio: ^5.4.0
  go_router: ^14.2.0
  flutter_secure_storage: ^9.0.0
  intl: ^0.19.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
  mocktail: ^1.0.3
```

Run: `cd app && flutter pub get`

- [ ] **Step 3: Verify it builds**

Run: `cd app && flutter analyze`
Expected: "No issues found!"

- [ ] **Step 4: Commit**

```bash
git add app/
git commit -m "chore: scaffold Flutter driver app with core dependencies"
```

---

### Task 2: The `Pence` money type

**Files:**
- Create: `app/lib/core/money.dart`
- Test: `app/test/core/money_test.dart`

**Interfaces:**
- Consumes: nothing
- Produces: `Pence` — `Pence(int)`, `Pence.fromPounds(double)`, `.pence` (int), `.format()` → `"£8.30"`, `.formatSigned()` → `"−£50.00"`, `.isNegative`, `.isZero`, `+`, `-`, `==`. Used by every money-rendering task in later batches.

- [ ] **Step 1: Write the failing test**

Create `app/test/core/money_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/money.dart';

void main() {
  group('Pence', () {
    test('formats whole and part pounds', () {
      expect(const Pence(830).format(), '£8.30');
      expect(const Pence(2000).format(), '£20.00');
      expect(const Pence(5).format(), '£0.05');
      expect(const Pence(0).format(), '£0.00');
    });

    test('formats negatives with a real minus sign, not a hyphen', () {
      expect(const Pence(-5000).format(), '−£50.00');
    });

    test('formatSigned marks positives explicitly', () {
      expect(const Pence(830).formatSigned(), '+£8.30');
      expect(const Pence(-300).formatSigned(), '−£3.00');
      expect(const Pence(0).formatSigned(), '£0.00');
    });

    test('fromPounds converts the wallet float without drift', () {
      expect(Pence.fromPounds(8.30).pence, 830);
      expect(Pence.fromPounds(0.1 + 0.2).pence, 30);
      expect(Pence.fromPounds(-50.0).pence, -5000);
    });

    test('arithmetic stays integer', () {
      expect((const Pence(830) + const Pence(170)).pence, 1000);
      expect((const Pence(830) - const Pence(1000)).pence, -170);
    });

    test('exposes sign predicates', () {
      expect(const Pence(-1).isNegative, isTrue);
      expect(const Pence(0).isNegative, isFalse);
      expect(const Pence(0).isZero, isTrue);
    });

    test('equality is by value', () {
      expect(const Pence(830), const Pence(830));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/core/money_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:hoppin_driver/core/money.dart'`

- [ ] **Step 3: Write the implementation**

Create `app/lib/core/money.dart`:

```dart
/// Integer pence. The backend sends `*_pence` as int64 everywhere except
/// `/drivers/me/wallet`, which predates the convention and sends float
/// pounds — use [Pence.fromPounds] at that boundary and nowhere else.
///
/// Money never travels as a double inside the app.
class Pence {
  final int pence;
  const Pence(this.pence);

  /// Converts float pounds to integer pence, rounding half away from zero.
  /// Rounding (not truncation) is what keeps 0.1 + 0.2 from becoming 29p.
  factory Pence.fromPounds(double pounds) => Pence((pounds * 100).round());

  bool get isNegative => pence < 0;
  bool get isZero => pence == 0;

  /// "£8.30", or "−£50.00" when negative. Uses U+2212 MINUS SIGN rather
  /// than a hyphen so a debt reads as a number, not a list dash.
  String format() {
    final abs = pence.abs();
    final body = '£${(abs ~/ 100)}.${(abs % 100).toString().padLeft(2, '0')}';
    return pence < 0 ? '−$body' : body;
  }

  /// Same, but positives carry an explicit '+'. For ledger and trip rows
  /// where the direction of the movement is the point.
  String formatSigned() {
    if (pence == 0) return format();
    return pence > 0 ? '+${format()}' : format();
  }

  Pence operator +(Pence other) => Pence(pence + other.pence);
  Pence operator -(Pence other) => Pence(pence - other.pence);

  @override
  bool operator ==(Object other) => other is Pence && other.pence == pence;

  @override
  int get hashCode => pence.hashCode;

  @override
  String toString() => 'Pence($pence)';
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/core/money_test.dart`
Expected: PASS, 7 tests

- [ ] **Step 5: Commit**

```bash
git add app/lib/core/money.dart app/test/core/money_test.dart
git commit -m "feat: add Pence integer money type"
```

---

### Task 3: `Result<T>` and `ApiException`

**Files:**
- Create: `app/lib/core/result.dart`
- Create: `app/lib/core/api/api_exception.dart`
- Test: `app/test/core/result_test.dart`

**Interfaces:**
- Consumes: nothing
- Produces: `Result<T>` sealed class with `Ok<T>(T value)` and `Err<T>(ApiException error)`; `.isOk`, `.valueOrNull`, `.errorOrNull`, `.when(ok:, err:)`. `ApiException(code, message, statusCode, {fields})` with `.isRetryable`. Every repository in later batches returns `Result<T>`.

- [ ] **Step 1: Write the failing test**

Create `app/test/core/result_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_exception.dart';
import 'package:hoppin_driver/core/result.dart';

void main() {
  group('Result', () {
    test('Ok carries a value', () {
      const r = Ok<int>(42);
      expect(r.isOk, isTrue);
      expect(r.valueOrNull, 42);
      expect(r.errorOrNull, isNull);
    });

    test('Err carries an ApiException', () {
      final r = Err<int>(ApiException('OFFER_EXPIRED', 'gone', 409));
      expect(r.isOk, isFalse);
      expect(r.valueOrNull, isNull);
      expect(r.errorOrNull!.code, 'OFFER_EXPIRED');
    });

    test('when branches on the variant', () {
      const ok = Ok<int>(1);
      final err = Err<int>(ApiException('INTERNAL', 'boom', 500));
      expect(ok.when(ok: (v) => 'v$v', err: (e) => 'e${e.code}'), 'v1');
      expect(err.when(ok: (v) => 'v$v', err: (e) => 'e${e.code}'), 'eINTERNAL');
    });
  });

  group('ApiException', () {
    test('marks transient codes retryable', () {
      expect(ApiException('INTERNAL', '', 500).isRetryable, isTrue);
      expect(ApiException('STORAGE_DISABLED', '', 503).isRetryable, isTrue);
      expect(ApiException('POSITION_UNAVAILABLE', '', 409).isRetryable, isTrue);
      expect(ApiException('NO_DRIVER_ASSIGNED', '', 409).isRetryable, isTrue);
    });

    test('marks state-dependent codes not retryable', () {
      expect(ApiException('OFFER_EXPIRED', '', 409).isRetryable, isFalse);
      expect(ApiException('ACCOUNT_SUSPENDED', '', 403).isRetryable, isFalse);
      expect(ApiException('VALIDATION_FAILED', '', 400).isRetryable, isFalse);
    });

    test('carries extra fields such as NOT_ELIGIBLE reason', () {
      final e = ApiException('NOT_ELIGIBLE', 'blocked', 403, fields: {
        'reason': 'DOCS_EXPIRED',
        'blocking_document_types': ['vehicle_insurance'],
      });
      expect(e.fields['reason'], 'DOCS_EXPIRED');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/core/result_test.dart`
Expected: FAIL — URIs don't exist

- [ ] **Step 3: Write `ApiException`**

Create `app/lib/core/api/api_exception.dart`:

```dart
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

  ApiException(this.code, this.message, this.statusCode, {this.fields = const {}});

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
```

- [ ] **Step 4: Write `Result`**

Create `app/lib/core/result.dart`:

```dart
import 'api/api_exception.dart';

/// The return type of every repository method. Forces callers to handle
/// failure at the point of use rather than by catching somewhere distant.
sealed class Result<T> {
  const Result();

  bool get isOk => this is Ok<T>;
  T? get valueOrNull => this is Ok<T> ? (this as Ok<T>).value : null;
  ApiException? get errorOrNull =>
      this is Err<T> ? (this as Err<T>).error : null;

  R when<R>({
    required R Function(T value) ok,
    required R Function(ApiException error) err,
  }) =>
      this is Ok<T>
          ? ok((this as Ok<T>).value)
          : err((this as Err<T>).error);
}

class Ok<T> extends Result<T> {
  final T value;
  const Ok(this.value);
}

class Err<T> extends Result<T> {
  final ApiException error;
  const Err(this.error);
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd app && flutter test test/core/result_test.dart`
Expected: PASS, 6 tests

- [ ] **Step 6: Commit**

```bash
git add app/lib/core/result.dart app/lib/core/api/api_exception.dart app/test/core/result_test.dart
git commit -m "feat: add Result type and ApiException with retryability"
```

---

### Task 4: The driver-reachable error-code map

**Files:**
- Create: `app/lib/core/api/error_codes.dart`
- Test: `app/test/core/error_codes_test.dart`

**Interfaces:**
- Consumes: `ApiException` from Task 3
- Produces: `errorCopy(ApiException) → String` and `notEligibleCopy(String reason) → NotEligibleCopy(title, body, action)`. Used by every screen that surfaces a failure.

- [ ] **Step 1: Write the failing test**

Create `app/test/core/error_codes_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_exception.dart';
import 'package:hoppin_driver/core/api/error_codes.dart';

void main() {
  group('errorCopy', () {
    test('maps known driver-reachable codes', () {
      expect(errorCopy(ApiException('OFFER_EXPIRED', '', 409)),
          'This offer has lapsed.');
      expect(errorCopy(ApiException('ACCOUNT_SUSPENDED', '', 403)),
          'Your account is suspended. Please contact support.');
      expect(errorCopy(ApiException('ILLEGAL_TRANSITION', '', 409)),
          "This ride isn't in a state that allows that. Refreshing now.");
    });

    test('falls back generically for an unlisted code', () {
      expect(errorCopy(ApiException('SOME_NEW_CODE', 'raw server text', 500)),
          'Something went wrong. Please try again.');
    });

    test('never surfaces the raw server message', () {
      final copy = errorCopy(ApiException('WHATEVER', 'sql: no rows', 500));
      expect(copy.contains('sql'), isFalse);
    });

    test('NO_SHOW_TOO_EARLY reports the remaining wait', () {
      final e = ApiException('NO_SHOW_TOO_EARLY', '', 400, fields: {'seconds': 120});
      expect(errorCopy(e), 'You can report a no-show in 2 min.');
    });
  });

  group('notEligibleCopy', () {
    test('gives each blocked reason its own title, body and action', () {
      final docs = notEligibleCopy('DOCS_EXPIRED');
      expect(docs.title, 'Document expired');
      expect(docs.action, BlockedAction.openDocuments);

      final review = notEligibleCopy('DOCS_PENDING_REVIEW');
      expect(review.action, BlockedAction.none);

      final susp = notEligibleCopy('SUSPENDED');
      expect(susp.action, BlockedAction.contactSupport);

      final vehicle = notEligibleCopy('NO_VEHICLE');
      expect(vehicle.action, BlockedAction.registerVehicle);
    });

    test('covers all eleven tokens', () {
      const tokens = [
        'SUSPENDED', 'RESTRICTED', 'DELETION_REQUESTED',
        'DOCS_MISSING', 'DOCS_PENDING_REVIEW', 'DOCS_REJECTED', 'DOCS_EXPIRED',
        'NO_VEHICLE', 'DEVICE_BLACKLISTED', 'PAYOUT_NOT_READY', 'UNKNOWN',
      ];
      for (final t in tokens) {
        expect(notEligibleCopy(t).title, isNotEmpty, reason: 'missing copy for $t');
      }
    });

    test('an unrecognised token degrades to the UNKNOWN copy', () {
      expect(notEligibleCopy('SOMETHING_ELSE').title,
          notEligibleCopy('UNKNOWN').title);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/core/error_codes_test.dart`
Expected: FAIL — `error_codes.dart` does not exist

- [ ] **Step 3: Write the implementation**

Create `app/lib/core/api/error_codes.dart`:

```dart
import 'api_exception.dart';

/// What a blocked-from-online row offers the driver to do about it.
enum BlockedAction { openDocuments, registerVehicle, contactSupport, none }

class NotEligibleCopy {
  final String title;
  final String body;
  final BlockedAction action;
  const NotEligibleCopy(this.title, this.body, this.action);
}

/// The ~22 codes a driver JWT can actually reach, per the backend's
/// error-code reference. Rider-only codes are deliberately absent — writing
/// copy for codes we cannot hit invites the wrong message being shown.
const _copy = <String, String>{
  // Global
  'VALIDATION_FAILED': 'Please check the details and try again.',
  'INTERNAL': 'Something went wrong on our side. Trying again…',
  'FORBIDDEN': "You don't have access to that.",
  'NOT_FOUND': 'That record no longer exists.',
  'RIDE_NOT_FOUND': 'That ride no longer exists.',
  'ACCOUNT_SUSPENDED': 'Your account is suspended. Please contact support.',
  'ACCOUNT_BANNED': 'Your account is banned. Please contact support.',
  'DEVICE_BLACKLISTED': 'This device has been blocked. Please contact support.',
  // Going online
  'NOT_ELIGIBLE': "You're not cleared to go online yet.",
  'PAYOUT_NOT_READY': 'Payment setup is incomplete. Please contact support.',
  // Offers
  'OFFER_EXPIRED': 'This offer has lapsed.',
  'OFFER_NOT_FOUND': 'This offer is no longer available.',
  // Trip lifecycle
  'ILLEGAL_TRANSITION': "This ride isn't in a state that allows that. Refreshing now.",
  // Live map
  'NO_DRIVER_ASSIGNED': 'No driver on this ride yet.',
  'RIDE_NOT_ACTIVE': "This ride isn't active.",
  'POSITION_UNAVAILABLE': 'Waiting for a live position…',
  // Profile / documents / account
  'STORAGE_DISABLED': 'Uploads are temporarily unavailable. Please try again shortly.',
  'PHONE_TAKEN': 'That phone number is already in use.',
  'USER_NOT_FOUND': "We couldn't find your profile.",
  'DELETION_BLOCKED': "Your account can't be deleted yet.",
};

/// User-facing copy for a failure. Never returns the server's `error`
/// string — that is log material and can carry internals.
String errorCopy(ApiException e) {
  if (e.code == 'NO_SHOW_TOO_EARLY') {
    final seconds = (e.fields['seconds'] as num?)?.round() ?? 0;
    final minutes = (seconds / 60).ceil();
    return 'You can report a no-show in $minutes min.';
  }
  return _copy[e.code] ?? 'Something went wrong. Please try again.';
}

const _blocked = <String, NotEligibleCopy>{
  'SUSPENDED': NotEligibleCopy('Account suspended',
      'Your account is suspended.', BlockedAction.contactSupport),
  'RESTRICTED': NotEligibleCopy('Account restricted',
      'Your account has been restricted.', BlockedAction.contactSupport),
  'DELETION_REQUESTED': NotEligibleCopy('Deletion pending',
      'Your account is scheduled for deletion.', BlockedAction.contactSupport),
  'DOCS_MISSING': NotEligibleCopy('Document needed',
      "This hasn't been uploaded yet.", BlockedAction.openDocuments),
  'DOCS_PENDING_REVIEW': NotEligibleCopy('Under review',
      "We're checking this — nothing for you to do.", BlockedAction.none),
  'DOCS_REJECTED': NotEligibleCopy('Document not accepted',
      'This needs uploading again.', BlockedAction.openDocuments),
  'DOCS_EXPIRED': NotEligibleCopy('Document expired',
      'This needs renewing.', BlockedAction.openDocuments),
  'NO_VEHICLE': NotEligibleCopy('No vehicle registered',
      'Add your vehicle to start driving.', BlockedAction.registerVehicle),
  'DEVICE_BLACKLISTED': NotEligibleCopy('Device blocked',
      'This device has been blocked.', BlockedAction.contactSupport),
  'PAYOUT_NOT_READY': NotEligibleCopy('Payment setup incomplete',
      'Your operator needs to finish setting up payments.',
      BlockedAction.contactSupport),
  'UNKNOWN': NotEligibleCopy("Can't go online right now",
      'Please contact support.', BlockedAction.contactSupport),
};

/// Copy for one `blocked_reason` / `NOT_ELIGIBLE.reason` token. The same
/// vocabulary serves `GET /drivers/me/status` and the online refusal, so
/// one map covers both paths.
NotEligibleCopy notEligibleCopy(String reason) =>
    _blocked[reason] ?? _blocked['UNKNOWN']!;
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/core/error_codes_test.dart`
Expected: PASS, 8 tests

- [ ] **Step 5: Commit**

```bash
git add app/lib/core/api/error_codes.dart app/test/core/error_codes_test.dart
git commit -m "feat: map driver-reachable error codes to user-facing copy"
```

---

### Task 5: `ApiClient` with auth interceptor and envelope parsing

**Files:**
- Create: `app/lib/core/api/api_client.dart`
- Create: `app/lib/core/auth/token_store.dart`
- Test: `app/test/core/api_client_test.dart`

**Interfaces:**
- Consumes: `ApiException` (Task 3), `Result` (Task 3)
- Produces:
  - `TokenStore` — `read()`, `write(String)`, `clear()`, backed by `flutter_secure_storage`.
  - `ApiClient(Dio dio, TokenStore tokens)` with `get/post/patch/delete<T>(path, {query, body}) → Result<T>`, `baseUrl` const, and a static `parseError(Response)`.
  - Riverpod providers `tokenStoreProvider`, `dioProvider`, `apiClientProvider`.

- [ ] **Step 1: Write the failing test**

Create `app/test/core/api_client_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_client.dart';
import 'package:hoppin_driver/core/auth/token_store.dart';
import 'package:mocktail/mocktail.dart';

class _FakeTokenStore implements TokenStore {
  String? token;
  _FakeTokenStore([this.token]);
  @override
  Future<void> clear() async => token = null;
  @override
  Future<String?> read() async => token;
  @override
  Future<void> write(String value) async => token = value;
}

class _MockAdapter extends Mock implements HttpClientAdapter {}

void main() {
  setUpAll(() {
    registerFallbackValue(RequestOptions(path: '/'));
  });

  ResponseBody _body(String json, int status) =>
      ResponseBody.fromString(json, status,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});

  late Dio dio;
  late _MockAdapter adapter;
  late ApiClient client;

  setUp(() {
    adapter = _MockAdapter();
    dio = Dio(BaseOptions(baseUrl: ApiClient.baseUrl))
      ..httpClientAdapter = adapter;
    client = ApiClient(dio, _FakeTokenStore('jwt-abc'));
  });

  test('returns Ok with the decoded body on 200', () async {
    when(() => adapter.fetch(any(), any(), any()))
        .thenAnswer((_) async => _body('{"presence":"online"}', 200));

    final r = await client.get<Map<String, dynamic>>('/drivers/me/status');

    expect(r.isOk, isTrue);
    expect(r.valueOrNull!['presence'], 'online');
  });

  test('attaches the bearer token', () async {
    when(() => adapter.fetch(any(), any(), any()))
        .thenAnswer((_) async => _body('{}', 200));

    await client.get<Map<String, dynamic>>('/drivers/me/status');

    final captured = verify(() => adapter.fetch(captureAny(), any(), any()))
        .captured.first as RequestOptions;
    expect(captured.headers['Authorization'], 'Bearer jwt-abc');
  });

  test('maps an error envelope to ApiException on the code', () async {
    when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async =>
        _body('{"code":"OFFER_EXPIRED","error":"offer lapsed"}', 409));

    final r = await client.post<Map<String, dynamic>>('/offers/x/accept');

    expect(r.isOk, isFalse);
    expect(r.errorOrNull!.code, 'OFFER_EXPIRED');
    expect(r.errorOrNull!.statusCode, 409);
  });

  test('keeps extra error fields such as NOT_ELIGIBLE reason', () async {
    when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async => _body(
        '{"code":"NOT_ELIGIBLE","error":"blocked","reason":"DOCS_EXPIRED",'
        '"blocking_document_types":["vehicle_insurance"]}',
        403));

    final r = await client.post<Map<String, dynamic>>('/drivers/me/online');

    expect(r.errorOrNull!.fields['reason'], 'DOCS_EXPIRED');
    expect(r.errorOrNull!.fields['blocking_document_types'],
        ['vehicle_insurance']);
  });

  test('maps a body-less failure to its status', () async {
    when(() => adapter.fetch(any(), any(), any()))
        .thenAnswer((_) async => _body('not json', 500));

    final r = await client.get<Map<String, dynamic>>('/drivers/me/status');

    expect(r.errorOrNull!.code, 'INTERNAL');
  });

  test('maps a connection failure to INTERNAL rather than throwing', () async {
    when(() => adapter.fetch(any(), any(), any())).thenThrow(
        DioException.connectionError(
            requestOptions: RequestOptions(path: '/x'), reason: 'offline'));

    final r = await client.get<Map<String, dynamic>>('/drivers/me/status');

    expect(r.isOk, isFalse);
    expect(r.errorOrNull!.isRetryable, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/core/api_client_test.dart`
Expected: FAIL — `api_client.dart` does not exist

- [ ] **Step 3: Write `TokenStore`**

Create `app/lib/core/auth/token_store.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The Supabase JWT, at rest. An interface so tests can substitute an
/// in-memory store without touching the platform keychain.
abstract class TokenStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> clear();
}

class SecureTokenStore implements TokenStore {
  static const _key = 'hoppin_driver_jwt';
  final FlutterSecureStorage _storage;

  SecureTokenStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String value) => _storage.write(key: _key, value: value);

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());
```

- [ ] **Step 4: Write `ApiClient`**

Create `app/lib/core/api/api_client.dart`:

```dart
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
    _dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) async {
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
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd app && flutter test test/core/api_client_test.dart`
Expected: PASS, 6 tests

- [ ] **Step 6: Commit**

```bash
git add app/lib/core/api/api_client.dart app/lib/core/auth/token_store.dart app/test/core/api_client_test.dart
git commit -m "feat: add ApiClient with auth interceptor and error envelope parsing"
```

---

### Task 6: Theme tokens

**Files:**
- Create: `app/lib/core/theme/colors.dart`
- Create: `app/lib/core/theme/typography.dart`
- Create: `app/lib/core/theme/app_theme.dart`
- Test: `app/test/core/theme_test.dart`

**Interfaces:**
- Consumes: nothing
- Produces: `AppColors` (static tokens), `AppText` (TextStyles), `appTheme()` → `ThemeData`. Every widget in later batches uses these, never a raw `Color(0x…)`.

- [ ] **Step 1: Write the failing test**

Create `app/test/core/theme_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/theme/app_theme.dart';
import 'package:hoppin_driver/core/theme/colors.dart';

void main() {
  test('theme is light and uses the brand primary', () {
    final theme = appTheme();
    expect(theme.brightness, Brightness.light);
    expect(theme.colorScheme.primary, AppColors.primary);
  });

  test('semantic tokens are distinct so states read differently', () {
    expect(AppColors.positive, isNot(AppColors.negative));
    expect(AppColors.warning, isNot(AppColors.negative));
  });

  test('scaffold background is the app surface, not pure white', () {
    expect(appTheme().scaffoldBackgroundColor, AppColors.background);
    expect(AppColors.background, isNot(const Color(0xFFFFFFFF)));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/core/theme_test.dart`
Expected: FAIL — theme files do not exist

- [ ] **Step 3: Write the colour tokens**

Create `app/lib/core/theme/colors.dart`:

```dart
import 'package:flutter/material.dart';

/// Palette derived from the Figma pack. Light mode is the only theme we
/// ship — drivers use this in a car, in daylight — but every colour is a
/// token so a future dark mode is this file, not twenty-five screens.
///
/// Never write a raw Color() in a widget.
class AppColors {
  AppColors._();

  static const primary = Color(0xFF2E0B78);       // deep indigo
  static const primaryDark = Color(0xFF1E0550);
  static const accent = Color(0xFFF07A21);        // orange, primary actions

  static const background = Color(0xFFF5F5F7);    // app ground
  static const surface = Color(0xFFFFFFFF);       // cards
  static const border = Color(0xFFE3E3E8);

  static const textPrimary = Color(0xFF1A1A2E);
  static const textSecondary = Color(0xFF6B6B7B);
  static const textDisabled = Color(0xFFA0A0B0);

  static const positive = Color(0xFF2BA84A);      // online, credits
  static const negative = Color(0xFFD64545);      // penalties, debits, blocked
  static const warning = Color(0xFFE8A33D);       // expiring, pending review
  static const info = Color(0xFF3D7FE8);
}
```

- [ ] **Step 4: Write typography and theme**

Create `app/lib/core/theme/typography.dart`:

```dart
import 'package:flutter/material.dart';
import 'colors.dart';

/// Type scale. Named by role rather than size so a screen asks for what a
/// piece of text *is*, not how big it happens to be.
class AppText {
  AppText._();

  static const display = TextStyle(
      fontSize: 34, fontWeight: FontWeight.w700, color: AppColors.textPrimary);
  static const title = TextStyle(
      fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.textPrimary);
  static const heading = TextStyle(
      fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary);
  static const body = TextStyle(
      fontSize: 15, fontWeight: FontWeight.w400, color: AppColors.textPrimary);
  static const bodySecondary = TextStyle(
      fontSize: 15, fontWeight: FontWeight.w400, color: AppColors.textSecondary);
  static const caption = TextStyle(
      fontSize: 13, fontWeight: FontWeight.w400, color: AppColors.textSecondary);
  static const money = TextStyle(
      fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary);
}
```

Create `app/lib/core/theme/app_theme.dart`:

```dart
import 'package:flutter/material.dart';
import 'colors.dart';
import 'typography.dart';

/// Light only, by product decision. See the spec, §2.4.
ThemeData appTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppColors.primary,
    secondary: AppColors.accent,
    surface: AppColors.surface,
    error: AppColors.negative,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: AppText.heading,
    ),
    cardTheme: CardTheme(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textTheme: const TextTheme(
      displayLarge: AppText.display,
      titleLarge: AppText.title,
      titleMedium: AppText.heading,
      bodyMedium: AppText.body,
      bodySmall: AppText.caption,
    ),
  );
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd app && flutter test test/core/theme_test.dart`
Expected: PASS, 3 tests

- [ ] **Step 6: Commit**

```bash
git add app/lib/core/theme/ app/test/core/theme_test.dart
git commit -m "feat: add light theme tokens and type scale"
```

---

### Task 7: Shared state widgets

**Files:**
- Create: `app/lib/shared/widgets/app_empty_state.dart`
- Create: `app/lib/shared/widgets/app_error_state.dart`
- Create: `app/lib/shared/widgets/app_loading.dart`
- Test: `app/test/shared/state_widgets_test.dart`

**Interfaces:**
- Consumes: `AppColors`, `AppText` (Task 6), `errorCopy` + `ApiException` (Tasks 3–4)
- Produces: `AppEmptyState(icon, title, {message})`, `AppErrorState(error, {onRetry})`, `AppLoading({label})`. Used by every list and detail screen in later batches.

- [ ] **Step 1: Write the failing test**

Create `app/test/shared/state_widgets_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_exception.dart';
import 'package:hoppin_driver/shared/widgets/app_empty_state.dart';
import 'package:hoppin_driver/shared/widgets/app_error_state.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('empty state shows its own title, not a generic one',
      (tester) async {
    await tester.pumpWidget(_wrap(const AppEmptyState(
        icon: Icons.receipt_long, title: 'No cancelled trips')));

    expect(find.text('No cancelled trips'), findsOneWidget);
  });

  testWidgets('error state shows mapped copy, never the raw server message',
      (tester) async {
    await tester.pumpWidget(_wrap(AppErrorState(
        error: ApiException('STORAGE_DISABLED', 'bucket offline: s3 500', 503))));

    expect(find.textContaining('temporarily unavailable'), findsOneWidget);
    expect(find.textContaining('s3'), findsNothing);
  });

  testWidgets('retry is offered only for retryable failures', (tester) async {
    await tester.pumpWidget(_wrap(AppErrorState(
        error: ApiException('INTERNAL', '', 500), onRetry: () {})));
    expect(find.text('Try again'), findsOneWidget);

    await tester.pumpWidget(_wrap(AppErrorState(
        error: ApiException('ACCOUNT_SUSPENDED', '', 403), onRetry: () {})));
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('retry fires the callback', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(_wrap(AppErrorState(
        error: ApiException('INTERNAL', '', 500), onRetry: () => tapped++)));

    await tester.tap(find.text('Try again'));
    expect(tapped, 1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/shared/state_widgets_test.dart`
Expected: FAIL — widget files do not exist

- [ ] **Step 3: Write the widgets**

Create `app/lib/shared/widgets/app_loading.dart`:

```dart
import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';

class AppLoading extends StatelessWidget {
  final String? label;
  const AppLoading({super.key, this.label});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            if (label != null) ...[
              const SizedBox(height: 12),
              Text(label!, style: AppText.caption),
            ],
          ],
        ),
      );
}
```

Create `app/lib/shared/widgets/app_empty_state.dart`:

```dart
import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';

/// An empty list says what is empty, in its own words. A shared "Nothing
/// here" reads as a bug; "No cancelled trips" reads as an answer.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
  });

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: AppColors.textDisabled),
              const SizedBox(height: 16),
              Text(title, style: AppText.heading, textAlign: TextAlign.center),
              if (message != null) ...[
                const SizedBox(height: 8),
                Text(message!,
                    style: AppText.bodySecondary, textAlign: TextAlign.center),
              ],
            ],
          ),
        ),
      );
}
```

Create `app/lib/shared/widgets/app_error_state.dart`:

```dart
import 'package:flutter/material.dart';
import '../../core/api/api_exception.dart';
import '../../core/api/error_codes.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';

/// Shows mapped copy for a failure. Retry appears only when retrying could
/// actually succeed — offering it for a suspended account teaches the driver
/// the button is a lie.
class AppErrorState extends StatelessWidget {
  final ApiException error;
  final VoidCallback? onRetry;

  const AppErrorState({super.key, required this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final canRetry = onRetry != null && error.isRetryable;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.negative),
            const SizedBox(height: 16),
            Text(errorCopy(error),
                style: AppText.body, textAlign: TextAlign.center),
            if (canRetry) ...[
              const SizedBox(height: 20),
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/shared/state_widgets_test.dart`
Expected: PASS, 4 tests

- [ ] **Step 5: Commit**

```bash
git add app/lib/shared/widgets/ app/test/shared/state_widgets_test.dart
git commit -m "feat: add shared loading, empty and error state widgets"
```

---

### Task 8: Navigation shell

**Files:**
- Create: `app/lib/shared/nav/app_shell.dart`
- Create: `app/lib/shared/nav/side_drawer.dart`
- Create: `app/lib/app_router.dart`
- Modify: `app/lib/app.dart`, `app/lib/main.dart`
- Test: `app/test/shared/app_shell_test.dart`

**Interfaces:**
- Consumes: `appTheme()` (Task 6)
- Produces: `AppShell` (4 bottom tabs + drawer), `appRouter` (`GoRouter`), route constants `Routes.home|earnings|documents|stats|trips|…`. Later batches replace each tab's placeholder body with the real screen.

- [ ] **Step 1: Write the failing test**

Create `app/test/shared/app_shell_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/shared/nav/app_shell.dart';

Widget _wrap() => const ProviderScope(
      child: MaterialApp(home: AppShell(child: Text('body'), currentIndex: 0)),
    );

void main() {
  testWidgets('shows exactly the four locked tabs in order', (tester) async {
    await tester.pumpWidget(_wrap());

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Earnings'), findsOneWidget);
    expect(find.text('Docs'), findsOneWidget);
    expect(find.text('Stats'), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(4));
  });

  testWidgets('Trips is not a bottom tab — it lives in the drawer',
      (tester) async {
    await tester.pumpWidget(_wrap());

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    final labels = bar.destinations
        .map((d) => (d as NavigationDestination).label)
        .toList();
    expect(labels.contains('Trips'), isFalse);
  });

  testWidgets('drawer lists Trips and the account destinations',
      (tester) async {
    await tester.pumpWidget(_wrap());
    tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
    await tester.pumpAndSettle();

    expect(find.text('Trips'), findsOneWidget);
    expect(find.text('Personal Information'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Help & Support'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/shared/app_shell_test.dart`
Expected: FAIL — `app_shell.dart` does not exist

- [ ] **Step 3: Write the route constants and drawer**

Create `app/lib/app_router.dart`:

```dart
/// Route paths, in one place so deep links and drawer entries cannot drift.
class Routes {
  Routes._();

  static const home = '/';
  static const earnings = '/earnings';
  static const documents = '/documents';
  static const stats = '/stats';

  // Drawer destinations
  static const trips = '/trips';
  static const statement = '/statement';
  static const personalInfo = '/profile';
  static const notifications = '/notifications';
  static const support = '/support';
  static const settings = '/settings';

  /// The four bottom-nav tabs, in order. Docs takes a slot because an
  /// expired document stops a driver earning; Trips is in the drawer.
  static const tabs = [home, earnings, documents, stats];
}
```

Create `app/lib/shared/nav/side_drawer.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app_router.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';

class SideDrawer extends StatelessWidget {
  const SideDrawer({super.key});

  @override
  Widget build(BuildContext context) => Drawer(
        backgroundColor: AppColors.surface,
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const SizedBox(height: 12),
              _item(context, Icons.person_outline, 'Personal Information',
                  Routes.personalInfo),
              _item(context, Icons.route_outlined, 'Trips', Routes.trips),
              _item(context, Icons.notifications_none, 'Notifications',
                  Routes.notifications),
              _item(context, Icons.help_outline, 'Help & Support',
                  Routes.support),
              _item(context, Icons.settings_outlined, 'Settings',
                  Routes.settings),
              const Divider(height: 32, color: AppColors.border),
              ListTile(
                leading: const Icon(Icons.logout, color: AppColors.negative),
                title: Text('Log out',
                    style: AppText.body.copyWith(color: AppColors.negative)),
                onTap: () {}, // wired in Batch 2
              ),
            ],
          ),
        ),
      );

  Widget _item(
          BuildContext context, IconData icon, String label, String route) =>
      ListTile(
        leading: Icon(icon, color: AppColors.textSecondary),
        title: Text(label, style: AppText.body),
        onTap: () {
          Navigator.of(context).pop();
          context.go(route);
        },
      );
}
```

- [ ] **Step 4: Write the shell**

Create `app/lib/shared/nav/app_shell.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app_router.dart';
import '../../core/theme/colors.dart';
import 'side_drawer.dart';

/// Bottom nav + drawer wrapper. The four tabs are locked: Home, Earnings,
/// Docs, Stats. Trips is a drawer destination, not a tab.
class AppShell extends StatelessWidget {
  final Widget child;
  final int currentIndex;

  const AppShell({super.key, required this.child, required this.currentIndex});

  @override
  Widget build(BuildContext context) => Scaffold(
        drawer: const SideDrawer(),
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: currentIndex,
          backgroundColor: AppColors.surface,
          indicatorColor: AppColors.primary.withValues(alpha: 0.12),
          onDestinationSelected: (i) => context.go(Routes.tabs[i]),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home'),
            NavigationDestination(
                icon: Icon(Icons.payments_outlined),
                selectedIcon: Icon(Icons.payments),
                label: 'Earnings'),
            NavigationDestination(
                icon: Icon(Icons.description_outlined),
                selectedIcon: Icon(Icons.description),
                label: 'Docs'),
            NavigationDestination(
                icon: Icon(Icons.bar_chart_outlined),
                selectedIcon: Icon(Icons.bar_chart),
                label: 'Stats'),
          ],
        ),
      );
}
```

- [ ] **Step 5: Wire the router into the app**

Replace `app/lib/app.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_router.dart';
import 'core/theme/app_theme.dart';
import 'shared/nav/app_shell.dart';

/// Placeholder bodies. Each is replaced by its real screen in a later batch.
Widget _placeholder(String name) =>
    Center(child: Text('$name — not built yet'));

final _router = GoRouter(
  initialLocation: Routes.home,
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(
        currentIndex: Routes.tabs.indexOf(state.uri.path).clamp(0, 3),
        child: child,
      ),
      routes: [
        GoRoute(path: Routes.home, builder: (_, __) => _placeholder('Home')),
        GoRoute(
            path: Routes.earnings,
            builder: (_, __) => _placeholder('Earnings')),
        GoRoute(
            path: Routes.documents,
            builder: (_, __) => _placeholder('Documents')),
        GoRoute(path: Routes.stats, builder: (_, __) => _placeholder('Stats')),
        GoRoute(path: Routes.trips, builder: (_, __) => _placeholder('Trips')),
        GoRoute(
            path: Routes.personalInfo,
            builder: (_, __) => _placeholder('Personal Information')),
        GoRoute(
            path: Routes.notifications,
            builder: (_, __) => _placeholder('Notifications')),
        GoRoute(
            path: Routes.support, builder: (_, __) => _placeholder('Support')),
        GoRoute(
            path: Routes.settings,
            builder: (_, __) => _placeholder('Settings')),
      ],
    ),
  ],
);

class HoppinDriverApp extends StatelessWidget {
  const HoppinDriverApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'Hoppin Driver',
        theme: appTheme(),
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
      );
}
```

Replace `app/lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  runApp(const ProviderScope(child: HoppinDriverApp()));
}
```

- [ ] **Step 6: Run the tests and the analyzer**

Run: `cd app && flutter test && flutter analyze`
Expected: all tests PASS (34 across the batch), analyzer reports no issues

- [ ] **Step 7: Commit**

```bash
git add app/lib/ app/test/
git commit -m "feat: add navigation shell with four tabs and side drawer"
```

---

### Task 9: Android FCM channel and manifest

**Files:**
- Modify: `app/android/app/src/main/AndroidManifest.xml`
- Create: `app/android/app/src/main/kotlin/tech/hoppin/driver/MainActivity.kt` (replace generated)

**Interfaces:**
- Consumes: nothing
- Produces: a notification channel with id exactly `ride_alerts`. Batch 3's FCM wiring depends on this existing.

- [ ] **Step 1: Add the channel to MainActivity**

Replace `app/android/app/src/main/kotlin/tech/hoppin/driver/MainActivity.kt`:

```kotlin
package tech.hoppin.driver

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createRideAlertsChannel()
    }

    // The backend targets this channel by name when sending a ride offer.
    // The id must stay exactly "ride_alerts" — a mismatch silently costs
    // heads-up delivery while backgrounded, which is when offers matter most.
    private fun createRideAlertsChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            "ride_alerts",
            "Ride offers",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "New ride offers and trip updates"
            enableVibration(true)
        }
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }
}
```

- [ ] **Step 2: Add permissions to the manifest**

In `app/android/app/src/main/AndroidManifest.xml`, add inside `<manifest>` above `<application>`:

```xml
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```

- [ ] **Step 3: Verify the Android build still configures**

Run: `cd app && flutter build apk --debug --target-platform android-arm64`
Expected: BUILD SUCCESSFUL

- [ ] **Step 4: Commit**

```bash
git add app/android/
git commit -m "feat: create ride_alerts notification channel and declare permissions"
```

---

## Batch 1 done when

- `flutter test` passes (34 tests) and `flutter analyze` is clean.
- `flutter run -d chrome` shows the shell: four tabs, a working drawer, placeholder bodies.
- No raw `Color(0x…)` outside `core/theme/colors.dart`; no `double` holding money anywhere.

**Next:** Batch 2 (Auth) replaces the shell's entry point with a real sign-in gate.
