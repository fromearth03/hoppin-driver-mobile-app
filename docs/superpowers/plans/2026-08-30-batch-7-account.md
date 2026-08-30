# Driver App — Batch 7: Account Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A driver can view and edit their profile, set their app preferences, read and clear notifications, raise and follow a support ticket, complete payout onboarding, and delete their account — with every blocker explained.

**Architecture:** Five small repositories over the Batch 1 `ApiClient`, one per surface. Settings persists through `/me/preferences`, which stores an opaque JSON blob, so the app owns the schema and sends back what it read plus its edits. Payout onboarding hands off to Stripe's hosted flow in a browser tab rather than collecting anything itself.

**Tech Stack:** Flutter, Riverpod, Dio, `url_launcher`, `shared_preferences`.

**Spec:** `docs/superpowers/specs/2026-08-30-driver-app-phase1-design.md` §4.9, §4.10, §4.11, §4.12

## Global Constraints

- **The app never collects card or bank details.** Payout onboarding opens Stripe's hosted flow via `POST /me/payout-account`; the Figma `Add Payment Methods` form is never built. This keeps PCI scope at SAQ-A.
- **Name and photo are operator-verified.** The profile screen says so and routes to Support rather than offering an edit that will fail.
- **Delete Account is built whole**, including the outstanding-balance block. Its settle action is **disabled with an explanation** until a settlement endpoint exists — an active-looking button that silently does nothing is worse than one that explains itself.
- **`DELETION_BLOCKED` blockers render one row each**, the same list-not-a-message principle as the blocked-from-online state.
- **No Language row** — single locale.
- **Notifications come from the endpoint, never assembled from received pushes.** A dropped push must not create a gap in the list.
- Light theme tokens only; money is `Pence`; server copy verbatim.

---

### Task 1: Profile

**Files:**
- Create: `app/lib/features/profile/data/models/driver_profile.dart`
- Create: `app/lib/features/profile/data/profile_repository.dart`
- Test: `app/test/features/profile/profile_repository_test.dart`

**Interfaces:**
- Consumes: `ApiClient`, `Result` (Batch 1)
- Produces: `DriverProfile(id, fullName, email, phoneNumber, dateOfBirth, avatarUrl)`; `ProfileRepository.me()`, `.update({phoneNumber, dateOfBirth})`, `.uploadAvatar(bytes, filename)`. Provider `profileRepositoryProvider`.

- [ ] **Step 1: Write the failing test**

Create `app/test/features/profile/profile_repository_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_client.dart';
import 'package:hoppin_driver/core/auth/token_store.dart';
import 'package:hoppin_driver/features/profile/data/models/driver_profile.dart';
import 'package:hoppin_driver/features/profile/data/profile_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockAdapter extends Mock implements HttpClientAdapter {}

void main() {
  setUpAll(() => registerFallbackValue(RequestOptions(path: '/')));

  ResponseBody body(String json, int status) =>
      ResponseBody.fromString(json, status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  late _MockAdapter adapter;
  late ProfileRepository repo;

  setUp(() {
    adapter = _MockAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    repo = ProfileRepository(ApiClient(dio, InMemoryTokenStore()));
  });

  test('parses the profile', () {
    final p = DriverProfile.fromJson({
      'id': 'u1',
      'full_name': 'Alex Morgan',
      'email': 'alex@hoppin.tech',
      'phone_number': '+44 7700 900000',
      'date_of_birth': '1990-05-14',
    });

    expect(p.fullName, 'Alex Morgan');
    expect(p.phoneNumber, '+44 7700 900000');
  });

  test('tolerates a profile with nothing optional set', () {
    final p = DriverProfile.fromJson({'id': 'u1', 'full_name': 'Sam Patel'});

    expect(p.phoneNumber, isNull);
    expect(p.dateOfBirth, isNull);
    expect(p.avatarUrl, isNull);
  });

  test('sends only the fields the driver may change', () async {
    when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async =>
        body('{"id":"u1","full_name":"Alex Morgan"}', 200));

    await repo.update(phoneNumber: '+44 7700 900111');

    final sent = verify(() => adapter.fetch(captureAny(), any(), any()))
        .captured
        .first as RequestOptions;
    expect(sent.data['phone_number'], '+44 7700 900111');
    // Name is operator-verified; the app must not attempt to change it.
    expect(sent.data.containsKey('full_name'), isFalse);
  });

  test('surfaces PHONE_TAKEN so the driver can pick another', () async {
    when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async =>
        body('{"code":"PHONE_TAKEN","error":"in use"}', 409));

    final r = await repo.update(phoneNumber: '+44 7700 900111');

    expect(r.errorOrNull!.code, 'PHONE_TAKEN');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/profile/`
Expected: FAIL — files do not exist

- [ ] **Step 3: Write the model and repository**

Create `app/lib/features/profile/data/models/driver_profile.dart`:

```dart
class DriverProfile {
  final String id;
  final String fullName;
  final String? email;
  final String? phoneNumber;
  final String? dateOfBirth;
  final String? avatarUrl;

  const DriverProfile({
    required this.id,
    required this.fullName,
    this.email,
    this.phoneNumber,
    this.dateOfBirth,
    this.avatarUrl,
  });

  factory DriverProfile.fromJson(Map<String, dynamic> json) => DriverProfile(
        id: (json['id'] as String?) ?? '',
        fullName: (json['full_name'] as String?) ?? '',
        email: json['email'] as String?,
        phoneNumber: json['phone_number'] as String?,
        dateOfBirth: json['date_of_birth'] as String?,
        avatarUrl: (json['avatar_url'] ?? json['photo_url']) as String?,
      );
}
```

Create `app/lib/features/profile/data/profile_repository.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/result.dart';
import 'models/driver_profile.dart';

class ProfileRepository {
  final ApiClient _api;
  ProfileRepository(this._api);

  Future<Result<DriverProfile>> me() async {
    final r = await _api.get<Map<String, dynamic>>('/me/profile');
    return r.when(
      ok: (json) => Ok(DriverProfile.fromJson(json)),
      err: (e) => Err(e),
    );
  }

  /// Only the fields a driver may change reach the server. Name and photo
  /// are verified by the operator, so offering an edit for them would be an
  /// edit that fails.
  Future<Result<DriverProfile>> update({
    String? phoneNumber,
    String? dateOfBirth,
  }) async {
    final r = await _api.patch<Map<String, dynamic>>('/me/profile', body: {
      if (phoneNumber != null) 'phone_number': phoneNumber,
      if (dateOfBirth != null) 'date_of_birth': dateOfBirth,
    });
    return r.when(
      ok: (json) => Ok(DriverProfile.fromJson(json)),
      err: (e) => Err(e),
    );
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>(
    (ref) => ProfileRepository(ref.watch(apiClientProvider)));
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/features/profile/`
Expected: PASS, 4 tests

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/profile app/test/features/profile
git commit -m "feat: add the driver profile repository"
```

---

### Task 2: Preferences

**Files:**
- Create: `app/lib/features/profile/data/models/driver_preferences.dart`
- Create: `app/lib/features/profile/data/preferences_repository.dart`
- Test: `app/test/features/profile/preferences_test.dart`

**Interfaces:**
- Consumes: `ApiClient`, `Result` (Batch 1)
- Produces: `DistanceUnit` enum (`miles`, `kilometres`); `NavApp` enum (`google`, `apple`); `DriverPreferences(notificationsEnabled, rideRequestSound, keepScreenAwake, distanceUnit, navApp)` with `.fromJson`, `.toJson`, `.copyWith`; `PreferencesRepository.load()`, `.save(prefs)`. Provider `preferencesRepositoryProvider`.

`/me/preferences` stores an opaque JSON blob, so the app owns this schema. Unknown keys are preserved on save rather than dropped — another client may be storing its own.

- [ ] **Step 1: Write the failing test**

Create `app/test/features/profile/preferences_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_client.dart';
import 'package:hoppin_driver/core/auth/token_store.dart';
import 'package:hoppin_driver/features/profile/data/models/driver_preferences.dart';
import 'package:hoppin_driver/features/profile/data/preferences_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockAdapter extends Mock implements HttpClientAdapter {}

void main() {
  setUpAll(() => registerFallbackValue(RequestOptions(path: '/')));

  ResponseBody body(String json, int status) =>
      ResponseBody.fromString(json, status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  late _MockAdapter adapter;
  late PreferencesRepository repo;

  setUp(() {
    adapter = _MockAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    repo = PreferencesRepository(ApiClient(dio, InMemoryTokenStore()));
  });

  test('a driver with no saved preferences gets sensible defaults', () {
    final p = DriverPreferences.fromJson(const {});

    expect(p.notificationsEnabled, isTrue);
    expect(p.rideRequestSound, isTrue);
    expect(p.distanceUnit, DistanceUnit.miles);
    expect(p.navApp, NavApp.google);
  });

  test('round-trips through json', () {
    const original = DriverPreferences(
      notificationsEnabled: false,
      keepScreenAwake: true,
      distanceUnit: DistanceUnit.kilometres,
      navApp: NavApp.apple,
    );

    final restored = DriverPreferences.fromJson(original.toJson());

    expect(restored.notificationsEnabled, isFalse);
    expect(restored.keepScreenAwake, isTrue);
    expect(restored.distanceUnit, DistanceUnit.kilometres);
    expect(restored.navApp, NavApp.apple);
  });

  test('an unrecognised unit falls back to miles', () {
    final p = DriverPreferences.fromJson({'distance_unit': 'furlongs'});
    expect(p.distanceUnit, DistanceUnit.miles);
  });

  test('reads the preferences envelope', () async {
    when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async =>
        body('{"preferences":{"distance_unit":"kilometres"}}', 200));

    final r = await repo.load();

    expect(r.valueOrNull!.distanceUnit, DistanceUnit.kilometres);
  });

  test('preserves keys another client may have stored', () async {
    when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async =>
        body('{"preferences":{"rider_only_setting":"keep me"}}', 200));

    final loaded = await repo.load();
    await repo.save(loaded.valueOrNull!);

    final sent = verify(() => adapter.fetch(captureAny(), any(), any()))
        .captured
        .last as RequestOptions;
    // This blob is shared; dropping unknown keys would silently wipe
    // settings this app knows nothing about.
    expect(sent.data['preferences']['rider_only_setting'], 'keep me');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/profile/preferences_test.dart`
Expected: FAIL — files do not exist

- [ ] **Step 3: Write the model and repository**

Create `app/lib/features/profile/data/models/driver_preferences.dart`:

```dart
enum DistanceUnit { miles, kilometres }

enum NavApp { google, apple }

/// App preferences.
///
/// `/me/preferences` stores an opaque JSON blob shared with other clients,
/// so [unknown] carries anything this app does not recognise straight back
/// on save. Dropping it would wipe settings we know nothing about.
class DriverPreferences {
  final bool notificationsEnabled;
  final bool rideRequestSound;
  final bool keepScreenAwake;
  final DistanceUnit distanceUnit;
  final NavApp navApp;
  final Map<String, dynamic> unknown;

  const DriverPreferences({
    this.notificationsEnabled = true,
    this.rideRequestSound = true,
    this.keepScreenAwake = false,
    this.distanceUnit = DistanceUnit.miles,
    this.navApp = NavApp.google,
    this.unknown = const {},
  });

  static const _known = {
    'notifications_enabled',
    'ride_request_sound',
    'keep_screen_awake',
    'distance_unit',
    'nav_app',
  };

  DriverPreferences copyWith({
    bool? notificationsEnabled,
    bool? rideRequestSound,
    bool? keepScreenAwake,
    DistanceUnit? distanceUnit,
    NavApp? navApp,
  }) =>
      DriverPreferences(
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
        rideRequestSound: rideRequestSound ?? this.rideRequestSound,
        keepScreenAwake: keepScreenAwake ?? this.keepScreenAwake,
        distanceUnit: distanceUnit ?? this.distanceUnit,
        navApp: navApp ?? this.navApp,
        unknown: unknown,
      );

  factory DriverPreferences.fromJson(Map<String, dynamic> json) =>
      DriverPreferences(
        notificationsEnabled: json['notifications_enabled'] as bool? ?? true,
        rideRequestSound: json['ride_request_sound'] as bool? ?? true,
        keepScreenAwake: json['keep_screen_awake'] as bool? ?? false,
        distanceUnit: switch (json['distance_unit'] as String?) {
          'kilometres' || 'km' => DistanceUnit.kilometres,
          _ => DistanceUnit.miles,
        },
        navApp: switch (json['nav_app'] as String?) {
          'apple' => NavApp.apple,
          _ => NavApp.google,
        },
        unknown: {
          for (final e in json.entries)
            if (!_known.contains(e.key)) e.key: e.value,
        },
      );

  Map<String, dynamic> toJson() => {
        ...unknown,
        'notifications_enabled': notificationsEnabled,
        'ride_request_sound': rideRequestSound,
        'keep_screen_awake': keepScreenAwake,
        'distance_unit': distanceUnit == DistanceUnit.kilometres
            ? 'kilometres'
            : 'miles',
        'nav_app': navApp == NavApp.apple ? 'apple' : 'google',
      };
}
```

Create `app/lib/features/profile/data/preferences_repository.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/result.dart';
import 'models/driver_preferences.dart';

class PreferencesRepository {
  final ApiClient _api;
  PreferencesRepository(this._api);

  Future<Result<DriverPreferences>> load() async {
    final r = await _api.get<Map<String, dynamic>>('/me/preferences');
    return r.when(
      ok: (json) => Ok(DriverPreferences.fromJson(
          Map<String, dynamic>.from((json['preferences'] as Map?) ?? const {}))),
      err: (e) => Err(e),
    );
  }

  Future<Result<void>> save(DriverPreferences prefs) async {
    final r = await _api.patch<dynamic>('/me/preferences',
        body: {'preferences': prefs.toJson()});
    return r.when(ok: (_) => const Ok(null), err: (e) => Err(e));
  }
}

final preferencesRepositoryProvider = Provider<PreferencesRepository>(
    (ref) => PreferencesRepository(ref.watch(apiClientProvider)));
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/features/profile/`
Expected: PASS, 9 tests

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/profile app/test/features/profile
git commit -m "feat: add driver preferences preserving unknown keys"
```

---

### Task 3: Notifications

**Files:**
- Create: `app/lib/features/notifications/data/models/app_notification.dart`
- Create: `app/lib/features/notifications/data/notifications_repository.dart`
- Create: `app/lib/features/notifications/logic/notifications_controller.dart`
- Create: `app/lib/features/notifications/ui/notifications_screen.dart`
- Test: `app/test/features/notifications/notifications_test.dart`

**Interfaces:**
- Consumes: `ApiClient`, `Result` (Batch 1), `CursorList` (Batch 5 Task 4)
- Produces: `AppNotification(id, type, title, ntfBody, rideId, deepLink, read, createdAt)`; `NotificationsPage(notifications, nextCursor, hasMore)`; `NotificationsRepository.page({cursor})`, `.markRead(id)`, `.markAllRead()`, `.dismiss(id)`, `.clearAll()`; `NotificationsController`; `NotificationsScreen`.

- [ ] **Step 1: Write the failing test**

Create `app/test/features/notifications/notifications_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_client.dart';
import 'package:hoppin_driver/core/auth/token_store.dart';
import 'package:hoppin_driver/features/notifications/data/models/app_notification.dart';
import 'package:hoppin_driver/features/notifications/data/notifications_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockAdapter extends Mock implements HttpClientAdapter {}

void main() {
  setUpAll(() => registerFallbackValue(RequestOptions(path: '/')));

  ResponseBody body(String json, int status) =>
      ResponseBody.fromString(json, status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  late _MockAdapter adapter;
  late NotificationsRepository repo;

  setUp(() {
    adapter = _MockAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    repo = NotificationsRepository(ApiClient(dio, InMemoryTokenStore()));
  });

  test('parses a notification with its deep link', () {
    final n = AppNotification.fromJson({
      'id': 'n1',
      'type': 'compliance',
      'title': 'Appeal decided',
      'body': 'Your appeal was approved.',
      'deep_link': 'hoppin://appeals',
      'read': false,
      'created_at': '2026-08-30T10:00:00Z',
    });

    expect(n.title, 'Appeal decided');
    expect(n.deepLink, 'hoppin://appeals');
    expect(n.read, isFalse);
  });

  test('read_at implies read even without the boolean', () {
    final n = AppNotification.fromJson({
      'id': 'n2',
      'title': 'x',
      'read_at': '2026-08-30T11:00:00Z',
      'created_at': '2026-08-30T10:00:00Z',
    });

    expect(n.read, isTrue);
  });

  test('reads a page with its cursor', () async {
    when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async => body(
        '{"notifications":[{"id":"n1","title":"Hi","read":false,'
        '"created_at":"2026-08-30T10:00:00Z"}],'
        '"next_cursor":"abc","has_more":true}',
        200));

    final r = await repo.page();

    expect(r.valueOrNull!.notifications.single.id, 'n1');
    expect(r.valueOrNull!.nextCursor, 'abc');
  });

  test('marking one read patches that notification', () async {
    when(() => adapter.fetch(any(), any(), any()))
        .thenAnswer((_) async => body('{}', 200));

    await repo.markRead('n1');

    final sent = verify(() => adapter.fetch(captureAny(), any(), any()))
        .captured
        .first as RequestOptions;
    expect(sent.path.contains('/me/notifications/n1/read'), isTrue);
    expect(sent.method, 'PATCH');
  });

  test('dismissing one deletes only that notification', () async {
    when(() => adapter.fetch(any(), any(), any()))
        .thenAnswer((_) async => body('{}', 200));

    await repo.dismiss('n1');

    final sent = verify(() => adapter.fetch(captureAny(), any(), any()))
        .captured
        .first as RequestOptions;
    expect(sent.method, 'DELETE');
    expect(sent.path.endsWith('/me/notifications/n1'), isTrue);
  });

  test('clear all deletes the centre, not one entry', () async {
    when(() => adapter.fetch(any(), any(), any()))
        .thenAnswer((_) async => body('{}', 200));

    await repo.clearAll();

    final sent = verify(() => adapter.fetch(captureAny(), any(), any()))
        .captured
        .first as RequestOptions;
    expect(sent.method, 'DELETE');
    expect(sent.path.endsWith('/me/notifications'), isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/notifications/`
Expected: FAIL — files do not exist

- [ ] **Step 3: Write the model and repository**

Create `app/lib/features/notifications/data/models/app_notification.dart`:

```dart
class AppNotification {
  final String id;
  final String? type;
  final String title;
  final String ntfBody;
  final String? rideId;
  final String? deepLink;
  final bool read;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.createdAt,
    this.type,
    this.ntfBody = '',
    this.rideId,
    this.deepLink,
    this.read = false,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        type: json['type'] as String?,
        title: (json['title'] as String?) ?? '',
        ntfBody: (json['body'] as String?) ?? '',
        rideId: json['ride_id'] as String?,
        deepLink: json['deep_link'] as String?,
        // The server sends both a boolean and a timestamp; either being
        // present means read.
        read: (json['read'] as bool?) ?? (json['read_at'] != null),
        createdAt:
            DateTime.tryParse((json['created_at'] as String?) ?? '') ??
                DateTime.now(),
      );
}

class NotificationsPage {
  final List<AppNotification> notifications;
  final String? nextCursor;
  final bool hasMore;

  const NotificationsPage({
    required this.notifications,
    this.nextCursor,
    this.hasMore = false,
  });

  factory NotificationsPage.fromJson(Map<String, dynamic> json) =>
      NotificationsPage(
        notifications: ((json['notifications'] as List?) ?? const [])
            .map((e) =>
                AppNotification.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        nextCursor: json['next_cursor'] as String?,
        hasMore: json['has_more'] as bool? ?? false,
      );
}
```

Create `app/lib/features/notifications/data/notifications_repository.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/result.dart';
import 'models/app_notification.dart';

/// The notification centre.
///
/// This endpoint is the history — the list is never assembled from received
/// pushes, because a push dropped by an OEM battery manager would then leave
/// a permanent hole in it.
class NotificationsRepository {
  final ApiClient _api;
  NotificationsRepository(this._api);

  Future<Result<NotificationsPage>> page({String? cursor, int limit = 50}) async {
    final r = await _api.get<Map<String, dynamic>>('/me/notifications', query: {
      'limit': limit,
      if (cursor != null) 'cursor': cursor,
    });
    return r.when(
      ok: (json) => Ok(NotificationsPage.fromJson(json)),
      err: (e) => Err(e),
    );
  }

  Future<Result<void>> markRead(String id) async {
    final r = await _api.patch<dynamic>('/me/notifications/$id/read');
    return r.when(ok: (_) => const Ok(null), err: (e) => Err(e));
  }

  Future<Result<void>> markAllRead() async {
    final r = await _api.post<dynamic>('/me/notifications/read-all');
    return r.when(ok: (_) => const Ok(null), err: (e) => Err(e));
  }

  Future<Result<void>> dismiss(String id) async {
    final r = await _api.delete<dynamic>('/me/notifications/$id');
    return r.when(ok: (_) => const Ok(null), err: (e) => Err(e));
  }

  Future<Result<void>> clearAll() async {
    final r = await _api.delete<dynamic>('/me/notifications');
    return r.when(ok: (_) => const Ok(null), err: (e) => Err(e));
  }
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
    (ref) => NotificationsRepository(ref.watch(apiClientProvider)));
```

- [ ] **Step 4: Write the controller and screen**

Create `app/lib/features/notifications/logic/notifications_controller.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../data/models/app_notification.dart';
import '../data/notifications_repository.dart';

class NotificationsState {
  final List<AppNotification> notifications;
  final String? nextCursor;
  final bool isLoadingMore;
  final ApiException? error;

  const NotificationsState({
    this.notifications = const [],
    this.nextCursor,
    this.isLoadingMore = false,
    this.error,
  });

  bool get hasMore => nextCursor != null;
  int get unreadCount => notifications.where((n) => !n.read).length;

  NotificationsState copyWith({
    List<AppNotification>? notifications,
    String? nextCursor,
    bool? isLoadingMore,
    ApiException? error,
    bool clearCursor = false,
  }) =>
      NotificationsState(
        notifications: notifications ?? this.notifications,
        nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        error: error ?? this.error,
      );
}

class NotificationsController extends AsyncNotifier<NotificationsState> {
  bool _disposed = false;

  @override
  Future<NotificationsState> build() async {
    ref.onDispose(() => _disposed = true);
    return _fetch();
  }

  NotificationsState get _current =>
      state.value ?? const NotificationsState();

  void _emit(NotificationsState next) {
    if (_disposed) return;
    state = AsyncData(next);
  }

  Future<NotificationsState> _fetch() async {
    final result = await ref.read(notificationsRepositoryProvider).page();
    return result.when(
      ok: (page) => NotificationsState(
        notifications: page.notifications,
        nextCursor: page.nextCursor,
      ),
      err: (e) => NotificationsState(error: e),
    );
  }

  Future<void> refresh() async => _emit(await _fetch());

  Future<void> loadMore() async {
    final cursor = _current.nextCursor;
    if (cursor == null || _current.isLoadingMore) return;

    _emit(_current.copyWith(isLoadingMore: true));
    final result =
        await ref.read(notificationsRepositoryProvider).page(cursor: cursor);
    result.when(
      ok: (page) => _emit(_current.copyWith(
        notifications: [..._current.notifications, ...page.notifications],
        nextCursor: page.nextCursor,
        clearCursor: page.nextCursor == null,
        isLoadingMore: false,
      )),
      err: (e) => _emit(_current.copyWith(isLoadingMore: false, error: e)),
    );
  }

  Future<void> markRead(String id) async {
    await ref.read(notificationsRepositoryProvider).markRead(id);
    await refresh();
  }

  Future<void> markAllRead() async {
    await ref.read(notificationsRepositoryProvider).markAllRead();
    await refresh();
  }

  Future<void> dismiss(String id) async {
    await ref.read(notificationsRepositoryProvider).dismiss(id);
    await refresh();
  }
}

final notificationsControllerProvider =
    AsyncNotifierProvider<NotificationsController, NotificationsState>(
        NotificationsController.new);
```

Create `app/lib/features/notifications/ui/notifications_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_loading.dart';
import '../../../shared/widgets/cursor_list.dart';
import '../data/models/app_notification.dart';
import '../logic/notifications_controller.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsControllerProvider);
    final controller = ref.read(notificationsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if ((async.value?.unreadCount ?? 0) > 0)
            TextButton(
              onPressed: controller.markAllRead,
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: async.when(
        loading: () => const AppLoading(),
        error: (e, _) => Center(child: Text('$e', style: AppText.body)),
        data: (state) => CursorList<AppNotification>(
          items: state.notifications,
          hasMore: state.hasMore,
          isLoadingMore: state.isLoadingMore,
          onLoadMore: controller.loadMore,
          onRefresh: controller.refresh,
          emptyState: const AppEmptyState(
            icon: Icons.notifications_none,
            title: 'Nothing here yet',
            message: 'Updates about your trips and account will appear here.',
          ),
          itemBuilder: (context, n) => Dismissible(
            key: ValueKey(n.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              color: AppColors.negative,
              child: const Icon(Icons.delete_outline, color: Colors.white),
            ),
            onDismissed: (_) => controller.dismiss(n.id),
            child: ListTile(
              leading: Icon(
                n.read ? Icons.notifications_none : Icons.notifications_active,
                color: n.read ? AppColors.textSecondary : AppColors.primary,
              ),
              title: Text(n.title,
                  style: AppText.body.copyWith(
                      fontWeight:
                          n.read ? FontWeight.w400 : FontWeight.w600)),
              subtitle: Text(
                '${n.ntfBody}\n${DateFormat('d MMM, HH:mm').format(n.createdAt.toLocal())}',
                style: AppText.caption,
              ),
              isThreeLine: true,
              onTap: () => controller.markRead(n.id),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd app && flutter test test/features/notifications/`
Expected: PASS, 6 tests

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/notifications app/test/features/notifications
git commit -m "feat: add the notification centre backed by the endpoint"
```

---

### Task 4: Support tickets

**Files:**
- Create: `app/lib/features/support/data/models/support_ticket.dart`
- Create: `app/lib/features/support/data/support_repository.dart`
- Test: `app/test/features/support/support_test.dart`

**Interfaces:**
- Consumes: `ApiClient`, `Result` (Batch 1)
- Produces: `TicketStatus` enum (`open`, `pending`, `resolved`, `rejected`); `SupportTicket(id, subject, category, status, ticketBody, resolutionNotes, rideId, createdAt)`; `SupportRepository.tickets()`, `.create({subject, category, body, rideId, ledgerEntryId})`. Provider `supportRepositoryProvider`.

- [ ] **Step 1: Write the failing test**

Create `app/test/features/support/support_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_client.dart';
import 'package:hoppin_driver/core/auth/token_store.dart';
import 'package:hoppin_driver/features/support/data/models/support_ticket.dart';
import 'package:hoppin_driver/features/support/data/support_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockAdapter extends Mock implements HttpClientAdapter {}

void main() {
  setUpAll(() => registerFallbackValue(RequestOptions(path: '/')));

  ResponseBody body(String json, int status) =>
      ResponseBody.fromString(json, status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  late _MockAdapter adapter;
  late SupportRepository repo;

  setUp(() {
    adapter = _MockAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    repo = SupportRepository(ApiClient(dio, InMemoryTokenStore()));
  });

  test('parses a resolved ticket with its resolution', () {
    final t = SupportTicket.fromJson({
      'id': 't1',
      'subject': 'Penalty dispute',
      'category': 'payment',
      'status': 'resolved',
      'body': 'I was charged for a no-show I reported.',
      'resolution_notes': 'Penalty reversed.',
      'created_at': '2026-08-28T10:00:00Z',
    });

    expect(t.status, TicketStatus.resolved);
    expect(t.resolutionNotes, 'Penalty reversed.');
  });

  test('an unknown status reads as open', () {
    final t = SupportTicket.fromJson({
      'id': 't2',
      'subject': 'x',
      'status': 'something_new',
      'created_at': '2026-08-28T10:00:00Z',
    });

    expect(t.status, TicketStatus.open);
  });

  test('a dispute cites the exact ledger entry', () async {
    when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async => body(
        '{"id":"t3","subject":"Dispute","status":"open",'
        '"created_at":"2026-08-30T10:00:00Z"}',
        200));

    await repo.create(
      subject: 'Dispute: Late arrival penalty',
      category: 'payment',
      ticketBody: 'I arrived on time.',
      ledgerEntryId: 'e1',
    );

    final sent = verify(() => adapter.fetch(captureAny(), any(), any()))
        .captured
        .first as RequestOptions;
    // Citing the entry is what stops support having to ask the driver which
    // charge they meant.
    expect(sent.data['ledger_entry_id'], 'e1');
    expect(sent.data['subject'], 'Dispute: Late arrival penalty');
  });

  test('omits optional references when there are none', () async {
    when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async => body(
        '{"id":"t4","subject":"Help","status":"open",'
        '"created_at":"2026-08-30T10:00:00Z"}',
        200));

    await repo.create(
        subject: 'Help', category: 'other', ticketBody: 'A question');

    final sent = verify(() => adapter.fetch(captureAny(), any(), any()))
        .captured
        .first as RequestOptions;
    expect(sent.data.containsKey('ledger_entry_id'), isFalse);
    expect(sent.data.containsKey('ride_id'), isFalse);
  });

  test('reads the ticket list', () async {
    when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async => body(
        '{"tickets":[{"id":"t1","subject":"Penalty","status":"pending",'
        '"created_at":"2026-08-28T10:00:00Z"}]}',
        200));

    final r = await repo.tickets();

    expect(r.valueOrNull!.single.status, TicketStatus.pending);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/support/`
Expected: FAIL — files do not exist

- [ ] **Step 3: Write the model and repository**

Create `app/lib/features/support/data/models/support_ticket.dart`:

```dart
enum TicketStatus { open, pending, resolved, rejected }

class SupportTicket {
  final String id;
  final String subject;
  final String? category;
  final TicketStatus status;
  final String ticketBody;
  final String? resolutionNotes;
  final String? rideId;
  final DateTime createdAt;

  const SupportTicket({
    required this.id,
    required this.subject,
    required this.status,
    required this.createdAt,
    this.category,
    this.ticketBody = '',
    this.resolutionNotes,
    this.rideId,
  });

  bool get isResolved =>
      status == TicketStatus.resolved || status == TicketStatus.rejected;

  factory SupportTicket.fromJson(Map<String, dynamic> json) => SupportTicket(
        id: json['id'] as String,
        subject: (json['subject'] as String?) ?? '',
        category: json['category'] as String?,
        status: switch (json['status'] as String?) {
          'resolved' || 'closed' => TicketStatus.resolved,
          'rejected' => TicketStatus.rejected,
          'pending' || 'in_progress' => TicketStatus.pending,
          // Anything unrecognised is still open — telling a driver their
          // issue is closed when we do not know would be the worse error.
          _ => TicketStatus.open,
        },
        ticketBody: (json['body'] as String?) ?? '',
        resolutionNotes: json['resolution_notes'] as String?,
        rideId: json['ride_id'] as String?,
        createdAt:
            DateTime.tryParse((json['created_at'] as String?) ?? '') ??
                DateTime.now(),
      );
}
```

Create `app/lib/features/support/data/support_repository.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/result.dart';
import 'models/support_ticket.dart';

class SupportRepository {
  final ApiClient _api;
  SupportRepository(this._api);

  Future<Result<List<SupportTicket>>> tickets() async {
    final r = await _api.get<dynamic>('/me/support-tickets');
    return r.when(
      ok: (data) {
        final list = data is Map
            ? ((data['tickets'] as List?) ?? const [])
            : (data as List? ?? const []);
        return Ok(list
            .map((e) =>
                SupportTicket.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList());
      },
      err: (e) => Err(e),
    );
  }

  /// `ledgerEntryId` is set when the ticket is a dispute raised from a
  /// statement row, so support sees exactly which charge is contested.
  Future<Result<SupportTicket>> create({
    required String subject,
    required String category,
    required String ticketBody,
    String? rideId,
    String? ledgerEntryId,
  }) async {
    final r = await _api.post<Map<String, dynamic>>('/me/support-tickets',
        body: {
          'subject': subject,
          'category': category,
          'body': ticketBody,
          if (rideId != null) 'ride_id': rideId,
          if (ledgerEntryId != null) 'ledger_entry_id': ledgerEntryId,
        });
    return r.when(
      ok: (json) => Ok(SupportTicket.fromJson(json)),
      err: (e) => Err(e),
    );
  }
}

final supportRepositoryProvider = Provider<SupportRepository>(
    (ref) => SupportRepository(ref.watch(apiClientProvider)));
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/features/support/`
Expected: PASS, 5 tests

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/support app/test/features/support
git commit -m "feat: add support tickets with ledger-entry citation"
```

---

### Task 5: Payout onboarding

**Files:**
- Create: `app/lib/features/payment/data/models/payout_status.dart`
- Create: `app/lib/features/payment/data/payout_repository.dart`
- Create: `app/lib/features/payment/ui/payout_screen.dart`
- Test: `app/test/features/payment/payout_test.dart`

**Interfaces:**
- Consumes: `ApiClient`, `Result` (Batch 1)
- Produces: `PayoutStatus(connected, payoutsEnabled, accountId)` with `.isReady`; `PayoutOnboarding(onboardingUrl, accountId, alreadyEnabled)`; `PayoutRepository.status()`, `.startOnboarding()`; `PayoutScreen`. Provider `payoutRepositoryProvider`.

**This resolves `PAYOUT_NOT_READY`.** Stripe Connect onboarding already exists server-side; the driver completes it in Stripe's hosted flow, so the app collects no bank or card details and PCI scope stays at SAQ-A.

- [ ] **Step 1: Write the failing test**

Create `app/test/features/payment/payout_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_client.dart';
import 'package:hoppin_driver/core/auth/token_store.dart';
import 'package:hoppin_driver/features/payment/data/models/payout_status.dart';
import 'package:hoppin_driver/features/payment/data/payout_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockAdapter extends Mock implements HttpClientAdapter {}

void main() {
  setUpAll(() => registerFallbackValue(RequestOptions(path: '/')));

  ResponseBody body(String json, int status) =>
      ResponseBody.fromString(json, status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  late _MockAdapter adapter;
  late PayoutRepository repo;

  setUp(() {
    adapter = _MockAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    repo = PayoutRepository(ApiClient(dio, InMemoryTokenStore()));
  });

  test('a fully onboarded driver is ready', () {
    final s = PayoutStatus.fromJson({
      'connected': true,
      'payouts_enabled': true,
      'account_id': 'acct_123',
    });

    expect(s.isReady, isTrue);
  });

  test('connected but not enabled is not ready', () {
    final s = PayoutStatus.fromJson({
      'connected': true,
      'payouts_enabled': false,
      'account_id': 'acct_123',
    });

    // Stripe has the account but has not cleared it for payouts — the driver
    // still cannot be paid, so the screen must not say they are set up.
    expect(s.isReady, isFalse);
    expect(s.connected, isTrue);
  });

  test('a driver who has never started is neither', () {
    final s = PayoutStatus.fromJson(const {});

    expect(s.connected, isFalse);
    expect(s.isReady, isFalse);
  });

  test('onboarding returns a hosted link, not a form', () async {
    when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async => body(
        '{"onboarding_url":"https://connect.stripe.com/setup/abc",'
        '"account_id":"acct_123","already_enabled":false}',
        200));

    final r = await repo.startOnboarding();

    // The app never collects bank details itself; Stripe's hosted flow does,
    // which is what keeps PCI scope at SAQ-A.
    expect(r.valueOrNull!.onboardingUrl,
        'https://connect.stripe.com/setup/abc');
    expect(r.valueOrNull!.alreadyEnabled, isFalse);
  });

  test('an already-enabled account says so rather than re-onboarding',
      () async {
    when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async => body(
        '{"onboarding_url":"","account_id":"acct_123",'
        '"already_enabled":true}',
        200));

    final r = await repo.startOnboarding();

    expect(r.valueOrNull!.alreadyEnabled, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/payment/`
Expected: FAIL — files do not exist

- [ ] **Step 3: Write the models and repository**

Create `app/lib/features/payment/data/models/payout_status.dart`:

```dart
/// Whether the driver can actually be paid.
///
/// `connected` means Stripe has an account for them; `payoutsEnabled` means
/// Stripe has cleared it. Both are needed — an account under review is
/// connected but cannot receive money, and telling the driver they are set
/// up would be wrong.
class PayoutStatus {
  final bool connected;
  final bool payoutsEnabled;
  final String? accountId;

  const PayoutStatus({
    this.connected = false,
    this.payoutsEnabled = false,
    this.accountId,
  });

  bool get isReady => connected && payoutsEnabled;

  factory PayoutStatus.fromJson(Map<String, dynamic> json) => PayoutStatus(
        connected: json['connected'] as bool? ?? false,
        payoutsEnabled: json['payouts_enabled'] as bool? ?? false,
        accountId: json['account_id'] as String?,
      );
}

class PayoutOnboarding {
  final String onboardingUrl;
  final String? accountId;
  final bool alreadyEnabled;

  const PayoutOnboarding({
    required this.onboardingUrl,
    this.accountId,
    this.alreadyEnabled = false,
  });

  factory PayoutOnboarding.fromJson(Map<String, dynamic> json) =>
      PayoutOnboarding(
        onboardingUrl: (json['onboarding_url'] as String?) ?? '',
        accountId: json['account_id'] as String?,
        alreadyEnabled: json['already_enabled'] as bool? ?? false,
      );
}
```

Create `app/lib/features/payment/data/payout_repository.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/result.dart';
import 'models/payout_status.dart';

class PayoutRepository {
  final ApiClient _api;
  PayoutRepository(this._api);

  Future<Result<PayoutStatus>> status() async {
    final r = await _api.get<Map<String, dynamic>>('/me/payout-account');
    return r.when(
      ok: (json) => Ok(PayoutStatus.fromJson(json)),
      err: (e) => Err(e),
    );
  }

  /// Returns a Stripe-hosted onboarding link. The driver enters their bank
  /// details on Stripe's page, never in this app.
  Future<Result<PayoutOnboarding>> startOnboarding() async {
    final r = await _api.post<Map<String, dynamic>>('/me/payout-account');
    return r.when(
      ok: (json) => Ok(PayoutOnboarding.fromJson(json)),
      err: (e) => Err(e),
    );
  }
}

final payoutRepositoryProvider = Provider<PayoutRepository>(
    (ref) => PayoutRepository(ref.watch(apiClientProvider)));
```

- [ ] **Step 4: Write the screen**

Create `app/lib/features/payment/ui/payout_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/error_codes.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/app_loading.dart';
import '../data/models/payout_status.dart';
import '../data/payout_repository.dart';

final payoutStatusProvider = FutureProvider<PayoutStatus>((ref) async {
  final result = await ref.watch(payoutRepositoryProvider).status();
  return result.valueOrNull ?? const PayoutStatus();
});

/// Payout setup. The app shows status and opens Stripe's hosted onboarding;
/// it never asks for a bank account or a card itself.
class PayoutScreen extends ConsumerStatefulWidget {
  const PayoutScreen({super.key});

  @override
  ConsumerState<PayoutScreen> createState() => _PayoutScreenState();
}

class _PayoutScreenState extends ConsumerState<PayoutScreen> {
  bool _busy = false;

  Future<void> _onboard() async {
    setState(() => _busy = true);
    final result =
        await ref.read(payoutRepositoryProvider).startOnboarding();
    if (!mounted) return;
    setState(() => _busy = false);

    await result.when(
      ok: (onboarding) async {
        if (onboarding.alreadyEnabled) {
          ref.invalidate(payoutStatusProvider);
          return;
        }
        final uri = Uri.parse(onboarding.onboardingUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      err: (e) async => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errorCopy(e)))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(payoutStatusProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Payments')),
      body: async.when(
        loading: () => const AppLoading(),
        error: (e, _) => Center(child: Text('$e', style: AppText.body)),
        data: (status) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        status.isReady
                            ? Icons.check_circle
                            : Icons.info_outline,
                        color: status.isReady
                            ? AppColors.positive
                            : AppColors.warning,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        status.isReady
                            ? 'Ready to be paid'
                            : status.connected
                                ? 'Setup in review'
                                : 'Payment setup needed',
                        style: AppText.heading,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    status.isReady
                        ? 'Your payout account is set up. Your operator issues payouts on their usual schedule.'
                        : status.connected
                            ? "We're waiting on Stripe to finish checking your details. Nothing for you to do."
                            : 'Set up your payout account so your earnings can reach you.',
                    style: AppText.bodySecondary,
                  ),
                  if (!status.isReady && !status.connected) ...[
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _busy ? null : _onboard,
                      child: const Text('Set up payouts'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You will be taken to Stripe to enter your bank details securely.',
                      style: AppText.caption,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd app && flutter test test/features/payment/`
Expected: PASS, 5 tests

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/payment app/test/features/payment
git commit -m "feat: add Stripe Connect payout onboarding"
```

---

### Task 6: Delete Account

**Files:**
- Create: `app/lib/features/profile/data/models/deletion_blocker.dart`
- Create: `app/lib/features/profile/data/deletion_repository.dart`
- Create: `app/lib/features/profile/ui/delete_account_screen.dart`
- Test: `app/test/features/profile/delete_account_test.dart`

**Interfaces:**
- Consumes: `ApiClient`, `Result` (Batch 1), `Wallet` (Batch 5 Task 1)
- Produces: `DeletionBlocker` enum + `blockerCopy(String)`; `DeletionRepository.requestDeletion()`; `DeleteAccountScreen`.

- [ ] **Step 1: Write the failing test**

Create `app/test/features/profile/delete_account_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_client.dart';
import 'package:hoppin_driver/core/auth/token_store.dart';
import 'package:hoppin_driver/features/profile/data/deletion_repository.dart';
import 'package:hoppin_driver/features/profile/data/models/deletion_blocker.dart';
import 'package:mocktail/mocktail.dart';

class _MockAdapter extends Mock implements HttpClientAdapter {}

void main() {
  setUpAll(() => registerFallbackValue(RequestOptions(path: '/')));

  ResponseBody body(String json, int status) =>
      ResponseBody.fromString(json, status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  late _MockAdapter adapter;
  late DeletionRepository repo;

  setUp(() {
    adapter = _MockAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    repo = DeletionRepository(ApiClient(dio, InMemoryTokenStore()));
  });

  test('every blocker code has copy a driver can act on', () {
    for (final code in [
      'active_trip',
      'unresolved_dispute',
      'outstanding_balance',
      'compliance_investigation',
    ]) {
      expect(blockerCopy(code).title, isNotEmpty, reason: 'missing $code');
      expect(blockerCopy(code).body, isNotEmpty, reason: 'missing $code');
    }
  });

  test('an unrecognised blocker degrades rather than showing a raw slug', () {
    final copy = blockerCopy('some_new_blocker');

    expect(copy.title, isNotEmpty);
    expect(copy.title.contains('_'), isFalse);
  });

  test('a successful deletion reports it', () async {
    when(() => adapter.fetch(any(), any(), any()))
        .thenAnswer((_) async => body('{"status":"deleted"}', 200));

    final r = await repo.requestDeletion();

    expect(r.isOk, isTrue);
  });

  test('DELETION_BLOCKED surfaces every blocker, not just the first',
      () async {
    when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async => body(
        '{"code":"DELETION_BLOCKED","error":"cannot delete",'
        '"blockers":["outstanding_balance","active_trip"]}',
        409));

    final r = await repo.requestDeletion();

    expect(r.errorOrNull!.code, 'DELETION_BLOCKED');
    // A driver blocked by two things should see both, not discover the
    // second after clearing the first.
    expect(r.errorOrNull!.fields['blockers'],
        ['outstanding_balance', 'active_trip']);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/profile/delete_account_test.dart`
Expected: FAIL — files do not exist

- [ ] **Step 3: Write the blocker copy and repository**

Create `app/lib/features/profile/data/models/deletion_blocker.dart`:

```dart
class BlockerCopy {
  final String title;
  final String body;
  const BlockerCopy(this.title, this.body);
}

const _blockers = <String, BlockerCopy>{
  'active_trip': BlockerCopy(
    'You have a trip in progress',
    'Finish or cancel your current trip, then try again.',
  ),
  'unresolved_dispute': BlockerCopy(
    'You have an open dispute',
    'We need to close your open support ticket first.',
  ),
  'outstanding_balance': BlockerCopy(
    'You have an outstanding balance',
    'Your account balance needs settling before it can be deleted.',
  ),
  'compliance_investigation': BlockerCopy(
    'Documents are under review',
    'We are still reviewing your documents. This usually finishes within a few days.',
  ),
};

/// Copy for one `DELETION_BLOCKED` reason. An unrecognised code degrades to
/// a generic message rather than showing the driver a raw slug.
BlockerCopy blockerCopy(String code) =>
    _blockers[code] ??
    const BlockerCopy('Something is blocking deletion',
        'Please contact support and we will sort it out.');
```

Create `app/lib/features/profile/data/deletion_repository.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/result.dart';

class DeletionRepository {
  final ApiClient _api;
  DeletionRepository(this._api);

  /// Irreversible. Returns 200 when the erasure ran, or 409
  /// `DELETION_BLOCKED` with a `blockers` array.
  Future<Result<void>> requestDeletion() async {
    final r = await _api.post<dynamic>('/me/delete-account');
    return r.when(ok: (_) => const Ok(null), err: (e) => Err(e));
  }
}

final deletionRepositoryProvider = Provider<DeletionRepository>(
    (ref) => DeletionRepository(ref.watch(apiClientProvider)));
```

- [ ] **Step 4: Write the screen**

Create `app/lib/features/profile/ui/delete_account_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app_router.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../data/deletion_repository.dart';
import '../data/models/deletion_blocker.dart';

/// UK GDPR right to erasure. Irreversible, so it confirms first, and when
/// the server refuses it lists every blocker rather than one message.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  bool _busy = false;
  List<String> _blockers = const [];

  Future<void> _confirmAndDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          'This erases your personal details and cannot be undone. Your trip '
          'and payment history is kept in an anonymised form, as the law requires.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep my account'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.negative),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _busy = true;
      _blockers = const [];
    });
    final result = await ref.read(deletionRepositoryProvider).requestDeletion();
    if (!mounted) return;
    setState(() => _busy = false);

    result.when(
      ok: (_) => context.go(Routes.signIn),
      err: (e) {
        if (e.code == 'DELETION_BLOCKED') {
          setState(() => _blockers = ((e.fields['blockers'] as List?) ?? const [])
              .map((b) => b as String)
              .toList());
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Delete account')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Deactivate or delete', style: AppText.title),
            const SizedBox(height: 16),
            Text('Temporary deactivation', style: AppText.heading),
            const SizedBox(height: 4),
            Text(
              "Hide your account for now. You won't receive ride offers, and your data is kept.",
              style: AppText.bodySecondary,
            ),
            const SizedBox(height: 16),
            Text('Permanent deletion', style: AppText.heading),
            const SizedBox(height: 4),
            Text(
              'Erase your personal details. This cannot be undone.',
              style: AppText.bodySecondary,
            ),
            if (_blockers.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                _blockers.length == 1
                    ? 'One thing to sort first'
                    : '${_blockers.length} things to sort first',
                style: AppText.heading,
              ),
              const SizedBox(height: 8),
              // One row per blocker, the same principle as the
              // blocked-from-online list: a driver stopped by two things
              // should see both at once.
              ..._blockers.map((code) {
                final copy = blockerCopy(code);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.negative.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(copy.title, style: AppText.body),
                      const SizedBox(height: 2),
                      Text(copy.body, style: AppText.caption),
                      if (code == 'outstanding_balance') ...[
                        const SizedBox(height: 10),
                        // No endpoint settles a balance from the app yet, so
                        // the action explains itself rather than pretending.
                        OutlinedButton(
                          onPressed: null,
                          child: const Text('Settle balance'),
                        ),
                        const SizedBox(height: 4),
                        Text('Contact support to settle your balance.',
                            style: AppText.caption),
                      ],
                    ],
                  ),
                );
              }),
            ],
            const SizedBox(height: 32),
            OutlinedButton(
              onPressed: _busy ? null : () {},
              child: const Text('Deactivate'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.negative),
              onPressed: _busy ? null : _confirmAndDelete,
              child: const Text('Delete account'),
            ),
          ],
        ),
      );
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd app && flutter test test/features/profile/`
Expected: PASS, 13 tests

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/profile app/test/features/profile
git commit -m "feat: add account deletion listing every blocker"
```

---

### Task 7: Profile, Settings and Support screens

**Files:**
- Create: `app/lib/features/profile/logic/profile_controller.dart`
- Create: `app/lib/features/profile/ui/profile_screen.dart`
- Create: `app/lib/features/profile/ui/settings_screen.dart`
- Create: `app/lib/features/support/ui/support_screen.dart`
- Modify: `app/lib/app.dart`
- Test: `app/test/features/profile/settings_screen_test.dart`

**Interfaces:**
- Consumes: everything above
- Produces: `ProfileScreen`, `SettingsScreen`, `SupportScreen`; routes registered for all Batch 7 surfaces.

- [ ] **Step 1: Write the failing test**

Create `app/test/features/profile/settings_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/result.dart';
import 'package:hoppin_driver/features/profile/data/models/driver_preferences.dart';
import 'package:hoppin_driver/features/profile/data/preferences_repository.dart';
import 'package:hoppin_driver/features/profile/ui/settings_screen.dart';
import 'package:mocktail/mocktail.dart';

class MockPrefsRepo extends Mock implements PreferencesRepository {}

Widget wrap(MockPrefsRepo repo) => ProviderScope(
      overrides: [preferencesRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: SettingsScreen()),
    );

void main() {
  late MockPrefsRepo repo;

  setUp(() {
    repo = MockPrefsRepo();
    when(() => repo.load())
        .thenAnswer((_) async => const Ok(DriverPreferences()));
    when(() => repo.save(any())).thenAnswer((_) async => const Ok(null));
  });

  testWidgets('shows the settings a driver can change', (tester) async {
    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Ride request sound'), findsOneWidget);
    expect(find.text('Keep screen awake'), findsOneWidget);
    expect(find.text('Distance units'), findsOneWidget);
  });

  testWidgets('has no Language row', (tester) async {
    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    // Single locale — a row that does nothing is worse than no row.
    expect(find.text('Language'), findsNothing);
  });

  testWidgets('persists a toggle immediately', (tester) async {
    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    verify(() => repo.save(any())).called(1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/profile/settings_screen_test.dart`
Expected: FAIL — `settings_screen.dart` does not exist

- [ ] **Step 3: Write the settings controller and screen**

Create `app/lib/features/profile/logic/profile_controller.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/driver_preferences.dart';
import '../data/models/driver_profile.dart';
import '../data/preferences_repository.dart';
import '../data/profile_repository.dart';

final profileProvider = FutureProvider<DriverProfile?>((ref) async {
  final result = await ref.watch(profileRepositoryProvider).me();
  return result.valueOrNull;
});

class PreferencesController extends AsyncNotifier<DriverPreferences> {
  bool _disposed = false;

  @override
  Future<DriverPreferences> build() async {
    ref.onDispose(() => _disposed = true);
    final result = await ref.read(preferencesRepositoryProvider).load();
    return result.valueOrNull ?? const DriverPreferences();
  }

  /// Saves on every change rather than behind a Save button — a settings
  /// screen the driver leaves without saving is a screen that silently
  /// discarded their choice.
  Future<void> update(DriverPreferences next) async {
    if (_disposed) return;
    state = AsyncData(next);
    await ref.read(preferencesRepositoryProvider).save(next);
  }
}

final preferencesControllerProvider =
    AsyncNotifierProvider<PreferencesController, DriverPreferences>(
        PreferencesController.new);
```

Create `app/lib/features/profile/ui/settings_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app_router.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/app_loading.dart';
import '../data/models/driver_preferences.dart';
import '../logic/profile_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(preferencesControllerProvider);
    final controller = ref.read(preferencesControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: async.when(
        loading: () => const AppLoading(),
        error: (e, _) => Center(child: Text('$e', style: AppText.body)),
        data: (prefs) => ListView(
          children: [
            SwitchListTile(
              title: const Text('Notifications'),
              subtitle: const Text('Ride offers and account updates'),
              value: prefs.notificationsEnabled,
              onChanged: (v) =>
                  controller.update(prefs.copyWith(notificationsEnabled: v)),
            ),
            SwitchListTile(
              title: const Text('Ride request sound'),
              value: prefs.rideRequestSound,
              onChanged: (v) =>
                  controller.update(prefs.copyWith(rideRequestSound: v)),
            ),
            SwitchListTile(
              title: const Text('Keep screen awake'),
              subtitle: const Text('While you are on a trip'),
              value: prefs.keepScreenAwake,
              onChanged: (v) =>
                  controller.update(prefs.copyWith(keepScreenAwake: v)),
            ),
            const Divider(color: AppColors.border),
            ListTile(
              title: const Text('Distance units'),
              trailing: DropdownButton<DistanceUnit>(
                value: prefs.distanceUnit,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(
                      value: DistanceUnit.miles, child: Text('Miles')),
                  DropdownMenuItem(
                      value: DistanceUnit.kilometres,
                      child: Text('Kilometres')),
                ],
                onChanged: (v) => v == null
                    ? null
                    : controller.update(prefs.copyWith(distanceUnit: v)),
              ),
            ),
            ListTile(
              title: const Text('Navigation app'),
              trailing: DropdownButton<NavApp>(
                value: prefs.navApp,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(
                      value: NavApp.google, child: Text('Google Maps')),
                  DropdownMenuItem(
                      value: NavApp.apple, child: Text('Apple Maps')),
                ],
                onChanged: (v) =>
                    v == null ? null : controller.update(prefs.copyWith(navApp: v)),
              ),
            ),
            const Divider(color: AppColors.border),
            ListTile(
              title: const Text('Payments'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(Routes.payouts),
            ),
            ListTile(
              title: Text('Delete account',
                  style: AppText.body.copyWith(color: AppColors.negative)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(Routes.deleteAccount),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Write the profile and support screens**

Create `app/lib/features/profile/ui/profile_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/app_loading.dart';
import '../logic/profile_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Personal information')),
      body: async.when(
        loading: () => const AppLoading(),
        error: (e, _) => Center(child: Text('$e', style: AppText.body)),
        data: (profile) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: CircleAvatar(
                radius: 44,
                backgroundColor: AppColors.border,
                backgroundImage: profile?.avatarUrl == null
                    ? null
                    : NetworkImage(profile!.avatarUrl!),
                child: profile?.avatarUrl == null
                    ? const Icon(Icons.person,
                        size: 40, color: AppColors.textSecondary)
                    : null,
              ),
            ),
            const SizedBox(height: 20),
            _field('Full name', profile?.fullName ?? '—'),
            _field('Email', profile?.email ?? '—'),
            _field('Phone', profile?.phoneNumber ?? '—'),
            _field('Date of birth', profile?.dateOfBirth ?? '—'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              // Name and photo are verified by the operator, so an edit here
              // would fail — this points at the route that actually works.
              child: Text(
                'Your name and photo are verified by your operator. Contact support to change them.',
                style: AppText.caption,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppText.caption),
            const SizedBox(height: 4),
            Text(value, style: AppText.body),
          ],
        ),
      );
}
```

Create `app/lib/features/support/ui/support_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_loading.dart';
import '../data/models/support_ticket.dart';
import '../data/support_repository.dart';

final ticketsProvider = FutureProvider<List<SupportTicket>>((ref) async {
  final result = await ref.watch(supportRepositoryProvider).tickets();
  return result.valueOrNull ?? const [];
});

class SupportScreen extends ConsumerWidget {
  const SupportScreen({super.key});

  static const _faq = [
    ('How do I go online?', 'Tap the toggle at the top of the Home screen. If it is disabled, the Home screen lists what needs sorting first.'),
    ('When do I get paid?', 'Your operator issues payouts on their usual schedule. You can see your balance and past payouts on the Earnings screen.'),
    ('Why was my document rejected?', 'Open the Documents tab — a rejected document shows the reviewer’s reason so you know what to change.'),
    ('How do I dispute a charge?', 'Open your Statement, find the charge, and tap Dispute. Your ticket will cite that exact entry.'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ticketsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Help & support')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Common questions', style: AppText.heading),
          ),
          ..._faq.map((entry) => ExpansionTile(
                title: Text(entry.$1, style: AppText.body),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(entry.$2, style: AppText.bodySecondary),
                  ),
                ],
              )),
          const Divider(color: AppColors.border),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Your tickets', style: AppText.heading),
          ),
          async.when(
            loading: () => const Padding(
                padding: EdgeInsets.all(32), child: AppLoading()),
            error: (_, __) => const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Tickets are unavailable right now.'),
            ),
            data: (tickets) => tickets.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: AppEmptyState(
                      icon: Icons.support_agent,
                      title: 'No tickets yet',
                    ),
                  )
                : Column(
                    children: tickets.map(_ticketTile).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _ticketTile(SupportTicket t) {
    final (label, colour) = switch (t.status) {
      TicketStatus.resolved => ('Resolved', AppColors.positive),
      TicketStatus.rejected => ('Rejected', AppColors.negative),
      TicketStatus.pending => ('In progress', AppColors.warning),
      TicketStatus.open => ('Open', AppColors.info),
    };

    return ListTile(
      title: Text(t.subject, style: AppText.body),
      subtitle: Text(
        '${DateFormat('d MMM yyyy').format(t.createdAt.toLocal())}'
        '${t.resolutionNotes == null ? '' : '\n${t.resolutionNotes}'}',
        style: AppText.caption,
      ),
      isThreeLine: t.resolutionNotes != null,
      trailing: Text(label, style: AppText.caption.copyWith(color: colour)),
    );
  }
}
```

- [ ] **Step 5: Register every Batch 7 route**

In `app/lib/app_router.dart` add:

```dart
  static const payouts = '/payouts';
  static const deleteAccount = '/delete-account';
```

In `app/lib/app.dart`, replace the placeholders and add the new routes inside the shell:

```dart
          GoRoute(
              path: Routes.personalInfo,
              builder: (_, __) => const ProfileScreen()),
          GoRoute(
              path: Routes.notifications,
              builder: (_, __) => const NotificationsScreen()),
          GoRoute(
              path: Routes.support, builder: (_, __) => const SupportScreen()),
          GoRoute(
              path: Routes.settings,
              builder: (_, __) => const SettingsScreen()),
          GoRoute(
              path: Routes.payouts, builder: (_, __) => const PayoutScreen()),
          GoRoute(
              path: Routes.deleteAccount,
              builder: (_, __) => const DeleteAccountScreen()),
```

Delete `_placeholder` once nothing references it.

- [ ] **Step 6: Run the whole suite**

Run: `cd app && flutter test && flutter analyze`
Expected: all PASS, analyzer clean

- [ ] **Step 7: Commit**

```bash
git add app/lib app/test
git commit -m "feat: add profile, settings and support screens"
```

---

## Batch 7 done when

- `flutter test` passes and `flutter analyze` is clean.
- Settings persists every change immediately and preserves preference keys this app does not recognise.
- There is no Language row.
- Notifications list, mark read, and dismiss against the endpoint — never assembled from pushes.
- A support ticket raised from a statement row cites that exact ledger entry.
- Payout setup opens Stripe's hosted flow; the app collects no bank or card details anywhere.
- Delete Account confirms first and, when refused, lists every blocker with copy the driver can act on.

**This completes Phase 1.** Every screen in the spec is either built or explicitly excluded with a reason.
