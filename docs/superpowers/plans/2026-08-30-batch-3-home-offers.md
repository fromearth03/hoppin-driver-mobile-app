# Driver App — Batch 3: Home & Offers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A driver goes online, sees why if they can't, receives offers by push with a polling safety net, and accepts or declines one against a live countdown.

**Architecture:** `DriverStatusRepository` and `OfferRepository` over the Batch 1 `ApiClient`. `HomeController` (Riverpod `AsyncNotifier`) owns presence, blockers and the current offer; one 5-second ticker polls offers and status together, running only while online and not on a trip. FCM wakes the app and triggers an immediate fetch — the push is a trigger, never a data source.

**Tech Stack:** Flutter, Riverpod, Dio, `firebase_messaging`, `geolocator`.

**Spec:** `docs/superpowers/specs/2026-08-30-driver-app-phase1-design.md` §3.1, §4.2

## Global Constraints

- **Offer cards show no rider identity** — no name, photo, rating or comment. Fare, distances, ETA, category, countdown only. Equality Act 2010; see spec §6.1.
- **The push is a wake-up, never data.** Never render `fare` or any field from an FCM payload; wake, then `GET /drivers/me/offers`.
- **Android channel id is exactly `ride_alerts`** (created in Batch 1 Task 9).
- **Poll only while online and not on a trip.** Stop when offline, on-trip, or backgrounded. 5s interval, `/status` folded into the same tick.
- **`blocked_reason` and `NOT_ELIGIBLE.reason` share one vocabulary** — 11 tokens, one copy map (`notEligibleCopy`, Batch 1 Task 4).
- Money is `Pence`; server copy verbatim; light theme tokens only.

---

### Task 1: Driver status model and repository

**Files:**
- Create: `app/lib/features/home/data/models/driver_status.dart`
- Create: `app/lib/features/home/data/driver_status_repository.dart`
- Test: `app/test/features/home/driver_status_test.dart`

**Interfaces:**
- Consumes: `ApiClient`, `Result` (Batch 1)
- Produces:
  - `Presence` enum (`online`, `stale`, `offline`), `DriverStatus(presence, lastLocationAt, staleAfterSeconds, dispatchable, blockedReason, blockingDocumentTypes, activeRideId)` with `.isBlocked`, `.fromJson`.
  - `DriverStatusRepository.status() → Result<DriverStatus>`, `.goOnline() → Result<DriverStatus>`, `.goOffline() → Result<void>`, `.updateLocation(lat, lng) → Result<void>`.
  - Provider `driverStatusRepositoryProvider`.

- [ ] **Step 1: Write the failing test**

Create `app/test/features/home/driver_status_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_client.dart';
import 'package:hoppin_driver/core/auth/token_store.dart';
import 'package:hoppin_driver/features/home/data/driver_status_repository.dart';
import 'package:hoppin_driver/features/home/data/models/driver_status.dart';
import 'package:mocktail/mocktail.dart';

class _MockAdapter extends Mock implements HttpClientAdapter {}

void main() {
  setUpAll(() => registerFallbackValue(RequestOptions(path: '/')));

  ResponseBody _body(String json, int status) =>
      ResponseBody.fromString(json, status,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});

  late _MockAdapter adapter;
  late DriverStatusRepository repo;

  setUp(() {
    adapter = _MockAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    repo = DriverStatusRepository(ApiClient(dio, InMemoryTokenStore()));
  });

  group('DriverStatus model', () {
    test('parses an unblocked online driver', () {
      final s = DriverStatus.fromJson({
        'presence': 'online',
        'last_location_at': '2026-08-30T10:00:00Z',
        'stale_after_seconds': 90,
        'dispatchable': true,
        'blocked_reason': null,
        'active_ride_id': null,
      });

      expect(s.presence, Presence.online);
      expect(s.isBlocked, isFalse);
      expect(s.dispatchable, isTrue);
      expect(s.blockingDocumentTypes, isEmpty);
    });

    test('parses a blocked driver with the documents at fault', () {
      final s = DriverStatus.fromJson({
        'presence': 'offline',
        'stale_after_seconds': 90,
        'dispatchable': false,
        'blocked_reason': 'DOCS_EXPIRED',
        'blocking_document_types': ['vehicle_insurance', 'dbs_check'],
        'active_ride_id': null,
      });

      expect(s.isBlocked, isTrue);
      expect(s.blockedReason, 'DOCS_EXPIRED');
      expect(s.blockingDocumentTypes, ['vehicle_insurance', 'dbs_check']);
    });

    test('maps an unknown presence to offline rather than throwing', () {
      final s = DriverStatus.fromJson({
        'presence': 'something_new',
        'stale_after_seconds': 90,
        'dispatchable': false,
      });
      expect(s.presence, Presence.offline);
    });

    test('carries the active ride so Home can hand off to the trip screen', () {
      final s = DriverStatus.fromJson({
        'presence': 'online',
        'stale_after_seconds': 90,
        'dispatchable': true,
        'active_ride_id': 'ride-1',
      });
      expect(s.activeRideId, 'ride-1');
    });
  });

  group('DriverStatusRepository', () {
    test('reads status', () async {
      when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async =>
          _body('{"presence":"online","stale_after_seconds":90,'
              '"dispatchable":true}', 200));

      final r = await repo.status();

      expect(r.valueOrNull!.presence, Presence.online);
    });

    test('goOnline surfaces NOT_ELIGIBLE with its reason and documents',
        () async {
      when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async =>
          _body('{"code":"NOT_ELIGIBLE","error":"blocked",'
              '"reason":"DOCS_MISSING",'
              '"blocking_document_types":["private_hire_licence"]}', 403));

      final r = await repo.goOnline();

      expect(r.errorOrNull!.code, 'NOT_ELIGIBLE');
      expect(r.errorOrNull!.fields['reason'], 'DOCS_MISSING');
      expect(r.errorOrNull!.fields['blocking_document_types'],
          ['private_hire_licence']);
    });

    test('goOnline surfaces PAYOUT_NOT_READY', () async {
      when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async =>
          _body('{"code":"PAYOUT_NOT_READY","error":"setup"}', 403));

      final r = await repo.goOnline();

      expect(r.errorOrNull!.code, 'PAYOUT_NOT_READY');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/home/driver_status_test.dart`
Expected: FAIL — files do not exist

- [ ] **Step 3: Write the model**

Create `app/lib/features/home/data/models/driver_status.dart`:

```dart
/// Presence as the dispatcher sees it. `stale` means the driver is marked
/// online but their GPS has not reported inside `staleAfterSeconds` — they
/// will not be dispatched, and the UI must say so.
enum Presence { online, stale, offline }

class DriverStatus {
  final Presence presence;
  final DateTime? lastLocationAt;
  final int staleAfterSeconds;
  final bool dispatchable;

  /// One of the 11 shared eligibility tokens, or null when clear.
  final String? blockedReason;

  /// Present only for DOCS_* reasons. Every document standing in the way,
  /// so the driver can clear them in one sitting rather than one at a time.
  final List<String> blockingDocumentTypes;

  final String? activeRideId;

  const DriverStatus({
    required this.presence,
    required this.staleAfterSeconds,
    required this.dispatchable,
    this.lastLocationAt,
    this.blockedReason,
    this.blockingDocumentTypes = const [],
    this.activeRideId,
  });

  bool get isBlocked => blockedReason != null;

  factory DriverStatus.fromJson(Map<String, dynamic> json) => DriverStatus(
        presence: switch (json['presence'] as String?) {
          'online' => Presence.online,
          'stale' => Presence.stale,
          // An unrecognised presence is treated as offline: the safe reading
          // is "not currently taking work", never a false online.
          _ => Presence.offline,
        },
        lastLocationAt: json['last_location_at'] == null
            ? null
            : DateTime.parse(json['last_location_at'] as String),
        staleAfterSeconds: (json['stale_after_seconds'] as num?)?.toInt() ?? 90,
        dispatchable: json['dispatchable'] as bool? ?? false,
        blockedReason: json['blocked_reason'] as String?,
        blockingDocumentTypes:
            ((json['blocking_document_types'] as List?) ?? const [])
                .map((e) => e as String)
                .toList(),
        activeRideId: json['active_ride_id'] as String?,
      );
}
```

- [ ] **Step 4: Write the repository**

Create `app/lib/features/home/data/driver_status_repository.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/result.dart';
import 'models/driver_status.dart';

class DriverStatusRepository {
  final ApiClient _api;
  DriverStatusRepository(this._api);

  Future<Result<DriverStatus>> status() async {
    final r = await _api.get<Map<String, dynamic>>('/drivers/me/status');
    return r.when(
      ok: (json) => Ok(DriverStatus.fromJson(json)),
      err: (e) => Err(e),
    );
  }

  /// A refusal arrives as 403 with `reason` + `blocking_document_types`;
  /// [ApiException.fields] carries both through untouched.
  Future<Result<DriverStatus>> goOnline() async {
    final r = await _api.post<Map<String, dynamic>>('/drivers/me/online');
    return r.when(
      ok: (json) => Ok(DriverStatus.fromJson(json)),
      err: (e) => Err(e),
    );
  }

  Future<Result<void>> goOffline() async {
    final r = await _api.post<dynamic>('/drivers/me/offline');
    return r.when(ok: (_) => const Ok(null), err: (e) => Err(e));
  }

  Future<Result<void>> updateLocation(double lat, double lng) async {
    final r = await _api.post<dynamic>('/drivers/me/location',
        body: {'lat': lat, 'lng': lng});
    return r.when(ok: (_) => const Ok(null), err: (e) => Err(e));
  }
}

final driverStatusRepositoryProvider = Provider<DriverStatusRepository>(
    (ref) => DriverStatusRepository(ref.watch(apiClientProvider)));
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd app && flutter test test/features/home/driver_status_test.dart`
Expected: PASS, 7 tests

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/home/data app/test/features/home/driver_status_test.dart
git commit -m "feat: add driver status model and repository"
```

---

### Task 2: Offer model and repository

**Files:**
- Create: `app/lib/features/home/data/models/pending_offer.dart`
- Create: `app/lib/features/home/data/offer_repository.dart`
- Test: `app/test/features/home/offer_test.dart`

**Interfaces:**
- Consumes: `ApiClient`, `Pence`, `Result` (Batch 1)
- Produces:
  - `PendingOffer(id, rideId, fare, pickupLabel, dropoffLabel, rideCategory, estimatedDurationSeconds, pickupEtaSeconds, expiresInSec, receivedAt)` with `.fromJson`, `.secondsRemaining`, `.hasExpired`.
  - `OfferRepository.offers() → Result<List<PendingOffer>>`, `.accept(offerId) → Result<String>` (returns rideId), `.decline(offerId) → Result<void>`.
  - Provider `offerRepositoryProvider`.

- [ ] **Step 1: Write the failing test**

Create `app/test/features/home/offer_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_client.dart';
import 'package:hoppin_driver/core/auth/token_store.dart';
import 'package:hoppin_driver/core/money.dart';
import 'package:hoppin_driver/features/home/data/models/pending_offer.dart';
import 'package:hoppin_driver/features/home/data/offer_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockAdapter extends Mock implements HttpClientAdapter {}

void main() {
  setUpAll(() => registerFallbackValue(RequestOptions(path: '/')));

  ResponseBody _body(String json, int status) =>
      ResponseBody.fromString(json, status,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});

  late _MockAdapter adapter;
  late OfferRepository repo;

  setUp(() {
    adapter = _MockAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    repo = OfferRepository(ApiClient(dio, InMemoryTokenStore()));
  });

  group('PendingOffer', () {
    test('parses the widened payload', () {
      final o = PendingOffer.fromJson({
        'id': 'offer-1',
        'ride_id': 'ride-1',
        'fare_pence': 2015,
        'pickup_label': 'City Centre',
        'dropoff_label': 'Railway Station',
        'ride_category': 'standard',
        'estimated_duration_seconds': 900,
        'pickup_eta_seconds': 240,
        'expires_in_sec': 60,
      });

      expect(o.fare, const Pence(2015));
      expect(o.pickupLabel, 'City Centre');
      expect(o.pickupEtaSeconds, 240);
      expect(o.expiresInSec, 60);
    });

    test('prefers fare_pence over the deprecated float fare', () {
      final o = PendingOffer.fromJson({
        'id': 'o', 'ride_id': 'r',
        'fare': 20.15,
        'fare_pence': 2015,
        'pickup_label': 'A', 'dropoff_label': 'B',
        'expires_in_sec': 60,
      });
      expect(o.fare.pence, 2015);
    });

    test('tolerates a null pickup ETA', () {
      final o = PendingOffer.fromJson({
        'id': 'o', 'ride_id': 'r',
        'fare_pence': 1000,
        'pickup_label': 'A', 'dropoff_label': 'B',
        'pickup_eta_seconds': null,
        'expires_in_sec': 60,
      });
      expect(o.pickupEtaSeconds, isNull);
    });

    test('counts down from when it was received', () {
      final o = PendingOffer.fromJson({
        'id': 'o', 'ride_id': 'r', 'fare_pence': 1000,
        'pickup_label': 'A', 'dropoff_label': 'B', 'expires_in_sec': 60,
      }, receivedAt: DateTime.now().subtract(const Duration(seconds: 20)));

      expect(o.secondsRemaining, closeTo(40, 1));
      expect(o.hasExpired, isFalse);
    });

    test('reports expiry once the window has passed', () {
      final o = PendingOffer.fromJson({
        'id': 'o', 'ride_id': 'r', 'fare_pence': 1000,
        'pickup_label': 'A', 'dropoff_label': 'B', 'expires_in_sec': 60,
      }, receivedAt: DateTime.now().subtract(const Duration(seconds: 61)));

      expect(o.hasExpired, isTrue);
      expect(o.secondsRemaining, 0);
    });

    test('carries no rider identity fields at all', () {
      // Guards the Equality Act position: even if the server started
      // sending a name, the model has nowhere to put it.
      final o = PendingOffer.fromJson({
        'id': 'o', 'ride_id': 'r', 'fare_pence': 1000,
        'pickup_label': 'A', 'dropoff_label': 'B', 'expires_in_sec': 60,
        'rider_name': 'Should Not Appear',
        'rider_rating': 4.3,
      });
      expect(o.toString().contains('Should Not Appear'), isFalse);
    });
  });

  group('OfferRepository', () {
    test('returns an empty list when there is no offer', () async {
      when(() => adapter.fetch(any(), any(), any()))
          .thenAnswer((_) async => _body('{"offers":[]}', 200));

      final r = await repo.offers();

      expect(r.valueOrNull, isEmpty);
    });

    test('parses a bare array as well as an envelope', () async {
      when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async =>
          _body('[{"id":"o","ride_id":"r","fare_pence":1000,'
              '"pickup_label":"A","dropoff_label":"B","expires_in_sec":60}]',
              200));

      final r = await repo.offers();

      expect(r.valueOrNull!.single.id, 'o');
    });

    test('accept returns the ride id', () async {
      when(() => adapter.fetch(any(), any(), any()))
          .thenAnswer((_) async => _body('{"ride_id":"ride-9"}', 200));

      final r = await repo.accept('offer-1');

      expect(r.valueOrNull, 'ride-9');
    });

    test('accept surfaces OFFER_EXPIRED', () async {
      when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async =>
          _body('{"code":"OFFER_EXPIRED","error":"lapsed"}', 409));

      final r = await repo.accept('offer-1');

      expect(r.errorOrNull!.code, 'OFFER_EXPIRED');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/home/offer_test.dart`
Expected: FAIL — files do not exist

- [ ] **Step 3: Write the model**

Create `app/lib/features/home/data/models/pending_offer.dart`:

```dart
import '../../../../core/money.dart';

/// A dispatch offer, exactly as `GET /drivers/me/offers` returns it.
///
/// There is deliberately no rider name, photo, rating or comment. The
/// payload does not carry them and the app must not ask: showing identity
/// before accept/decline turns every decline into a data point tied to a
/// protected characteristic. See spec §6.1.
class PendingOffer {
  final String id;
  final String rideId;
  final Pence fare;
  final String pickupLabel;
  final String dropoffLabel;
  final String? rideCategory;
  final int? estimatedDurationSeconds;

  /// Live OSRM ETA from the driver's position to the pickup. Null when the
  /// server has no position to compute from.
  final int? pickupEtaSeconds;

  final int expiresInSec;

  /// When this app received the offer — the countdown runs from here, not
  /// from an absolute server timestamp we would have to trust the clock for.
  final DateTime receivedAt;

  const PendingOffer({
    required this.id,
    required this.rideId,
    required this.fare,
    required this.pickupLabel,
    required this.dropoffLabel,
    required this.expiresInSec,
    required this.receivedAt,
    this.rideCategory,
    this.estimatedDurationSeconds,
    this.pickupEtaSeconds,
  });

  factory PendingOffer.fromJson(Map<String, dynamic> json,
          {DateTime? receivedAt}) =>
      PendingOffer(
        id: json['id'] as String,
        rideId: (json['ride_id'] ?? json['rideId']) as String,
        // fare_pence is authoritative; the float `fare` is deprecated and
        // only read if the integer is somehow absent.
        fare: json['fare_pence'] != null
            ? Pence((json['fare_pence'] as num).toInt())
            : Pence.fromPounds(((json['fare'] as num?) ?? 0).toDouble()),
        pickupLabel: (json['pickup_label'] as String?) ?? '',
        dropoffLabel: (json['dropoff_label'] as String?) ?? '',
        rideCategory: json['ride_category'] as String?,
        estimatedDurationSeconds:
            (json['estimated_duration_seconds'] as num?)?.toInt(),
        pickupEtaSeconds: (json['pickup_eta_seconds'] as num?)?.toInt(),
        expiresInSec: (json['expires_in_sec'] as num?)?.toInt() ?? 60,
        receivedAt: receivedAt ?? DateTime.now(),
      );

  int get secondsRemaining {
    final elapsed = DateTime.now().difference(receivedAt).inSeconds;
    final left = expiresInSec - elapsed;
    return left < 0 ? 0 : left;
  }

  bool get hasExpired => secondsRemaining <= 0;

  @override
  String toString() => 'PendingOffer($id, ${fare.format()})';
}
```

- [ ] **Step 4: Write the repository**

Create `app/lib/features/home/data/offer_repository.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/result.dart';
import 'models/pending_offer.dart';

class OfferRepository {
  final ApiClient _api;
  OfferRepository(this._api);

  Future<Result<List<PendingOffer>>> offers() async {
    final r = await _api.get<dynamic>('/drivers/me/offers');
    return r.when(
      ok: (data) {
        // Accepts either {"offers":[…]} or a bare array — the endpoint has
        // used both shapes and either is unambiguous.
        final list = data is Map
            ? ((data['offers'] as List?) ?? const [])
            : (data as List? ?? const []);
        final received = DateTime.now();
        return Ok(list
            .map((e) => PendingOffer.fromJson(
                Map<String, dynamic>.from(e as Map),
                receivedAt: received))
            .toList());
      },
      err: (e) => Err(e),
    );
  }

  /// Returns the ride id to hand to the trip screen.
  Future<Result<String>> accept(String offerId) async {
    final r = await _api.post<Map<String, dynamic>>('/offers/$offerId/accept');
    return r.when(
      ok: (json) => Ok((json['ride_id'] ?? json['id']) as String),
      err: (e) => Err(e),
    );
  }

  Future<Result<void>> decline(String offerId) async {
    final r = await _api.post<dynamic>('/offers/$offerId/decline');
    return r.when(ok: (_) => const Ok(null), err: (e) => Err(e));
  }
}

final offerRepositoryProvider =
    Provider<OfferRepository>((ref) => OfferRepository(ref.watch(apiClientProvider)));
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd app && flutter test test/features/home/offer_test.dart`
Expected: PASS, 10 tests

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/home/data app/test/features/home/offer_test.dart
git commit -m "feat: add offer model and repository with no rider identity"
```

---

### Task 3: `HomeController` with the polling ticker

**Files:**
- Create: `app/lib/features/home/logic/home_controller.dart`
- Test: `app/test/features/home/home_controller_test.dart`

**Interfaces:**
- Consumes: `DriverStatusRepository` (Task 1), `OfferRepository` (Task 2)
- Produces: `HomeState(status, offer, isBusy, error)` and `HomeController extends AsyncNotifier<HomeState>` with `.refresh()`, `.toggleOnline()`, `.acceptOffer()`, `.declineOffer()`, `.onPushWake()`. Provider `homeControllerProvider`; `pollIntervalProvider` (default 5s) so tests can shorten it.

- [ ] **Step 1: Write the failing test**

Create `app/test/features/home/home_controller_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_exception.dart';
import 'package:hoppin_driver/core/money.dart';
import 'package:hoppin_driver/core/result.dart';
import 'package:hoppin_driver/features/home/data/driver_status_repository.dart';
import 'package:hoppin_driver/features/home/data/models/driver_status.dart';
import 'package:hoppin_driver/features/home/data/models/pending_offer.dart';
import 'package:hoppin_driver/features/home/data/offer_repository.dart';
import 'package:hoppin_driver/features/home/logic/home_controller.dart';
import 'package:mocktail/mocktail.dart';

class _MockStatusRepo extends Mock implements DriverStatusRepository {}
class _MockOfferRepo extends Mock implements OfferRepository {}

DriverStatus _status({
  Presence presence = Presence.offline,
  String? blocked,
  List<String> docs = const [],
  String? activeRide,
}) =>
    DriverStatus(
      presence: presence,
      staleAfterSeconds: 90,
      dispatchable: blocked == null && presence == Presence.online,
      blockedReason: blocked,
      blockingDocumentTypes: docs,
      activeRideId: activeRide,
    );

PendingOffer _offer({String id = 'o1'}) => PendingOffer(
      id: id,
      rideId: 'r1',
      fare: const Pence(2015),
      pickupLabel: 'City Centre',
      dropoffLabel: 'Station',
      expiresInSec: 60,
      receivedAt: DateTime.now(),
    );

ProviderContainer _container(_MockStatusRepo s, _MockOfferRepo o) {
  final c = ProviderContainer(overrides: [
    driverStatusRepositoryProvider.overrideWithValue(s),
    offerRepositoryProvider.overrideWithValue(o),
    pollIntervalProvider.overrideWithValue(const Duration(milliseconds: 20)),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  late _MockStatusRepo status;
  late _MockOfferRepo offers;

  setUp(() {
    status = _MockStatusRepo();
    offers = _MockOfferRepo();
    when(() => offers.offers()).thenAnswer((_) async => const Ok([]));
  });

  test('loads status on build', () async {
    when(() => status.status())
        .thenAnswer((_) async => Ok(_status(presence: Presence.offline)));

    final c = _container(status, offers);
    final state = await c.read(homeControllerProvider.future);

    expect(state.status!.presence, Presence.offline);
    expect(state.offer, isNull);
  });

  test('going online stores the returned status', () async {
    when(() => status.status()).thenAnswer((_) async => Ok(_status()));
    when(() => status.goOnline())
        .thenAnswer((_) async => Ok(_status(presence: Presence.online)));

    final c = _container(status, offers);
    await c.read(homeControllerProvider.future);
    await c.read(homeControllerProvider.notifier).toggleOnline();

    expect(c.read(homeControllerProvider).value!.status!.presence,
        Presence.online);
  });

  test('a NOT_ELIGIBLE refusal becomes a blocked status, not an error toast',
      () async {
    when(() => status.status()).thenAnswer((_) async => Ok(_status()));
    when(() => status.goOnline()).thenAnswer((_) async => Err(ApiException(
        'NOT_ELIGIBLE', 'blocked', 403, fields: {
      'reason': 'DOCS_EXPIRED',
      'blocking_document_types': ['vehicle_insurance'],
    })));

    final c = _container(status, offers);
    await c.read(homeControllerProvider.future);
    await c.read(homeControllerProvider.notifier).toggleOnline();

    final s = c.read(homeControllerProvider).value!.status!;
    expect(s.isBlocked, isTrue);
    expect(s.blockedReason, 'DOCS_EXPIRED');
    expect(s.blockingDocumentTypes, ['vehicle_insurance']);
  });

  test('PAYOUT_NOT_READY also lands as a blocked reason', () async {
    when(() => status.status()).thenAnswer((_) async => Ok(_status()));
    when(() => status.goOnline()).thenAnswer(
        (_) async => Err(ApiException('PAYOUT_NOT_READY', '', 403)));

    final c = _container(status, offers);
    await c.read(homeControllerProvider.future);
    await c.read(homeControllerProvider.notifier).toggleOnline();

    expect(c.read(homeControllerProvider).value!.status!.blockedReason,
        'PAYOUT_NOT_READY');
  });

  test('polls for offers while online', () async {
    when(() => status.status())
        .thenAnswer((_) async => Ok(_status(presence: Presence.online)));
    when(() => offers.offers()).thenAnswer((_) async => Ok([_offer()]));

    final c = _container(status, offers);
    await c.read(homeControllerProvider.future);
    c.read(homeControllerProvider.notifier).startPolling();
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(c.read(homeControllerProvider).value!.offer, isNotNull);
    c.read(homeControllerProvider.notifier).stopPolling();
  });

  test('does not poll while offline', () async {
    when(() => status.status())
        .thenAnswer((_) async => Ok(_status(presence: Presence.offline)));

    final c = _container(status, offers);
    await c.read(homeControllerProvider.future);
    c.read(homeControllerProvider.notifier).startPolling();
    await Future<void>.delayed(const Duration(milliseconds: 80));

    verifyNever(() => offers.offers());
    c.read(homeControllerProvider.notifier).stopPolling();
  });

  test('does not poll while on a trip', () async {
    when(() => status.status()).thenAnswer((_) async =>
        Ok(_status(presence: Presence.online, activeRide: 'ride-1')));

    final c = _container(status, offers);
    await c.read(homeControllerProvider.future);
    c.read(homeControllerProvider.notifier).startPolling();
    await Future<void>.delayed(const Duration(milliseconds: 80));

    verifyNever(() => offers.offers());
    c.read(homeControllerProvider.notifier).stopPolling();
  });

  test('a push wake fetches immediately rather than trusting the payload',
      () async {
    when(() => status.status())
        .thenAnswer((_) async => Ok(_status(presence: Presence.online)));
    when(() => offers.offers()).thenAnswer((_) async => Ok([_offer()]));

    final c = _container(status, offers);
    await c.read(homeControllerProvider.future);
    await c.read(homeControllerProvider.notifier).onPushWake();

    verify(() => offers.offers()).called(greaterThanOrEqualTo(1));
    expect(c.read(homeControllerProvider).value!.offer!.id, 'o1');
  });

  test('accepting clears the offer and reports the ride id', () async {
    when(() => status.status())
        .thenAnswer((_) async => Ok(_status(presence: Presence.online)));
    when(() => offers.offers()).thenAnswer((_) async => Ok([_offer()]));
    when(() => offers.accept('o1')).thenAnswer((_) async => const Ok('ride-9'));

    final c = _container(status, offers);
    await c.read(homeControllerProvider.future);
    await c.read(homeControllerProvider.notifier).onPushWake();

    final r = await c.read(homeControllerProvider.notifier).acceptOffer();

    expect(r.valueOrNull, 'ride-9');
    expect(c.read(homeControllerProvider).value!.offer, isNull);
  });

  test('an expired offer clears rather than sticking on screen', () async {
    when(() => status.status())
        .thenAnswer((_) async => Ok(_status(presence: Presence.online)));
    when(() => offers.offers()).thenAnswer((_) async => Ok([_offer()]));
    when(() => offers.accept(any())).thenAnswer(
        (_) async => Err(ApiException('OFFER_EXPIRED', '', 409)));

    final c = _container(status, offers);
    await c.read(homeControllerProvider.future);
    await c.read(homeControllerProvider.notifier).onPushWake();
    final r = await c.read(homeControllerProvider.notifier).acceptOffer();

    expect(r.errorOrNull!.code, 'OFFER_EXPIRED');
    expect(c.read(homeControllerProvider).value!.offer, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/home/home_controller_test.dart`
Expected: FAIL — `home_controller.dart` does not exist

- [ ] **Step 3: Write the controller**

Create `app/lib/features/home/logic/home_controller.dart`:

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/result.dart';
import '../data/driver_status_repository.dart';
import '../data/models/driver_status.dart';
import '../data/models/pending_offer.dart';
import '../data/offer_repository.dart';

class HomeState {
  final DriverStatus? status;
  final PendingOffer? offer;
  final bool isBusy;
  final ApiException? error;

  const HomeState({this.status, this.offer, this.isBusy = false, this.error});

  HomeState copyWith({
    DriverStatus? status,
    PendingOffer? offer,
    bool? isBusy,
    ApiException? error,
    bool clearOffer = false,
    bool clearError = false,
  }) =>
      HomeState(
        status: status ?? this.status,
        offer: clearOffer ? null : (offer ?? this.offer),
        isBusy: isBusy ?? this.isBusy,
        error: clearError ? null : (error ?? this.error),
      );

  bool get isOnline => status?.presence == Presence.online;
  bool get onTrip => status?.activeRideId != null;
}

/// Overridable so tests do not wait five real seconds.
final pollIntervalProvider =
    Provider<Duration>((ref) => const Duration(seconds: 5));

/// Owns presence, blockers and the current offer.
///
/// FCM is the primary path — a push wakes the app and calls [onPushWake],
/// which fetches the authoritative offer. The 5s poll is a safety net for
/// Android OEM battery managers that silently drop high-priority pushes; it
/// runs only while online and off-trip, so an idle or driving app is quiet.
class HomeController extends AsyncNotifier<HomeState> {
  Timer? _timer;

  DriverStatusRepository get _statusRepo =>
      ref.read(driverStatusRepositoryProvider);
  OfferRepository get _offerRepo => ref.read(offerRepositoryProvider);

  @override
  Future<HomeState> build() async {
    ref.onDispose(stopPolling);
    final result = await _statusRepo.status();
    return result.when(
      ok: (status) => HomeState(status: status),
      err: (e) => HomeState(error: e),
    );
  }

  HomeState get _current => state.value ?? const HomeState();

  Future<void> refresh() async {
    final result = await _statusRepo.status();
    result.when(
      ok: (status) => state = AsyncData(_current.copyWith(
          status: status, clearError: true)),
      err: (e) => state = AsyncData(_current.copyWith(error: e)),
    );
  }

  Future<void> toggleOnline() async {
    final current = _current;
    state = AsyncData(current.copyWith(isBusy: true, clearError: true));

    if (current.isOnline) {
      await _statusRepo.goOffline();
      stopPolling();
      await refresh();
      state = AsyncData(_current.copyWith(isBusy: false, clearOffer: true));
      return;
    }

    final result = await _statusRepo.goOnline();
    result.when(
      ok: (status) {
        state = AsyncData(current.copyWith(status: status, isBusy: false));
        startPolling();
      },
      err: (e) {
        // A refusal is not an error toast — it is a state the Home screen
        // renders as a resolution list. Fold the reason into the status so
        // one widget handles both the polled and refused paths.
        state = AsyncData(current.copyWith(
          isBusy: false,
          status: _blockedFrom(e, current.status),
        ));
      },
    );
  }

  /// Builds a blocked [DriverStatus] from a 403 refusal. `NOT_ELIGIBLE`
  /// carries its specific reason in `fields`; the other two refusal codes
  /// *are* the reason.
  DriverStatus _blockedFrom(ApiException e, DriverStatus? previous) {
    final reason = e.code == 'NOT_ELIGIBLE'
        ? (e.fields['reason'] as String?) ?? 'UNKNOWN'
        : e.code;
    final docs = ((e.fields['blocking_document_types'] as List?) ?? const [])
        .map((d) => d as String)
        .toList();
    return DriverStatus(
      presence: Presence.offline,
      staleAfterSeconds: previous?.staleAfterSeconds ?? 90,
      dispatchable: false,
      blockedReason: reason,
      blockingDocumentTypes: docs,
      activeRideId: previous?.activeRideId,
    );
  }

  void startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(ref.read(pollIntervalProvider), (_) => _tick());
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  /// One tick fetches offers and status together — the stale-GPS warning is
  /// as time-sensitive as an offer, and a second timer would double the load.
  Future<void> _tick() async {
    final current = _current;
    if (!current.isOnline || current.onTrip) return;

    final offersResult = await _offerRepo.offers();
    offersResult.when(
      ok: (list) => state = AsyncData(list.isEmpty
          ? _current.copyWith(clearOffer: true)
          : _current.copyWith(offer: list.first)),
      err: (_) {}, // a failed poll is not worth surfacing; the next tick retries
    );

    final statusResult = await _statusRepo.status();
    statusResult.when(
      ok: (s) => state = AsyncData(_current.copyWith(status: s)),
      err: (_) {},
    );
  }

  /// Called when an FCM ride-offer push wakes the app. The push payload is
  /// a trigger only — nothing in it is rendered.
  Future<void> onPushWake() async {
    final result = await _offerRepo.offers();
    result.when(
      ok: (list) {
        if (list.isNotEmpty) {
          state = AsyncData(_current.copyWith(offer: list.first));
        }
      },
      err: (_) {},
    );
  }

  Future<Result<String>> acceptOffer() async {
    final offer = _current.offer;
    if (offer == null) {
      return Err(ApiException('OFFER_NOT_FOUND', 'no offer on screen', 404));
    }
    state = AsyncData(_current.copyWith(isBusy: true));
    final result = await _offerRepo.accept(offer.id);

    // Either way the card comes down: accepted offers become a trip, and a
    // lapsed one must not linger looking tappable.
    state = AsyncData(_current.copyWith(isBusy: false, clearOffer: true));
    if (result.isOk) stopPolling();
    return result;
  }

  Future<void> declineOffer() async {
    final offer = _current.offer;
    if (offer == null) return;
    state = AsyncData(_current.copyWith(clearOffer: true));
    await _offerRepo.decline(offer.id);
  }
}

final homeControllerProvider =
    AsyncNotifierProvider<HomeController, HomeState>(HomeController.new);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/features/home/home_controller_test.dart`
Expected: PASS, 10 tests

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/home/logic app/test/features/home/home_controller_test.dart
git commit -m "feat: add HomeController with offer polling and blocked-state folding"
```

---

### Task 4: The blocker list widget

**Files:**
- Create: `app/lib/features/home/ui/widgets/blocker_list.dart`
- Test: `app/test/features/home/blocker_list_test.dart`

**Interfaces:**
- Consumes: `DriverStatus` (Task 1), `notEligibleCopy` + `BlockedAction` (Batch 1 Task 4)
- Produces: `BlockerList(status, {onOpenDocument, onRegisterVehicle, onContactSupport})`. Consumed by Task 6's Home screen.

- [ ] **Step 1: Write the failing test**

Create `app/test/features/home/blocker_list_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/home/data/models/driver_status.dart';
import 'package:hoppin_driver/features/home/ui/widgets/blocker_list.dart';

DriverStatus _blocked(String reason, [List<String> docs = const []]) =>
    DriverStatus(
      presence: Presence.offline,
      staleAfterSeconds: 90,
      dispatchable: false,
      blockedReason: reason,
      blockingDocumentTypes: docs,
    );

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  testWidgets('renders one row per blocking document', (tester) async {
    await tester.pumpWidget(_wrap(BlockerList(
        status: _blocked(
            'DOCS_EXPIRED', ['vehicle_insurance', 'private_hire_licence']))));

    expect(find.text('Vehicle Insurance'), findsOneWidget);
    expect(find.text('Private Hire Licence'), findsOneWidget);
  });

  testWidgets('counts the blockers in the heading', (tester) async {
    await tester.pumpWidget(_wrap(BlockerList(
        status: _blocked('DOCS_MISSING', ['dbs_check', 'mot_certificate']))));

    expect(find.textContaining('Two things to sort'), findsOneWidget);
  });

  testWidgets('uses the singular for one blocker', (tester) async {
    await tester.pumpWidget(
        _wrap(BlockerList(status: _blocked('DOCS_EXPIRED', ['dbs_check']))));

    expect(find.textContaining('One thing to sort'), findsOneWidget);
  });

  testWidgets('under review gets no chevron and no tap target',
      (tester) async {
    await tester.pumpWidget(_wrap(BlockerList(
        status: _blocked('DOCS_PENDING_REVIEW', ['dbs_check']))));

    expect(find.byIcon(Icons.chevron_right), findsNothing);
    expect(find.textContaining('no action'), findsOneWidget);
  });

  testWidgets('a support-only reason renders one row, not a document list',
      (tester) async {
    await tester.pumpWidget(_wrap(BlockerList(status: _blocked('SUSPENDED'))));

    expect(find.text('Account suspended'), findsOneWidget);
    expect(find.text('Contact support'), findsOneWidget);
  });

  testWidgets('tapping a document row reports which document', (tester) async {
    String? tapped;
    await tester.pumpWidget(_wrap(BlockerList(
      status: _blocked('DOCS_REJECTED', ['vehicle_insurance']),
      onOpenDocument: (d) => tapped = d,
    )));

    await tester.tap(find.text('Vehicle Insurance'));
    expect(tapped, 'vehicle_insurance');
  });

  testWidgets('NO_VEHICLE offers vehicle registration', (tester) async {
    var called = false;
    await tester.pumpWidget(_wrap(BlockerList(
      status: _blocked('NO_VEHICLE'),
      onRegisterVehicle: () => called = true,
    )));

    await tester.tap(find.text('No vehicle registered'));
    expect(called, isTrue);
  });

  testWidgets('renders nothing when the driver is not blocked',
      (tester) async {
    await tester.pumpWidget(_wrap(BlockerList(
        status: const DriverStatus(
            presence: Presence.online,
            staleAfterSeconds: 90,
            dispatchable: true))));

    expect(find.byType(Card), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/home/blocker_list_test.dart`
Expected: FAIL — `blocker_list.dart` does not exist

- [ ] **Step 3: Write the widget**

Create `app/lib/features/home/ui/widgets/blocker_list.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../core/api/error_codes.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../data/models/driver_status.dart';

/// What stands between the driver and going online, as a list rather than a
/// screen. `blocking_document_types` is an array — a driver blocked by three
/// documents should see all three at once, not discover them one re-upload
/// at a time.
class BlockerList extends StatelessWidget {
  final DriverStatus status;
  final void Function(String documentType)? onOpenDocument;
  final VoidCallback? onRegisterVehicle;
  final VoidCallback? onContactSupport;

  const BlockerList({
    super.key,
    required this.status,
    this.onOpenDocument,
    this.onRegisterVehicle,
    this.onContactSupport,
  });

  static const _counts = ['No', 'One', 'Two', 'Three', 'Four', 'Five'];

  /// `vehicle_insurance` → `Vehicle Insurance`. The tokens are a closed
  /// server enum, so title-casing them is safe — unlike prettifying free
  /// text, which is guesswork.
  static String documentLabel(String type) => type
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  @override
  Widget build(BuildContext context) {
    if (!status.isBlocked) return const SizedBox.shrink();

    final copy = notEligibleCopy(status.blockedReason!);
    final docs = status.blockingDocumentTypes;
    final rowCount = docs.isEmpty ? 1 : docs.length;
    final counter =
        rowCount < _counts.length ? _counts[rowCount] : '$rowCount';
    final noun = rowCount == 1 ? 'thing' : 'things';

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$counter $noun to sort before you can go online',
                style: AppText.heading),
            const SizedBox(height: 12),
            if (docs.isEmpty)
              _row(title: copy.title, subtitle: copy.body, action: copy.action)
            else
              ...docs.map((d) => _row(
                    title: documentLabel(d),
                    subtitle: copy.body,
                    action: copy.action,
                    documentType: d,
                  )),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: onContactSupport,
                child: const Text('Contact support'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row({
    required String title,
    required String subtitle,
    required BlockedAction action,
    String? documentType,
  }) {
    final (icon, tint) = switch (action) {
      BlockedAction.none => (Icons.schedule, AppColors.warning),
      BlockedAction.contactSupport => (Icons.error_outline, AppColors.negative),
      _ => (Icons.priority_high, AppColors.negative),
    };

    // A row is tappable only when there is somewhere to go. Offering a tap
    // that does nothing teaches the driver the list is decorative.
    final onTap = switch (action) {
      BlockedAction.openDocuments when documentType != null =>
        () => onOpenDocument?.call(documentType),
      BlockedAction.registerVehicle => onRegisterVehicle,
      BlockedAction.contactSupport => onContactSupport,
      _ => null,
    };

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: tint),
      title: Text(title, style: AppText.body),
      subtitle: Text(
        action == BlockedAction.none ? '$subtitle · no action' : subtitle,
        style: AppText.caption,
      ),
      trailing: onTap == null
          ? null
          : const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      onTap: onTap,
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/features/home/blocker_list_test.dart`
Expected: PASS, 8 tests

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/home/ui app/test/features/home/blocker_list_test.dart
git commit -m "feat: add blocked-from-online resolution list"
```

---

### Task 5: The offer card

**Files:**
- Create: `app/lib/features/home/ui/widgets/offer_card.dart`
- Test: `app/test/features/home/offer_card_test.dart`

**Interfaces:**
- Consumes: `PendingOffer` (Task 2), `Pence` (Batch 1)
- Produces: `OfferCard(offer, {onAccept, onDecline, isBusy})` with a live countdown ring. Consumed by Task 6.

- [ ] **Step 1: Write the failing test**

Create `app/test/features/home/offer_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/money.dart';
import 'package:hoppin_driver/features/home/data/models/pending_offer.dart';
import 'package:hoppin_driver/features/home/ui/widgets/offer_card.dart';

PendingOffer _offer({
  int farePence = 2015,
  int? etaSeconds = 240,
  int? durationSeconds = 900,
  String? category = 'standard',
}) =>
    PendingOffer(
      id: 'o1',
      rideId: 'r1',
      fare: Pence(farePence),
      pickupLabel: 'City Centre',
      dropoffLabel: 'Railway Station',
      rideCategory: category,
      estimatedDurationSeconds: durationSeconds,
      pickupEtaSeconds: etaSeconds,
      expiresInSec: 60,
      receivedAt: DateTime.now(),
    );

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('leads with the fare', (tester) async {
    await tester.pumpWidget(_wrap(OfferCard(offer: _offer())));

    expect(find.text('£20.15'), findsOneWidget);
  });

  testWidgets('shows both labels', (tester) async {
    await tester.pumpWidget(_wrap(OfferCard(offer: _offer())));

    expect(find.text('City Centre'), findsOneWidget);
    expect(find.text('Railway Station'), findsOneWidget);
  });

  testWidgets('shows pickup ETA and trip duration in minutes',
      (tester) async {
    await tester.pumpWidget(_wrap(OfferCard(offer: _offer())));

    expect(find.textContaining('4 min away'), findsOneWidget);
    expect(find.textContaining('15 min trip'), findsOneWidget);
  });

  testWidgets('omits the ETA line when the server has no position',
      (tester) async {
    await tester.pumpWidget(_wrap(OfferCard(offer: _offer(etaSeconds: null))));

    expect(find.textContaining('away'), findsNothing);
  });

  testWidgets('shows the category badge', (tester) async {
    await tester.pumpWidget(_wrap(OfferCard(offer: _offer())));

    expect(find.text('Standard'), findsOneWidget);
  });

  testWidgets('renders no rider identity of any kind', (tester) async {
    await tester.pumpWidget(_wrap(OfferCard(offer: _offer())));

    // No avatar, no star rating — the Equality Act position, enforced at
    // the widget level as well as in the model.
    expect(find.byType(CircleAvatar), findsNothing);
    expect(find.byIcon(Icons.star), findsNothing);
    expect(find.byIcon(Icons.person), findsNothing);
  });

  testWidgets('accept states the amount being accepted', (tester) async {
    await tester.pumpWidget(_wrap(OfferCard(offer: _offer())));

    expect(find.text('Accept for £20.15'), findsOneWidget);
  });

  testWidgets('accept and decline fire their callbacks', (tester) async {
    var accepted = false, declined = false;
    await tester.pumpWidget(_wrap(OfferCard(
      offer: _offer(),
      onAccept: () => accepted = true,
      onDecline: () => declined = true,
    )));

    await tester.tap(find.text('Accept for £20.15'));
    await tester.tap(find.text('Decline'));

    expect(accepted, isTrue);
    expect(declined, isTrue);
  });

  testWidgets('both actions are disabled while busy', (tester) async {
    await tester.pumpWidget(_wrap(OfferCard(
        offer: _offer(), onAccept: () {}, onDecline: () {}, isBusy: true)));

    final accept = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(accept.onPressed, isNull);
  });

  testWidgets('shows a countdown', (tester) async {
    await tester.pumpWidget(_wrap(OfferCard(offer: _offer())));
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining('s'), findsWidgets);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/home/offer_card_test.dart`
Expected: FAIL — `offer_card.dart` does not exist

- [ ] **Step 3: Write the widget**

Create `app/lib/features/home/ui/widgets/offer_card.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../data/models/pending_offer.dart';

/// The decision surface. A driver has ~60 seconds to answer two questions:
/// is this worth it, and how far do I drive unpaid to start it. Fare,
/// pickup ETA and trip length answer both.
///
/// It shows no rider name, photo or rating — see spec §6.1.
class OfferCard extends StatefulWidget {
  final PendingOffer offer;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final bool isBusy;

  const OfferCard({
    super.key,
    required this.offer,
    this.onAccept,
    this.onDecline,
    this.isBusy = false,
  });

  @override
  State<OfferCard> createState() => _OfferCardState();
}

class _OfferCardState extends State<OfferCard> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(
        const Duration(seconds: 1), (_) => mounted ? setState(() {}) : null);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  static String _minutes(int seconds) => '${(seconds / 60).round()} min';

  @override
  Widget build(BuildContext context) {
    final offer = widget.offer;
    final remaining = offer.secondsRemaining;
    final fraction =
        offer.expiresInSec == 0 ? 0.0 : remaining / offer.expiresInSec;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(offer.fare.format(), style: AppText.money),
                      if (offer.rideCategory != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: _badge(offer.rideCategory!),
                        ),
                    ],
                  ),
                ),
                _countdown(remaining, fraction),
              ],
            ),
            const SizedBox(height: 16),
            _leg(Icons.trip_origin, AppColors.info, offer.pickupLabel),
            const SizedBox(height: 8),
            _leg(Icons.place, AppColors.negative, offer.dropoffLabel),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              children: [
                if (offer.pickupEtaSeconds != null)
                  Text('${_minutes(offer.pickupEtaSeconds!)} away',
                      style: AppText.caption),
                if (offer.estimatedDurationSeconds != null)
                  Text('${_minutes(offer.estimatedDurationSeconds!)} trip',
                      style: AppText.caption),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: widget.isBusy ? null : widget.onAccept,
              child: Text('Accept for ${offer.fare.format()}'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: widget.isBusy ? null : widget.onDecline,
              child: const Text('Decline'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String category) {
    final label =
        '${category[0].toUpperCase()}${category.substring(1).replaceAll('_', ' ')}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: AppText.caption.copyWith(color: AppColors.primary)),
    );
  }

  Widget _leg(IconData icon, Color color, String label) => Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
              child: Text(label,
                  style: AppText.body, overflow: TextOverflow.ellipsis)),
        ],
      );

  /// The ring is driven by the server's `expires_in_sec`, so it reflects the
  /// real window rather than a client guess.
  Widget _countdown(int remaining, double fraction) => SizedBox(
        width: 52,
        height: 52,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              strokeWidth: 4,
              backgroundColor: AppColors.border,
              color: remaining <= 10 ? AppColors.negative : AppColors.primary,
            ),
            Text('${remaining}s', style: AppText.caption),
          ],
        ),
      );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/features/home/offer_card_test.dart`
Expected: PASS, 10 tests

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/home/ui/widgets/offer_card.dart app/test/features/home/offer_card_test.dart
git commit -m "feat: add offer card with countdown and no rider identity"
```

---

### Task 6: The Home screen

**Files:**
- Create: `app/lib/features/home/ui/home_screen.dart`
- Create: `app/lib/features/home/ui/widgets/online_toggle.dart`
- Modify: `app/lib/app.dart`
- Test: `app/test/features/home/home_screen_test.dart`

**Interfaces:**
- Consumes: `HomeController` (Task 3), `BlockerList` (Task 4), `OfferCard` (Task 5)
- Produces: `HomeScreen`, `OnlineToggle(isOnline, {onChanged, enabled})`. Replaces the Home placeholder route.

- [ ] **Step 1: Write the failing test**

Create `app/test/features/home/home_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/money.dart';
import 'package:hoppin_driver/core/result.dart';
import 'package:hoppin_driver/features/home/data/driver_status_repository.dart';
import 'package:hoppin_driver/features/home/data/models/driver_status.dart';
import 'package:hoppin_driver/features/home/data/models/pending_offer.dart';
import 'package:hoppin_driver/features/home/data/offer_repository.dart';
import 'package:hoppin_driver/features/home/ui/home_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockStatusRepo extends Mock implements DriverStatusRepository {}
class _MockOfferRepo extends Mock implements OfferRepository {}

DriverStatus _status({
  Presence presence = Presence.offline,
  String? blocked,
  List<String> docs = const [],
}) =>
    DriverStatus(
      presence: presence,
      staleAfterSeconds: 90,
      dispatchable: blocked == null && presence == Presence.online,
      blockedReason: blocked,
      blockingDocumentTypes: docs,
    );

Widget _wrap(_MockStatusRepo s, _MockOfferRepo o) => ProviderScope(
      overrides: [
        driverStatusRepositoryProvider.overrideWithValue(s),
        offerRepositoryProvider.overrideWithValue(o),
      ],
      child: const MaterialApp(home: HomeScreen()),
    );

void main() {
  late _MockStatusRepo status;
  late _MockOfferRepo offers;

  setUp(() {
    status = _MockStatusRepo();
    offers = _MockOfferRepo();
    when(() => offers.offers()).thenAnswer((_) async => const Ok([]));
  });

  testWidgets('shows the offline toggle by default', (tester) async {
    when(() => status.status()).thenAnswer((_) async => Ok(_status()));

    await tester.pumpWidget(_wrap(status, offers));
    await tester.pumpAndSettle();

    expect(find.text('Offline'), findsOneWidget);
  });

  testWidgets('shows the blocker list and disables the toggle when blocked',
      (tester) async {
    when(() => status.status()).thenAnswer((_) async =>
        Ok(_status(blocked: 'DOCS_EXPIRED', docs: ['vehicle_insurance'])));

    await tester.pumpWidget(_wrap(status, offers));
    await tester.pumpAndSettle();

    expect(find.text('Vehicle Insurance'), findsOneWidget);
    final toggle = tester.widget<Switch>(find.byType(Switch));
    expect(toggle.onChanged, isNull);
  });

  testWidgets('shows the offer card when an offer arrives', (tester) async {
    when(() => status.status())
        .thenAnswer((_) async => Ok(_status(presence: Presence.online)));
    when(() => offers.offers()).thenAnswer((_) async => Ok([
          PendingOffer(
            id: 'o1',
            rideId: 'r1',
            fare: const Pence(2015),
            pickupLabel: 'City Centre',
            dropoffLabel: 'Station',
            expiresInSec: 60,
            receivedAt: DateTime.now(),
          )
        ]));

    await tester.pumpWidget(_wrap(status, offers));
    await tester.pumpAndSettle();
    // Simulate the push wake path rather than waiting for a real 5s tick.
    final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeScreen)));
    await container.read(homeControllerProvider.notifier).onPushWake();
    await tester.pumpAndSettle();

    expect(find.text('£20.15'), findsOneWidget);
    expect(find.text('Accept for £20.15'), findsOneWidget);
  });

  testWidgets('warns when the GPS position has gone stale', (tester) async {
    when(() => status.status())
        .thenAnswer((_) async => Ok(_status(presence: Presence.stale)));

    await tester.pumpWidget(_wrap(status, offers));
    await tester.pumpAndSettle();

    expect(find.textContaining('location'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/home/home_screen_test.dart`
Expected: FAIL — `home_screen.dart` does not exist

- [ ] **Step 3: Write the toggle**

Create `app/lib/features/home/ui/widgets/online_toggle.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';

class OnlineToggle extends StatelessWidget {
  final bool isOnline;
  final ValueChanged<bool>? onChanged;

  const OnlineToggle({super.key, required this.isOnline, this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isOnline ? 'Online' : 'Offline',
              style: AppText.heading.copyWith(
                color: isOnline ? AppColors.positive : AppColors.textSecondary,
              ),
            ),
            Switch(
              value: isOnline,
              onChanged: onChanged,
              activeTrackColor: AppColors.positive,
            ),
          ],
        ),
      );
}
```

- [ ] **Step 4: Write the Home screen**

Create `app/lib/features/home/ui/home_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app_router.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_loading.dart';
import '../data/models/driver_status.dart';
import '../logic/home_controller.dart';
import 'widgets/blocker_list.dart';
import 'widgets/offer_card.dart';
import 'widgets/online_toggle.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(homeControllerProvider);
    final controller = ref.read(homeControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: async.maybeWhen(
          data: (s) => OnlineToggle(
            isOnline: s.isOnline,
            // A blocked driver gets a disabled toggle plus a list saying
            // why — never a live toggle that silently refuses.
            onChanged: (s.status?.isBlocked ?? false) || s.isBusy
                ? null
                : (_) => controller.toggleOnline(),
          ),
          orElse: () => const SizedBox.shrink(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.go(Routes.settings),
          ),
        ],
      ),
      body: async.when(
        loading: () => const AppLoading(),
        error: (e, _) => Center(child: Text('$e', style: AppText.body)),
        data: (state) {
          if (state.error != null && state.status == null) {
            return AppErrorState(
                error: state.error!, onRetry: controller.refresh);
          }
          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: ListView(
              children: [
                if (state.status?.presence == Presence.stale)
                  _staleBanner(),
                if (state.status != null)
                  BlockerList(
                    status: state.status!,
                    onOpenDocument: (_) => context.go(Routes.documents),
                    onRegisterVehicle: () => context.go(Routes.documents),
                    onContactSupport: () => context.go(Routes.support),
                  ),
                if (state.offer != null)
                  OfferCard(
                    offer: state.offer!,
                    isBusy: state.isBusy,
                    onAccept: () async {
                      final result = await controller.acceptOffer();
                      if (!context.mounted) return;
                      result.when(
                        ok: (rideId) => context.go('${Routes.trip}/$rideId'),
                        err: (_) {},
                      );
                    },
                    onDecline: controller.declineOffer,
                  )
                else
                  _waitingState(state),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _staleBanner() => Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_off, color: AppColors.warning),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "We can't see your location right now, so you won't receive offers.",
                style: AppText.caption,
              ),
            ),
          ],
        ),
      );

  Widget _waitingState(HomeState state) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 80),
        child: Column(
          children: [
            Icon(
              state.isOnline ? Icons.radar : Icons.power_settings_new,
              size: 72,
              color: state.isOnline ? AppColors.positive : AppColors.textDisabled,
            ),
            const SizedBox(height: 20),
            Text(
              state.isOnline ? 'Looking for offers…' : "You're offline",
              style: AppText.heading,
            ),
            const SizedBox(height: 6),
            Text(
              state.isOnline
                  ? "We'll let you know as soon as a ride comes in."
                  : 'Go online to start receiving ride offers.',
              style: AppText.bodySecondary,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
}
```

- [ ] **Step 5: Wire the route**

In `app/lib/app_router.dart` add:

```dart
  static const trip = '/trip';
```

In `app/lib/app.dart`, replace the Home placeholder route with `const HomeScreen()` and add the import.

- [ ] **Step 6: Run test to verify it passes**

Run: `cd app && flutter test test/features/home/ && flutter analyze`
Expected: PASS, analyzer clean

- [ ] **Step 7: Commit**

```bash
git add app/lib app/test
git commit -m "feat: add Home screen with online toggle, blockers and offers"
```

---

### Task 7: FCM registration and wake handling

**Files:**
- Create: `app/lib/core/push/push_payload.dart`
- Create: `app/lib/core/push/fcm_service.dart`
- Test: `app/test/core/push_payload_test.dart`

**Interfaces:**
- Consumes: `ApiClient` (Batch 1), `HomeController.onPushWake` (Task 3)
- Produces: `PushPayload.parse(Map) → PushPayload?` with `type`, `rideId`, `offerId`, `deepLink`; `FcmService.registerToken()`, `.listen(onOffer)`. Provider `fcmServiceProvider`.

- [ ] **Step 1: Write the failing test**

Create `app/test/core/push_payload_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/push/push_payload.dart';

void main() {
  test('parses a ride offer push', () {
    final p = PushPayload.parse({
      'type': 'ride_offer',
      'ride_id': 'r1',
      'offer_id': 'o1',
      'deep_link': '/offer',
      'expiresIn': '60',
      'fare': '20.15',
    });

    expect(p!.type, PushType.rideOffer);
    expect(p.rideId, 'r1');
    expect(p.offerId, 'o1');
  });

  test('prefers snake_case when both cases are present', () {
    final p = PushPayload.parse({
      'type': 'ride_offer',
      'ride_id': 'snake',
      'rideId': 'camel',
    });

    expect(p!.rideId, 'snake');
  });

  test('parses a compliance appeal decision', () {
    final p = PushPayload.parse({
      'type': 'compliance_appeal',
      'appeal_id': 'a1',
      'decision': 'approved',
    });

    expect(p!.type, PushType.complianceAppeal);
  });

  test('an unknown type parses as other rather than throwing', () {
    final p = PushPayload.parse({'type': 'something_new'});
    expect(p!.type, PushType.other);
  });

  test('returns null for a payload with no type', () {
    expect(PushPayload.parse({'body': 'hello'}), isNull);
  });

  test('exposes no fare or money field at all', () {
    // The push is a wake-up, not data. If the payload's fare were readable
    // here, a screen could render it and disagree with the real offer.
    final p = PushPayload.parse({'type': 'ride_offer', 'fare': '20.15'});
    expect(p.toString().contains('20.15'), isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/core/push_payload_test.dart`
Expected: FAIL — `push_payload.dart` does not exist

- [ ] **Step 3: Write the payload**

Create `app/lib/core/push/push_payload.dart`:

```dart
enum PushType { rideOffer, complianceAppeal, rideUpdate, other }

/// The routable part of an FCM data payload.
///
/// Deliberately carries no fare, label or timing. The backend sends some of
/// those as best-effort context, but rendering them would let a stale push
/// contradict `GET /drivers/me/offers`. The push says "something happened";
/// the endpoint says what.
class PushPayload {
  final PushType type;
  final String? rideId;
  final String? offerId;
  final String? appealId;
  final String? deepLink;

  const PushPayload({
    required this.type,
    this.rideId,
    this.offerId,
    this.appealId,
    this.deepLink,
  });

  static PushPayload? parse(Map<String, dynamic> data) {
    final rawType = data['type'] as String?;
    if (rawType == null) return null;

    // The backend duplicates keys in both cases; snake_case is canonical.
    String? pick(String snake, String camel) =>
        (data[snake] ?? data[camel]) as String?;

    return PushPayload(
      type: switch (rawType) {
        'ride_offer' => PushType.rideOffer,
        'compliance_appeal' => PushType.complianceAppeal,
        'ride_update' => PushType.rideUpdate,
        _ => PushType.other,
      },
      rideId: pick('ride_id', 'rideId'),
      offerId: pick('offer_id', 'offerId'),
      appealId: pick('appeal_id', 'appealId'),
      deepLink: pick('deep_link', 'deepLink'),
    );
  }

  @override
  String toString() => 'PushPayload($type, ride=$rideId, offer=$offerId)';
}
```

- [ ] **Step 4: Write the FCM service**

Add to `app/pubspec.yaml` dependencies: `firebase_core: ^3.6.0`, `firebase_messaging: ^15.1.3`, then `flutter pub get`.

Create `app/lib/core/push/fcm_service.dart`:

```dart
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import 'push_payload.dart';

/// Registers this device for offers and turns an incoming push into a
/// *fetch*, never into rendered content.
class FcmService {
  final ApiClient _api;
  final FirebaseMessaging _messaging;

  FcmService(this._api, [FirebaseMessaging? messaging])
      : _messaging = messaging ?? FirebaseMessaging.instance;

  String get _deviceOs {
    if (kIsWeb) return 'web';
    return Platform.isIOS ? 'ios' : 'android';
  }

  /// Called after sign-in and whenever FCM rotates the token. The backend
  /// treats `fcm_token` as globally unique and reassigns it if the same
  /// handset appears for a different user.
  Future<void> registerToken() async {
    await _messaging.requestPermission();
    final token = await _messaging.getToken();
    if (token == null) return;
    await _api.post<dynamic>('/me/device-tokens',
        body: {'fcm_token': token, 'device_os': _deviceOs});

    _messaging.onTokenRefresh.listen((refreshed) {
      _api.post<dynamic>('/me/device-tokens',
          body: {'fcm_token': refreshed, 'device_os': _deviceOs});
    });
  }

  /// Wires foreground messages and taps on a background notification to
  /// [onOffer], which should fetch the authoritative offer.
  void listen({required Future<void> Function() onOffer}) {
    FirebaseMessaging.onMessage.listen((message) {
      final payload = PushPayload.parse(message.data);
      if (payload?.type == PushType.rideOffer) onOffer();
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final payload = PushPayload.parse(message.data);
      if (payload?.type == PushType.rideOffer) onOffer();
    });
  }
}

final fcmServiceProvider =
    Provider<FcmService>((ref) => FcmService(ref.watch(apiClientProvider)));
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd app && flutter test test/core/push_payload_test.dart`
Expected: PASS, 6 tests

- [ ] **Step 6: Wire registration to the sign-in hook**

Batch 2 Task 4 left `onSignedInProvider` as a no-op so auth carried no
Firebase dependency. Override it now, in `app/lib/app.dart`, inside the
`ProviderScope` created in `main.dart`:

```dart
// main.dart — replace the bare ProviderScope
  runApp(ProviderScope(
    overrides: [
      onSignedInProvider.overrideWith((ref) => () async {
            await ref.read(fcmServiceProvider).registerToken();
          }),
    ],
    child: const HoppinDriverApp(),
  ));
```

Add `Firebase.initializeApp()` before `Supabase.initialize` in `main()`, and
import `package:firebase_core/firebase_core.dart`.

- [ ] **Step 7: Commit**

```bash
git add app/lib app/test app/pubspec.yaml
git commit -m "feat: add FCM token registration and wake-then-fetch handling"
```

---

## Batch 3 done when

- `flutter test` passes and `flutter analyze` is clean.
- Toggling online with a blocked account shows the resolution list, one row per blocking document, with the toggle disabled.
- An offer renders with fare, labels, ETA, category and a live countdown — and no rider identity anywhere.
- Polling starts on going online and stops on going offline, on accepting, and on disposal.

**Next:** Batch 4 (Trip lifecycle) picks up from `Routes.trip/:rideId` after an accepted offer.
