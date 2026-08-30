# Driver App — Batch 4: Trip Lifecycle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A driver who accepts an offer can navigate to the pickup, wait with the charging terms visible, start and finish the trip, chat with the rider, and cancel or report a no-show — all against the real ride endpoints.

**Architecture:** One `TripRepository` over the Batch 1 `ApiClient` covering the ride read, the four lifecycle transitions, chat, and the waiting policy. `TripController` (Riverpod `AsyncNotifier`, family-keyed on `rideId`) owns the ride and derives the screen state from `ride.status` rather than holding a separate state machine — the server is the authority on what phase a ride is in. One screen renders all four phases, swapping the bottom action bar; a map widget and a rider card are shared across them.

**Tech Stack:** Flutter, Riverpod, Dio, `google_maps_flutter`, `url_launcher` (nav handoff and phone calls).

**Spec:** `docs/superpowers/specs/2026-08-30-driver-app-phase1-design.md` §4.3

## Global Constraints

- **Single stop only: pickup → dropoff.** No waypoints, no A/B/C, no "Mid point" badge. `geo.waypoints` exists in the payload and is deliberately not read.
- **Rider identity is shown in full from acceptance onward** — name, photo, rating, call, chat. The withholding rule applies only to the pre-accept offer card (§6.1).
- **The route polyline comes from `GET /rides/:id` `geo.route`** — the real OSRM geometry dispatch priced. Never call the Directions API for it.
- **`NO_SHOW_TOO_EARLY` carries `seconds_remaining`** (not `seconds`).
- **Money is `Pence`**; the waiting policy sends `per_minute_pence` and `no_show_fee_pence` as int64.
- **Cancel reasons: only `pickable: true` entries appear in the picker.** Never prettify a slug client-side.
- Light theme tokens only; server copy verbatim.
- **Maps API key** ships per-platform via `--dart-define=MAPS_API_KEY=…`, restricted by bundle id / SHA-1 and to the Maps SDK. Never committed.

---

### Task 1: Ride model and the trip repository

**Files:**
- Create: `app/lib/features/trip/data/models/ride.dart`
- Create: `app/lib/features/trip/data/models/waiting_policy.dart`
- Create: `app/lib/features/trip/data/trip_repository.dart`
- Test: `app/test/features/trip/ride_model_test.dart`
- Test: `app/test/features/trip/trip_repository_test.dart`

**Interfaces:**
- Consumes: `ApiClient`, `Pence`, `Result` (Batch 1)
- Produces:
  - `TripPhase` enum (`headingToPickup`, `waiting`, `inTrip`, `completed`, `cancelled`).
  - `GeoPoint(lat, lng, label)`; `RideGeo(pickup, dropoff, route)`.
  - `Rider(id, fullName, avatarUrl, rating, ratingCount, phone)`.
  - `Ride(id, ref, status, phase, geo, rider, chatUnread, pickupEtaSeconds, acceptedAt, arrivedAt, startedAt)` with `.fromJson`.
  - `WaitingPolicy(arrivedAt, freeWaitSeconds, perMinutePence, noShowAfterSeconds, noShowFeePence, billableFrom, currency)` with `.fromJson`, `.isBillable`, `.freeSecondsRemaining`.
  - `TripRepository` — `ride(id)`, `waitingPolicy(id)`, `arrive(id)`, `start(id)`, `complete(id)`, `cancel(id, reasonId)`, `riderContext(id)`, each returning `Result`.
  - Provider `tripRepositoryProvider`.

- [ ] **Step 1: Write the failing model test**

Create `app/test/features/trip/ride_model_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/money.dart';
import 'package:hoppin_driver/features/trip/data/models/ride.dart';
import 'package:hoppin_driver/features/trip/data/models/waiting_policy.dart';

void main() {
  group('Ride', () {
    test('derives the phase from the server status, not from local state', () {
      Ride phaseOf(String status) => Ride.fromJson({
            'id': 'r1',
            'status': status,
            'geo': {
              'pickup': {'lat': 52.58, 'lng': -2.12},
              'dropoff': {'lat': 52.59, 'lng': -2.13},
              'route': <dynamic>[],
            },
          });

      expect(phaseOf('accepted').phase, TripPhase.headingToPickup);
      expect(phaseOf('arrived').phase, TripPhase.waiting);
      expect(phaseOf('in_progress').phase, TripPhase.inTrip);
      expect(phaseOf('completed').phase, TripPhase.completed);
      expect(phaseOf('cancelled').phase, TripPhase.cancelled);
    });

    test('an unrecognised status does not crash the trip screen', () {
      final ride = Ride.fromJson({
        'id': 'r1',
        'status': 'some_new_state',
        'geo': {
          'pickup': {'lat': 1.0, 'lng': 2.0},
          'dropoff': {'lat': 3.0, 'lng': 4.0},
          'route': <dynamic>[],
        },
      });
      expect(ride.phase, TripPhase.headingToPickup);
    });

    test('reads the road-following route the backend persisted', () {
      final ride = Ride.fromJson({
        'id': 'r1',
        'status': 'accepted',
        'geo': {
          'pickup': {'lat': 52.58, 'lng': -2.12, 'label': 'City Centre'},
          'dropoff': {'lat': 52.59, 'lng': -2.13, 'label': 'Station'},
          'route': [
            {'lat': 52.58, 'lng': -2.12},
            {'lat': 52.585, 'lng': -2.125},
            {'lat': 52.59, 'lng': -2.13},
          ],
        },
      });

      expect(ride.geo.route, hasLength(3));
      expect(ride.geo.pickup.label, 'City Centre');
    });

    test('ignores waypoints entirely — the app is single-stop', () {
      final ride = Ride.fromJson({
        'id': 'r1',
        'status': 'accepted',
        'geo': {
          'pickup': {'lat': 1.0, 'lng': 2.0},
          'dropoff': {'lat': 3.0, 'lng': 4.0},
          'waypoints': [
            {'lat': 9.0, 'lng': 9.0}
          ],
          'route': <dynamic>[],
        },
      });

      // There is nowhere in the model to put a waypoint, so a server that
      // starts sending them cannot make the map grow a third pin.
      expect(ride.toString().contains('9.0'), isFalse);
    });

    test('carries the full rider identity, which is allowed after accepting',
        () {
      final ride = Ride.fromJson({
        'id': 'r1',
        'status': 'accepted',
        'ref': 'R-1042',
        'chat_unread': 2,
        'geo': {
          'pickup': {'lat': 1.0, 'lng': 2.0},
          'dropoff': {'lat': 3.0, 'lng': 4.0},
          'route': <dynamic>[],
        },
        'rider': {
          'id': 'u1',
          'full_name': 'Alex Morgan',
          'rating': 4.8,
          'rating_count': 12,
        },
      });

      expect(ride.rider!.fullName, 'Alex Morgan');
      expect(ride.rider!.rating, 4.8);
      expect(ride.ref, 'R-1042');
      expect(ride.chatUnread, 2);
    });

    test('tolerates a ride with no rider block yet', () {
      final ride = Ride.fromJson({
        'id': 'r1',
        'status': 'accepted',
        'geo': {
          'pickup': {'lat': 1.0, 'lng': 2.0},
          'dropoff': {'lat': 3.0, 'lng': 4.0},
          'route': <dynamic>[],
        },
      });
      expect(ride.rider, isNull);
      expect(ride.chatUnread, 0);
    });
  });

  group('WaitingPolicy', () {
    test('parses the charging terms', () {
      final p = WaitingPolicy.fromJson({
        'arrived_at': '2026-08-30T10:00:00Z',
        'free_wait_seconds': 180,
        'per_minute_pence': 30,
        'no_show_after_seconds': 300,
        'no_show_fee_pence': 5900,
        'billable_from': '2026-08-30T10:03:00Z',
        'currency': 'GBP',
      });

      expect(p.freeWaitSeconds, 180);
      expect(p.perMinutePence, const Pence(30));
      expect(p.noShowFeePence, const Pence(5900));
      expect(p.noShowAfterSeconds, 300);
    });

    test('reports free seconds remaining from billable_from', () {
      final p = WaitingPolicy.fromJson({
        'free_wait_seconds': 180,
        'per_minute_pence': 30,
        'no_show_fee_pence': 0,
        'billable_from':
            DateTime.now().toUtc().add(const Duration(seconds: 60)).toIso8601String(),
        'currency': 'GBP',
      });

      expect(p.freeSecondsRemaining, closeTo(60, 2));
      expect(p.isBillable, isFalse);
    });

    test('reports billable once the free period has passed', () {
      final p = WaitingPolicy.fromJson({
        'free_wait_seconds': 180,
        'per_minute_pence': 30,
        'no_show_fee_pence': 0,
        'billable_from': DateTime.now()
            .toUtc()
            .subtract(const Duration(seconds: 10))
            .toIso8601String(),
        'currency': 'GBP',
      });

      expect(p.isBillable, isTrue);
      expect(p.freeSecondsRemaining, 0);
    });

    test('a policy with no billable_from is not billable', () {
      final p = WaitingPolicy.fromJson({
        'free_wait_seconds': 180,
        'per_minute_pence': 30,
        'no_show_fee_pence': 0,
        'currency': 'GBP',
      });
      expect(p.isBillable, isFalse);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/trip/ride_model_test.dart`
Expected: FAIL — model files do not exist

- [ ] **Step 3: Write the models**

Create `app/lib/features/trip/data/models/ride.dart`:

```dart
/// Which screen the driver should be looking at. Derived from the server's
/// `status` on every read rather than advanced locally, so an admin
/// force-cancel or a transition made on another device lands correctly.
enum TripPhase { headingToPickup, waiting, inTrip, completed, cancelled }

class GeoPoint {
  final double lat;
  final double lng;
  final String? label;

  const GeoPoint({required this.lat, required this.lng, this.label});

  factory GeoPoint.fromJson(Map<String, dynamic> json) => GeoPoint(
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        label: json['label'] as String?,
      );
}

/// Pickup, dropoff and the road-following polyline.
///
/// The payload also carries `waypoints`; this model deliberately has no
/// field for them. The app is single-stop by product decision, and a model
/// that cannot hold a third point cannot accidentally draw one.
class RideGeo {
  final GeoPoint pickup;
  final GeoPoint dropoff;
  final List<GeoPoint> route;

  const RideGeo({
    required this.pickup,
    required this.dropoff,
    this.route = const [],
  });

  factory RideGeo.fromJson(Map<String, dynamic> json) => RideGeo(
        pickup: GeoPoint.fromJson(
            Map<String, dynamic>.from(json['pickup'] as Map)),
        dropoff: GeoPoint.fromJson(
            Map<String, dynamic>.from(json['dropoff'] as Map)),
        route: ((json['route'] as List?) ?? const [])
            .map((e) => GeoPoint.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

/// The person being collected. Available only after acceptance — see the
/// offer card for why it is absent before.
class Rider {
  final String id;
  final String fullName;
  final String? avatarUrl;
  final double? rating;
  final int ratingCount;
  final String? phone;

  const Rider({
    required this.id,
    required this.fullName,
    this.avatarUrl,
    this.rating,
    this.ratingCount = 0,
    this.phone,
  });

  factory Rider.fromJson(Map<String, dynamic> json) => Rider(
        id: (json['id'] as String?) ?? '',
        fullName: (json['full_name'] ?? json['name'] ?? '') as String,
        avatarUrl: (json['avatar_url'] ?? json['photo_url']) as String?,
        rating: (json['rating'] as num?)?.toDouble(),
        ratingCount: (json['rating_count'] as num?)?.toInt() ?? 0,
        phone: json['phone'] as String?,
      );
}

class Ride {
  final String id;
  final String? ref;
  final String status;
  final RideGeo geo;
  final Rider? rider;
  final int chatUnread;
  final int? pickupEtaSeconds;
  final DateTime? acceptedAt;
  final DateTime? arrivedAt;
  final DateTime? startedAt;

  const Ride({
    required this.id,
    required this.status,
    required this.geo,
    this.ref,
    this.rider,
    this.chatUnread = 0,
    this.pickupEtaSeconds,
    this.acceptedAt,
    this.arrivedAt,
    this.startedAt,
  });

  /// The server's vocabulary mapped to ours. An unknown status falls back to
  /// the first phase rather than throwing — a driver mid-job must never see
  /// a crash because the backend added a state.
  TripPhase get phase => switch (status) {
        'accepted' || 'assigned' || 'driver_assigned' => TripPhase.headingToPickup,
        'arrived' || 'waiting' => TripPhase.waiting,
        'in_progress' || 'started' || 'on_trip' => TripPhase.inTrip,
        'completed' => TripPhase.completed,
        'cancelled' || 'canceled' => TripPhase.cancelled,
        _ => TripPhase.headingToPickup,
      };

  bool get isFinished =>
      phase == TripPhase.completed || phase == TripPhase.cancelled;

  static DateTime? _time(dynamic v) =>
      v == null ? null : DateTime.tryParse(v as String);

  factory Ride.fromJson(Map<String, dynamic> json) => Ride(
        id: json['id'] as String,
        ref: json['ref'] as String?,
        status: (json['status'] as String?) ?? '',
        geo: RideGeo.fromJson(Map<String, dynamic>.from(json['geo'] as Map)),
        rider: json['rider'] == null
            ? null
            : Rider.fromJson(Map<String, dynamic>.from(json['rider'] as Map)),
        chatUnread: (json['chat_unread'] as num?)?.toInt() ?? 0,
        pickupEtaSeconds: (json['pickup_eta_seconds'] as num?)?.toInt(),
        acceptedAt: _time(json['accepted_at']),
        arrivedAt: _time(json['arrived_at']),
        startedAt: _time(json['started_at']),
      );

  @override
  String toString() => 'Ride($id, $status)';
}
```

Create `app/lib/features/trip/data/models/waiting_policy.dart`:

```dart
import '../../../../core/money.dart';

/// The waiting terms for one ride, from `GET /rides/:id/waiting-policy`.
///
/// `billableFrom` is the important field: it is the instant charging starts,
/// computed server-side. A bare count-up timer would leave the driver
/// guessing when the free period ends.
class WaitingPolicy {
  final DateTime? arrivedAt;
  final int freeWaitSeconds;
  final Pence perMinutePence;
  final int? noShowAfterSeconds;
  final Pence noShowFeePence;
  final DateTime? billableFrom;
  final String currency;

  const WaitingPolicy({
    required this.freeWaitSeconds,
    required this.perMinutePence,
    required this.noShowFeePence,
    this.arrivedAt,
    this.noShowAfterSeconds,
    this.billableFrom,
    this.currency = 'GBP',
  });

  factory WaitingPolicy.fromJson(Map<String, dynamic> json) => WaitingPolicy(
        arrivedAt: json['arrived_at'] == null
            ? null
            : DateTime.tryParse(json['arrived_at'] as String),
        freeWaitSeconds: (json['free_wait_seconds'] as num?)?.toInt() ?? 0,
        perMinutePence: Pence((json['per_minute_pence'] as num?)?.toInt() ?? 0),
        noShowAfterSeconds: (json['no_show_after_seconds'] as num?)?.toInt(),
        noShowFeePence: Pence((json['no_show_fee_pence'] as num?)?.toInt() ?? 0),
        billableFrom: json['billable_from'] == null
            ? null
            : DateTime.tryParse(json['billable_from'] as String),
        currency: (json['currency'] as String?) ?? 'GBP',
      );

  bool get isBillable =>
      billableFrom != null && DateTime.now().toUtc().isAfter(billableFrom!);

  /// Seconds of free waiting left, or 0 once charging has started.
  int get freeSecondsRemaining {
    if (billableFrom == null) return freeWaitSeconds;
    final left = billableFrom!.difference(DateTime.now().toUtc()).inSeconds;
    return left < 0 ? 0 : left;
  }
}
```

- [ ] **Step 4: Write the failing repository test**

Create `app/test/features/trip/trip_repository_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_client.dart';
import 'package:hoppin_driver/core/auth/token_store.dart';
import 'package:hoppin_driver/features/trip/data/models/ride.dart';
import 'package:hoppin_driver/features/trip/data/trip_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockAdapter extends Mock implements HttpClientAdapter {}

void main() {
  setUpAll(() => registerFallbackValue(RequestOptions(path: '/')));

  ResponseBody body(String json, int status) =>
      ResponseBody.fromString(json, status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  const rideJson = '{"id":"r1","status":"accepted","ref":"R-1042",'
      '"geo":{"pickup":{"lat":1.0,"lng":2.0},"dropoff":{"lat":3.0,"lng":4.0},'
      '"route":[]}}';

  late _MockAdapter adapter;
  late TripRepository repo;

  setUp(() {
    adapter = _MockAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    repo = TripRepository(ApiClient(dio, InMemoryTokenStore()));
  });

  test('reads a ride', () async {
    when(() => adapter.fetch(any(), any(), any()))
        .thenAnswer((_) async => body(rideJson, 200));

    final r = await repo.ride('r1');

    expect(r.valueOrNull!.phase, TripPhase.headingToPickup);
    expect(r.valueOrNull!.ref, 'R-1042');
  });

  test('arrive returns the updated ride', () async {
    when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async =>
        body('{"id":"r1","status":"arrived","geo":{"pickup":{"lat":1.0,'
            '"lng":2.0},"dropoff":{"lat":3.0,"lng":4.0},"route":[]}}', 200));

    final r = await repo.arrive('r1');

    expect(r.valueOrNull!.phase, TripPhase.waiting);
  });

  test('a transition out of order surfaces ILLEGAL_TRANSITION', () async {
    when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async =>
        body('{"code":"ILLEGAL_TRANSITION","error":"start before arrive"}',
            409));

    final r = await repo.start('r1');

    expect(r.errorOrNull!.code, 'ILLEGAL_TRANSITION');
  });

  test('an early no-show reports how long is left', () async {
    when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async => body(
        '{"code":"NO_SHOW_TOO_EARLY","error":"wait","seconds_remaining":120}',
        400));

    final r = await repo.cancel('r1', reasonId: 'rider_no_show');

    expect(r.errorOrNull!.code, 'NO_SHOW_TOO_EARLY');
    expect(r.errorOrNull!.fields['seconds_remaining'], 120);
  });

  test('reads the waiting policy', () async {
    when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async => body(
        '{"free_wait_seconds":180,"per_minute_pence":30,'
        '"no_show_fee_pence":5900,"currency":"GBP"}',
        200));

    final r = await repo.waitingPolicy('r1');

    expect(r.valueOrNull!.freeWaitSeconds, 180);
    expect(r.valueOrNull!.perMinutePence.pence, 30);
  });

  test('cancel sends the reason id the picker chose', () async {
    when(() => adapter.fetch(any(), any(), any())).thenAnswer(
        (_) async => body('{"id":"r1","status":"cancelled","geo":{"pickup":'
            '{"lat":1.0,"lng":2.0},"dropoff":{"lat":3.0,"lng":4.0},'
            '"route":[]}}', 200));

    await repo.cancel('r1', reasonId: 'vehicle_issue');

    final sent = verify(() => adapter.fetch(captureAny(), any(), any()))
        .captured
        .first as RequestOptions;
    expect(sent.data['reason_id'], 'vehicle_issue');
  });
}
```

- [ ] **Step 5: Run test to verify it fails**

Run: `cd app && flutter test test/features/trip/trip_repository_test.dart`
Expected: FAIL — `trip_repository.dart` does not exist

- [ ] **Step 6: Write the repository**

Create `app/lib/features/trip/data/trip_repository.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/result.dart';
import 'models/ride.dart';
import 'models/waiting_policy.dart';

class TripRepository {
  final ApiClient _api;
  TripRepository(this._api);

  Future<Result<Ride>> ride(String rideId) => _rideCall(
      () => _api.get<Map<String, dynamic>>('/rides/$rideId'));

  Future<Result<Ride>> arrive(String rideId) => _rideCall(
      () => _api.patch<Map<String, dynamic>>('/rides/$rideId/arrive'));

  Future<Result<Ride>> start(String rideId) => _rideCall(
      () => _api.patch<Map<String, dynamic>>('/rides/$rideId/start'));

  Future<Result<Ride>> complete(String rideId) => _rideCall(
      () => _api.patch<Map<String, dynamic>>('/rides/$rideId/complete'));

  /// `reasonId` comes from the picker, which only ever offers entries the
  /// server marked `pickable: true`.
  Future<Result<Ride>> cancel(String rideId, {required String reasonId}) =>
      _rideCall(() => _api.patch<Map<String, dynamic>>('/rides/$rideId/cancel',
          body: {'reason_id': reasonId}));

  Future<Result<WaitingPolicy>> waitingPolicy(String rideId) async {
    final r =
        await _api.get<Map<String, dynamic>>('/rides/$rideId/waiting-policy');
    return r.when(
      ok: (json) => Ok(WaitingPolicy.fromJson(json)),
      err: (e) => Err(e),
    );
  }

  Future<Result<Map<String, dynamic>>> riderContext(String rideId) =>
      _api.get<Map<String, dynamic>>('/rides/$rideId/rider-context');

  Future<Result<Ride>> _rideCall(
      Future<Result<Map<String, dynamic>>> Function() call) async {
    final r = await call();
    return r.when(
      ok: (json) => Ok(Ride.fromJson(json)),
      err: (e) => Err(e),
    );
  }
}

final tripRepositoryProvider =
    Provider<TripRepository>((ref) => TripRepository(ref.watch(apiClientProvider)));
```

- [ ] **Step 7: Run both tests to verify they pass**

Run: `cd app && flutter test test/features/trip/`
Expected: PASS, 16 tests

- [ ] **Step 8: Commit**

```bash
git add app/lib/features/trip app/test/features/trip
git commit -m "feat: add ride model, waiting policy and trip repository"
```

---

### Task 2: Cancel reasons

**Files:**
- Create: `app/lib/features/trip/data/models/cancel_reason.dart`
- Create: `app/lib/features/trip/data/cancel_reason_repository.dart`
- Test: `app/test/features/trip/cancel_reason_test.dart`

**Interfaces:**
- Consumes: `ApiClient`, `Pence` (Batch 1)
- Produces: `CancelReason(id, text, pickable, penaltyFee, freeCancelSeconds)` with `.fromJson`, `.hasPenalty`; `CancelReasonRepository.forDriver() → Result<List<CancelReason>>` filtered to `pickable`. Provider `cancelReasonRepositoryProvider`.

- [ ] **Step 1: Write the failing test**

Create `app/test/features/trip/cancel_reason_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_client.dart';
import 'package:hoppin_driver/core/auth/token_store.dart';
import 'package:hoppin_driver/features/trip/data/cancel_reason_repository.dart';
import 'package:hoppin_driver/features/trip/data/models/cancel_reason.dart';
import 'package:mocktail/mocktail.dart';

class _MockAdapter extends Mock implements HttpClientAdapter {}

void main() {
  setUpAll(() => registerFallbackValue(RequestOptions(path: '/')));

  ResponseBody body(String json, int status) =>
      ResponseBody.fromString(json, status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  late _MockAdapter adapter;
  late CancelReasonRepository repo;

  setUp(() {
    adapter = _MockAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    repo = CancelReasonRepository(ApiClient(dio, InMemoryTokenStore()));
  });

  test('parses the penny amount, not the deprecated float', () {
    final r = CancelReason.fromJson({
      'id': 'rider_no_show',
      'reason_text': "Rider didn't show up",
      'pickable': true,
      'penalty_fee_amount': 59.0,
      'penalty_fee_pence': 5900,
      'free_cancel_seconds': 300,
    });

    expect(r.penaltyFee!.pence, 5900);
    expect(r.hasPenalty, isTrue);
    expect(r.freeCancelSeconds, 300);
  });

  test('a reason with no penalty reports none', () {
    final r = CancelReason.fromJson({
      'id': 'vehicle_issue',
      'reason_text': 'Vehicle issue',
      'pickable': true,
    });

    expect(r.penaltyFee, isNull);
    expect(r.hasPenalty, isFalse);
  });

  test('the picker never offers a system outcome', () async {
    when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async => body(
        '[{"id":"driver_declined","reason_text":"driver_declined",'
        '"pickable":false},'
        '{"id":"offer_timeout","reason_text":"offer_timeout","pickable":false},'
        '{"id":"vehicle_issue","reason_text":"Vehicle issue","pickable":true}]',
        200));

    final r = await repo.forDriver();

    // The two slugs are system-generated outcomes, not choices. Filtering on
    // the server's flag is what keeps a raw slug off the screen without us
    // prettifying one.
    expect(r.valueOrNull!.map((e) => e.id), ['vehicle_issue']);
  });

  test('reads an envelope as well as a bare array', () async {
    when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async => body(
        '{"reasons":[{"id":"a","reason_text":"A","pickable":true}]}', 200));

    final r = await repo.forDriver();

    expect(r.valueOrNull!.single.id, 'a');
  });

  test('asks for the driver actor', () async {
    when(() => adapter.fetch(any(), any(), any()))
        .thenAnswer((_) async => body('[]', 200));

    await repo.forDriver();

    final sent = verify(() => adapter.fetch(captureAny(), any(), any()))
        .captured
        .first as RequestOptions;
    expect(sent.queryParameters['actor'], 'driver');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/trip/cancel_reason_test.dart`
Expected: FAIL — files do not exist

- [ ] **Step 3: Write the model and repository**

Create `app/lib/features/trip/data/models/cancel_reason.dart`:

```dart
import '../../../../core/money.dart';

/// One selectable cancellation reason.
///
/// `reason_text` is server-owned prose. Two live values (`driver_declined`,
/// `offer_timeout`) are raw slugs describing system outcomes rather than
/// driver choices; the server marks those `pickable: false` and the picker
/// drops them. We never title-case a slug ourselves — that is guesswork
/// that breaks the moment a reason is added.
class CancelReason {
  final String id;
  final String text;
  final bool pickable;
  final Pence? penaltyFee;
  final int? freeCancelSeconds;

  const CancelReason({
    required this.id,
    required this.text,
    required this.pickable,
    this.penaltyFee,
    this.freeCancelSeconds,
  });

  bool get hasPenalty => (penaltyFee?.pence ?? 0) > 0;

  factory CancelReason.fromJson(Map<String, dynamic> json) => CancelReason(
        id: (json['id'] ?? json['code'] ?? '') as String,
        text: (json['reason_text'] ?? json['display_text'] ?? '') as String,
        pickable: json['pickable'] as bool? ?? true,
        // penalty_fee_pence is authoritative; penalty_fee_amount is a
        // deprecated float and is never read.
        penaltyFee: json['penalty_fee_pence'] == null
            ? null
            : Pence((json['penalty_fee_pence'] as num).toInt()),
        freeCancelSeconds: (json['free_cancel_seconds'] as num?)?.toInt(),
      );
}
```

Create `app/lib/features/trip/data/cancel_reason_repository.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/result.dart';
import 'models/cancel_reason.dart';

class CancelReasonRepository {
  final ApiClient _api;
  CancelReasonRepository(this._api);

  /// Only `pickable` reasons reach the picker.
  Future<Result<List<CancelReason>>> forDriver() async {
    final r = await _api
        .get<dynamic>('/cancellation-reasons', query: {'actor': 'driver'});
    return r.when(
      ok: (data) {
        final list = data is Map
            ? ((data['reasons'] as List?) ?? const [])
            : (data as List? ?? const []);
        return Ok(list
            .map((e) =>
                CancelReason.fromJson(Map<String, dynamic>.from(e as Map)))
            .where((r) => r.pickable)
            .toList());
      },
      err: (e) => Err(e),
    );
  }
}

final cancelReasonRepositoryProvider = Provider<CancelReasonRepository>(
    (ref) => CancelReasonRepository(ref.watch(apiClientProvider)));
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/features/trip/cancel_reason_test.dart`
Expected: PASS, 5 tests

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/trip/data app/test/features/trip/cancel_reason_test.dart
git commit -m "feat: add cancel reasons filtered to pickable entries"
```

---

### Task 3: `TripController`

**Files:**
- Create: `app/lib/features/trip/logic/trip_controller.dart`
- Test: `app/test/features/trip/trip_controller_test.dart`

**Interfaces:**
- Consumes: `TripRepository` (Task 1)
- Produces: `TripState(ride, policy, isBusy, error)`; `TripController extends FamilyAsyncNotifier<TripState, String>` with `.refresh()`, `.arrive()`, `.start()`, `.complete()`, `.cancel(reasonId)`. Provider `tripControllerProvider(rideId)`; `tripPollIntervalProvider` (default 10s).

The same disposal and post-await discipline as `HomeController`: every write goes through `_emit`, and state is re-read after each await rather than written onto a stale snapshot. Those were real bugs on Home; they would be worse here, mid-job.

- [ ] **Step 1: Write the failing test**

Create `app/test/features/trip/trip_controller_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_exception.dart';
import 'package:hoppin_driver/core/money.dart';
import 'package:hoppin_driver/core/result.dart';
import 'package:hoppin_driver/features/trip/data/models/ride.dart';
import 'package:hoppin_driver/features/trip/data/models/waiting_policy.dart';
import 'package:hoppin_driver/features/trip/data/trip_repository.dart';
import 'package:hoppin_driver/features/trip/logic/trip_controller.dart';
import 'package:mocktail/mocktail.dart';

class MockTripRepo extends Mock implements TripRepository {}

Ride buildRide(String status) => Ride(
      id: 'r1',
      status: status,
      geo: const RideGeo(
        pickup: GeoPoint(lat: 1, lng: 2),
        dropoff: GeoPoint(lat: 3, lng: 4),
      ),
    );

WaitingPolicy buildPolicy() => const WaitingPolicy(
      freeWaitSeconds: 180,
      perMinutePence: Pence(30),
      noShowFeePence: Pence(5900),
    );

void main() {
  late MockTripRepo repo;

  setUp(() {
    repo = MockTripRepo();
    when(() => repo.waitingPolicy(any()))
        .thenAnswer((_) async => Ok(buildPolicy()));
  });

  ProviderContainer container() {
    final c = ProviderContainer(overrides: [
      tripRepositoryProvider.overrideWithValue(repo),
      tripPollIntervalProvider
          .overrideWithValue(const Duration(milliseconds: 20)),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  test('loads the ride on build', () async {
    when(() => repo.ride('r1'))
        .thenAnswer((_) async => Ok(buildRide('accepted')));

    final c = container();
    final state = await c.read(tripControllerProvider('r1').future);

    expect(state.ride!.phase, TripPhase.headingToPickup);
  });

  test('arriving advances the phase to waiting', () async {
    when(() => repo.ride('r1'))
        .thenAnswer((_) async => Ok(buildRide('accepted')));
    when(() => repo.arrive('r1'))
        .thenAnswer((_) async => Ok(buildRide('arrived')));

    final c = container();
    await c.read(tripControllerProvider('r1').future);
    await c.read(tripControllerProvider('r1').notifier).arrive();

    expect(c.read(tripControllerProvider('r1')).value!.ride!.phase,
        TripPhase.waiting);
  });

  test('ILLEGAL_TRANSITION re-reads the ride rather than guessing', () async {
    when(() => repo.ride('r1'))
        .thenAnswer((_) async => Ok(buildRide('accepted')));
    when(() => repo.start('r1')).thenAnswer(
        (_) async => Err(ApiException('ILLEGAL_TRANSITION', '', 409)));

    final c = container();
    await c.read(tripControllerProvider('r1').future);
    clearInteractions(repo);
    await c.read(tripControllerProvider('r1').notifier).start();

    // The server and the app disagree about the phase; the server wins.
    verify(() => repo.ride('r1')).called(1);
  });

  test('loads the waiting policy once the driver has arrived', () async {
    when(() => repo.ride('r1'))
        .thenAnswer((_) async => Ok(buildRide('arrived')));

    final c = container();
    final state = await c.read(tripControllerProvider('r1').future);

    expect(state.policy, isNotNull);
    expect(state.policy!.perMinutePence.pence, 30);
  });

  test('does not fetch a waiting policy before arrival', () async {
    when(() => repo.ride('r1'))
        .thenAnswer((_) async => Ok(buildRide('accepted')));

    final c = container();
    await c.read(tripControllerProvider('r1').future);

    verifyNever(() => repo.waitingPolicy(any()));
  });

  test('a failed transition surfaces its error and leaves the phase alone',
      () async {
    when(() => repo.ride('r1'))
        .thenAnswer((_) async => Ok(buildRide('arrived')));
    when(() => repo.cancel(any(), reasonId: any(named: 'reasonId'))).thenAnswer(
        (_) async => Err(ApiException('NO_SHOW_TOO_EARLY', '', 400,
            fields: {'seconds_remaining': 120})));

    final c = container();
    await c.read(tripControllerProvider('r1').future);
    final result = await c
        .read(tripControllerProvider('r1').notifier)
        .cancel('rider_no_show');

    expect(result.errorOrNull!.code, 'NO_SHOW_TOO_EARLY');
    expect(c.read(tripControllerProvider('r1')).value!.ride!.phase,
        TripPhase.waiting);
  });

  test('stops polling once the ride is finished', () async {
    when(() => repo.ride('r1'))
        .thenAnswer((_) async => Ok(buildRide('completed')));

    final c = container();
    await c.read(tripControllerProvider('r1').future);
    await Future<void>.delayed(const Duration(milliseconds: 60));

    // One read on build and nothing after: a finished ride cannot change.
    verify(() => repo.ride('r1')).called(1);
  });

  test('a read resolving after disposal does not throw', () async {
    when(() => repo.ride('r1')).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 40));
      return Ok(buildRide('accepted'));
    });

    final c = ProviderContainer(
        overrides: [tripRepositoryProvider.overrideWithValue(repo)]);
    await c.read(tripControllerProvider('r1').future);
    final pending = c.read(tripControllerProvider('r1').notifier).refresh();
    c.dispose();

    await expectLater(pending, completes);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/trip/trip_controller_test.dart`
Expected: FAIL — `trip_controller.dart` does not exist

- [ ] **Step 3: Write the controller**

Create `app/lib/features/trip/logic/trip_controller.dart`:

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/result.dart';
import '../data/models/ride.dart';
import '../data/models/waiting_policy.dart';
import '../data/trip_repository.dart';

class TripState {
  final Ride? ride;
  final WaitingPolicy? policy;
  final bool isBusy;
  final ApiException? error;

  const TripState({this.ride, this.policy, this.isBusy = false, this.error});

  TripState copyWith({
    Ride? ride,
    WaitingPolicy? policy,
    bool? isBusy,
    ApiException? error,
    bool clearError = false,
  }) =>
      TripState(
        ride: ride ?? this.ride,
        policy: policy ?? this.policy,
        isBusy: isBusy ?? this.isBusy,
        error: clearError ? null : (error ?? this.error),
      );

  TripPhase get phase => ride?.phase ?? TripPhase.headingToPickup;
}

/// Slower than the offer poll: a trip in progress changes on the driver's own
/// actions, and the only external event worth catching is a rider or admin
/// cancelling underneath them.
final tripPollIntervalProvider =
    Provider<Duration>((ref) => const Duration(seconds: 10));

/// Owns one ride. The phase is always derived from the server's `status`,
/// never advanced locally, so a cancellation made elsewhere lands correctly.
class TripController extends FamilyAsyncNotifier<TripState, String> {
  Timer? _timer;
  bool _disposed = false;

  TripRepository get _repo => ref.read(tripRepositoryProvider);

  @override
  Future<TripState> build(String rideId) async {
    ref.onDispose(() {
      _disposed = true;
      _timer?.cancel();
    });

    final result = await _repo.ride(rideId);
    final state = await result.when(
      ok: (ride) async => TripState(ride: ride, policy: await _policyFor(ride)),
      err: (e) async => TripState(error: e),
    );
    if (!(state.ride?.isFinished ?? true)) _startPolling();
    return state;
  }

  TripState get _current => state.value ?? const TripState();

  void _emit(TripState next) {
    if (_disposed) return;
    state = AsyncData(next);
  }

  /// The waiting terms only exist once the driver has marked arrival, so
  /// asking earlier would be a guaranteed 404 on every trip.
  Future<WaitingPolicy?> _policyFor(Ride ride) async {
    if (ride.phase != TripPhase.waiting) return null;
    final result = await _repo.waitingPolicy(ride.id);
    return result.valueOrNull;
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(ref.read(tripPollIntervalProvider), (_) {
      if (_current.ride?.isFinished ?? false) {
        _timer?.cancel();
        return;
      }
      refresh();
    });
  }

  Future<void> refresh() async {
    final result = await _repo.ride(arg);
    if (_disposed) return;
    await result.when(
      ok: (ride) async {
        final policy = ride.phase == TripPhase.waiting
            ? (_current.policy ?? await _policyFor(ride))
            : null;
        _emit(_current.copyWith(ride: ride, policy: policy, clearError: true));
        if (ride.isFinished) _timer?.cancel();
      },
      err: (e) async => _emit(_current.copyWith(error: e)),
    );
  }

  Future<Result<Ride>> arrive() => _transition(() => _repo.arrive(arg));
  Future<Result<Ride>> start() => _transition(() => _repo.start(arg));
  Future<Result<Ride>> complete() => _transition(() => _repo.complete(arg));

  Future<Result<Ride>> cancel(String reasonId) =>
      _transition(() => _repo.cancel(arg, reasonId: reasonId));

  Future<Result<Ride>> _transition(Future<Result<Ride>> Function() call) async {
    _emit(_current.copyWith(isBusy: true, clearError: true));
    final result = await call();
    if (_disposed) return result;

    await result.when(
      ok: (ride) async {
        _emit(_current.copyWith(
          ride: ride,
          isBusy: false,
          policy: await _policyFor(ride),
        ));
        if (ride.isFinished) _timer?.cancel();
      },
      err: (e) async {
        _emit(_current.copyWith(isBusy: false, error: e));
        // The app thought the ride was in a state it was not. Re-reading is
        // the only honest recovery — guessing the real phase would be
        // guessing about a job in progress.
        if (e.code == 'ILLEGAL_TRANSITION') await refresh();
      },
    );
    return result;
  }
}

final tripControllerProvider =
    AsyncNotifierProvider.family<TripController, TripState, String>(
        TripController.new);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/features/trip/trip_controller_test.dart`
Expected: PASS, 8 tests

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/trip/logic app/test/features/trip/trip_controller_test.dart
git commit -m "feat: add TripController deriving phase from server status"
```

---

### Task 4: The trip map

**Files:**
- Modify: `app/pubspec.yaml`
- Create: `app/lib/features/trip/ui/widgets/trip_map.dart`
- Modify: `app/android/app/src/main/AndroidManifest.xml`, `app/ios/Runner/AppDelegate.swift`
- Test: `app/test/features/trip/trip_map_test.dart`

**Interfaces:**
- Consumes: `RideGeo` (Task 1)
- Produces: `TripMap(geo, {target})` rendering pickup and dropoff markers plus the route polyline; `TripMap.boundsFor(List<GeoPoint>)` as a testable pure function.

- [ ] **Step 1: Add the dependency**

In `app/pubspec.yaml` add to `dependencies`:

```yaml
  google_maps_flutter: ^2.9.0
  url_launcher: ^6.3.0
```

Run: `cd app && flutter pub get`

- [ ] **Step 2: Write the failing test**

Create `app/test/features/trip/trip_map_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/trip/data/models/ride.dart';
import 'package:hoppin_driver/features/trip/ui/widgets/trip_map.dart';

void main() {
  test('bounds span every point on the route', () {
    final bounds = TripMap.boundsFor(const [
      GeoPoint(lat: 52.58, lng: -2.12),
      GeoPoint(lat: 52.60, lng: -2.20),
      GeoPoint(lat: 52.55, lng: -2.05),
    ]);

    expect(bounds.southwest.latitude, 52.55);
    expect(bounds.southwest.longitude, -2.20);
    expect(bounds.northeast.latitude, 52.60);
    expect(bounds.northeast.longitude, -2.05);
  });

  test('a single point still yields usable bounds', () {
    final bounds =
        TripMap.boundsFor(const [GeoPoint(lat: 52.58, lng: -2.12)]);

    expect(bounds.southwest.latitude, lessThanOrEqualTo(52.58));
    expect(bounds.northeast.latitude, greaterThanOrEqualTo(52.58));
  });

  test('an empty route falls back rather than throwing', () {
    // A ride whose polyline failed to persist still has to render a map.
    expect(() => TripMap.boundsFor(const []), returnsNormally);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `cd app && flutter test test/features/trip/trip_map_test.dart`
Expected: FAIL — `trip_map.dart` does not exist

- [ ] **Step 4: Write the map widget**

Create `app/lib/features/trip/ui/widgets/trip_map.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/theme/colors.dart';
import '../../data/models/ride.dart';

/// Pickup, dropoff and the route between them.
///
/// The polyline is the OSRM geometry the backend persisted at dispatch — the
/// same road route the fare was priced against. We never ask the Directions
/// API for our own, which would draw a line the driver was not paid for.
class TripMap extends StatelessWidget {
  final RideGeo geo;

  /// Which end of the leg to centre on. Pickup while approaching, dropoff
  /// once the rider is aboard.
  final GeoPoint? target;

  const TripMap({super.key, required this.geo, this.target});

  static const _padding = 0.005;

  /// Smallest box containing every point, with a margin so pins are not
  /// flush against the edge. Pure, so the framing is testable without a map.
  static LatLngBounds boundsFor(List<GeoPoint> points) {
    if (points.isEmpty) {
      // Wolverhampton, the operating area — a sane frame for a ride whose
      // geometry failed to persist.
      return LatLngBounds(
        southwest: const LatLng(52.57, -2.14),
        northeast: const LatLng(52.60, -2.10),
      );
    }
    var minLat = points.first.lat, maxLat = points.first.lat;
    var minLng = points.first.lng, maxLng = points.first.lng;
    for (final p in points) {
      if (p.lat < minLat) minLat = p.lat;
      if (p.lat > maxLat) maxLat = p.lat;
      if (p.lng < minLng) minLng = p.lng;
      if (p.lng > maxLng) maxLng = p.lng;
    }
    final pad = points.length == 1 ? _padding : 0.0;
    return LatLngBounds(
      southwest: LatLng(minLat - pad, minLng - pad),
      northeast: LatLng(maxLat + pad, maxLng + pad),
    );
  }

  @override
  Widget build(BuildContext context) {
    final centre = target ?? geo.pickup;
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(centre.lat, centre.lng),
        zoom: 14,
      ),
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      zoomControlsEnabled: false,
      markers: {
        Marker(
          markerId: const MarkerId('pickup'),
          position: LatLng(geo.pickup.lat, geo.pickup.lng),
          infoWindow: InfoWindow(title: geo.pickup.label ?? 'Pickup'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
        Marker(
          markerId: const MarkerId('dropoff'),
          position: LatLng(geo.dropoff.lat, geo.dropoff.lng),
          infoWindow: InfoWindow(title: geo.dropoff.label ?? 'Dropoff'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      },
      polylines: {
        if (geo.route.isNotEmpty)
          Polyline(
            polylineId: const PolylineId('route'),
            points:
                geo.route.map((p) => LatLng(p.lat, p.lng)).toList(),
            color: AppColors.primary,
            width: 5,
          ),
      },
      onMapCreated: (controller) {
        if (geo.route.length > 1) {
          controller.animateCamera(
              CameraUpdate.newLatLngBounds(boundsFor(geo.route), 48));
        }
      },
    );
  }
}
```

- [ ] **Step 5: Declare the API key per platform**

In `app/android/app/src/main/AndroidManifest.xml`, inside `<application>`:

```xml
        <meta-data android:name="com.google.android.geo.API_KEY"
                   android:value="${MAPS_API_KEY}"/>
```

In `app/android/app/build.gradle.kts`, inside `defaultConfig`:

```kotlin
        manifestPlaceholders["MAPS_API_KEY"] =
            (project.findProperty("MAPS_API_KEY") as String?) ?: ""
```

In `app/ios/Runner/AppDelegate.swift`, before `GeneratedPluginRegistrant`:

```swift
import GoogleMaps
// Read from the build environment; never hardcode the key in the repo.
GMSServices.provideAPIKey(
  Bundle.main.object(forInfoDictionaryKey: "MAPS_API_KEY") as? String ?? "")
```

- [ ] **Step 6: Run test to verify it passes**

Run: `cd app && flutter test test/features/trip/trip_map_test.dart`
Expected: PASS, 3 tests

- [ ] **Step 7: Commit**

```bash
git add app/lib/features/trip/ui app/test/features/trip/trip_map_test.dart app/pubspec.yaml app/android app/ios
git commit -m "feat: add trip map drawing the persisted OSRM route"
```

---

### Task 5: The rider card and trip action bar

**Files:**
- Create: `app/lib/features/trip/ui/widgets/rider_card.dart`
- Create: `app/lib/features/trip/ui/widgets/waiting_timer.dart`
- Test: `app/test/features/trip/trip_widgets_test.dart`

**Interfaces:**
- Consumes: `Rider`, `WaitingPolicy` (Task 1)
- Produces: `RiderCard(rider, {chatUnread, onCall, onChat})`; `WaitingTimer(policy)` showing the free period and what happens after.

- [ ] **Step 1: Write the failing test**

Create `app/test/features/trip/trip_widgets_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/money.dart';
import 'package:hoppin_driver/features/trip/data/models/ride.dart';
import 'package:hoppin_driver/features/trip/data/models/waiting_policy.dart';
import 'package:hoppin_driver/features/trip/ui/widgets/rider_card.dart';
import 'package:hoppin_driver/features/trip/ui/widgets/waiting_timer.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('RiderCard', () {
    const rider = Rider(
        id: 'u1', fullName: 'Alex Morgan', rating: 4.8, ratingCount: 12);

    testWidgets('names the person being collected', (tester) async {
      await tester.pumpWidget(wrap(const RiderCard(rider: rider)));

      // Identity is shown in full after acceptance — the withholding rule
      // applies to the offer card only.
      expect(find.text('Alex Morgan'), findsOneWidget);
      expect(find.textContaining('4.8'), findsOneWidget);
    });

    testWidgets('badges the chat button with the unread count',
        (tester) async {
      await tester.pumpWidget(
          wrap(const RiderCard(rider: rider, chatUnread: 3)));

      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('shows no badge when there is nothing unread', (tester) async {
      await tester.pumpWidget(
          wrap(const RiderCard(rider: rider, chatUnread: 0)));

      expect(find.text('0'), findsNothing);
    });

    testWidgets('call and chat fire their callbacks', (tester) async {
      var called = false, chatted = false;
      await tester.pumpWidget(wrap(RiderCard(
        rider: rider,
        onCall: () => called = true,
        onChat: () => chatted = true,
      )));

      await tester.tap(find.byIcon(Icons.phone));
      await tester.tap(find.byIcon(Icons.chat_bubble_outline));

      expect(called, isTrue);
      expect(chatted, isTrue);
    });

    testWidgets('renders a rider with no rating yet', (tester) async {
      await tester.pumpWidget(wrap(
          const RiderCard(rider: Rider(id: 'u2', fullName: 'Sam Patel'))));

      expect(find.text('Sam Patel'), findsOneWidget);
      // A missing rating renders an em dash, never "0.0", which would read
      // as a terrible passenger rather than a new one.
      expect(find.textContaining('0.0'), findsNothing);
    });
  });

  group('WaitingTimer', () {
    testWidgets('states when charging starts, not just elapsed time',
        (tester) async {
      final policy = WaitingPolicy(
        freeWaitSeconds: 180,
        perMinutePence: const Pence(30),
        noShowFeePence: const Pence(5900),
        billableFrom:
            DateTime.now().toUtc().add(const Duration(seconds: 90)),
      );

      await tester.pumpWidget(wrap(WaitingTimer(policy: policy)));

      expect(find.textContaining('free'), findsOneWidget);
      expect(find.textContaining('£0.30'), findsOneWidget);
    });

    testWidgets('says plainly once waiting is being charged', (tester) async {
      final policy = WaitingPolicy(
        freeWaitSeconds: 180,
        perMinutePence: const Pence(30),
        noShowFeePence: const Pence(5900),
        billableFrom:
            DateTime.now().toUtc().subtract(const Duration(seconds: 30)),
      );

      await tester.pumpWidget(wrap(WaitingTimer(policy: policy)));

      expect(find.textContaining('Waiting time is being charged'),
          findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/trip/trip_widgets_test.dart`
Expected: FAIL — widget files do not exist

- [ ] **Step 3: Write the widgets**

Create `app/lib/features/trip/ui/widgets/rider_card.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../data/models/ride.dart';

/// Who the driver is collecting, with the two ways to reach them.
///
/// Full identity is correct here: the driver has accepted and is about to
/// meet a stranger. Withholding applies only before accept/decline.
class RiderCard extends StatelessWidget {
  final Rider rider;
  final int chatUnread;
  final VoidCallback? onCall;
  final VoidCallback? onChat;

  const RiderCard({
    super.key,
    required this.rider,
    this.chatUnread = 0,
    this.onCall,
    this.onChat,
  });

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.border,
                backgroundImage: rider.avatarUrl == null
                    ? null
                    : NetworkImage(rider.avatarUrl!),
                child: rider.avatarUrl == null
                    ? const Icon(Icons.person, color: AppColors.textSecondary)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rider.fullName, style: AppText.heading),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.star,
                            size: 14, color: AppColors.warning),
                        const SizedBox(width: 4),
                        Text(
                          // A rider with no ratings yet shows an em dash;
                          // "0.0" would read as an awful passenger.
                          rider.rating == null
                              ? '—'
                              : '${rider.rating!.toStringAsFixed(1)} (${rider.ratingCount})',
                          style: AppText.caption,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.phone, color: AppColors.positive),
                onPressed: onCall,
              ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline,
                        color: AppColors.primary),
                    onPressed: onChat,
                  ),
                  if (chatUnread > 0)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                          color: AppColors.negative,
                          shape: BoxShape.circle,
                        ),
                        child: Text('$chatUnread',
                            style: AppText.caption.copyWith(
                                color: Colors.white, fontSize: 11)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
}
```

Create `app/lib/features/trip/ui/widgets/waiting_timer.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../data/models/waiting_policy.dart';

/// How long the driver has been waiting, and — the part that matters — when
/// waiting starts costing the rider money. A bare count-up leaves the driver
/// unable to answer the one question a waiting passenger asks.
class WaitingTimer extends StatefulWidget {
  final WaitingPolicy policy;

  const WaitingTimer({super.key, required this.policy});

  @override
  State<WaitingTimer> createState() => _WaitingTimerState();
}

class _WaitingTimerState extends State<WaitingTimer> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  static String _clock(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final policy = widget.policy;
    final billable = policy.isBillable;
    final remaining = policy.freeSecondsRemaining;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (billable ? AppColors.warning : AppColors.info)
            .withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(billable ? Icons.timer : Icons.schedule,
              color: billable ? AppColors.warning : AppColors.info),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              billable
                  ? 'Waiting time is being charged at '
                      '${policy.perMinutePence.format()} per minute.'
                  : '${_clock(remaining)} of free waiting left, then '
                      '${policy.perMinutePence.format()} per minute.',
              style: AppText.caption,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/features/trip/trip_widgets_test.dart`
Expected: PASS, 7 tests

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/trip/ui/widgets app/test/features/trip/trip_widgets_test.dart
git commit -m "feat: add rider card and waiting timer with charging terms"
```

---

### Task 6: The trip screen and the cancel flow

**Files:**
- Create: `app/lib/features/trip/ui/trip_screen.dart`
- Create: `app/lib/features/trip/ui/widgets/cancel_sheet.dart`
- Modify: `app/lib/app.dart`
- Test: `app/test/features/trip/trip_screen_test.dart`

**Interfaces:**
- Consumes: `TripController` (Task 3), `TripMap` (Task 4), `RiderCard` + `WaitingTimer` (Task 5), `CancelReasonRepository` (Task 2)
- Produces: `TripScreen(rideId)` rendering all four phases; `CancelSheet` as a modal bottom sheet. Replaces the `/trip/:rideId` placeholder from Batch 3.

- [ ] **Step 1: Write the failing test**

Create `app/test/features/trip/trip_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_exception.dart';
import 'package:hoppin_driver/core/money.dart';
import 'package:hoppin_driver/core/result.dart';
import 'package:hoppin_driver/features/trip/data/cancel_reason_repository.dart';
import 'package:hoppin_driver/features/trip/data/models/cancel_reason.dart';
import 'package:hoppin_driver/features/trip/data/models/ride.dart';
import 'package:hoppin_driver/features/trip/data/models/waiting_policy.dart';
import 'package:hoppin_driver/features/trip/data/trip_repository.dart';
import 'package:hoppin_driver/features/trip/ui/trip_screen.dart';
import 'package:mocktail/mocktail.dart';

class MockTripRepo extends Mock implements TripRepository {}

class MockReasonRepo extends Mock implements CancelReasonRepository {}

Ride buildRide(String status) => Ride(
      id: 'r1',
      status: status,
      ref: 'R-1042',
      rider: const Rider(id: 'u1', fullName: 'Alex Morgan', rating: 4.8),
      geo: const RideGeo(
        pickup: GeoPoint(lat: 1, lng: 2, label: 'City Centre'),
        dropoff: GeoPoint(lat: 3, lng: 4, label: 'Station'),
      ),
    );

Widget wrap(MockTripRepo trip, MockReasonRepo reasons) => ProviderScope(
      overrides: [
        tripRepositoryProvider.overrideWithValue(trip),
        cancelReasonRepositoryProvider.overrideWithValue(reasons),
      ],
      child: const MaterialApp(home: TripScreen(rideId: 'r1')),
    );

void main() {
  late MockTripRepo trip;
  late MockReasonRepo reasons;

  setUp(() {
    trip = MockTripRepo();
    reasons = MockReasonRepo();
    when(() => trip.waitingPolicy(any())).thenAnswer((_) async => const Ok(
        WaitingPolicy(
            freeWaitSeconds: 180,
            perMinutePence: Pence(30),
            noShowFeePence: Pence(5900))));
    when(() => reasons.forDriver()).thenAnswer((_) async => const Ok([
          CancelReason(
              id: 'vehicle_issue', text: 'Vehicle issue', pickable: true),
          CancelReason(
            id: 'rider_no_show',
            text: "Rider didn't show up",
            pickable: true,
            penaltyFee: Pence(5900),
          ),
        ]));
  });

  testWidgets('offers Arrived while heading to the pickup', (tester) async {
    when(() => trip.ride('r1'))
        .thenAnswer((_) async => Ok(buildRide('accepted')));

    await tester.pumpWidget(wrap(trip, reasons));
    await tester.pumpAndSettle();

    expect(find.text('Arrived at Pickup'), findsOneWidget);
    expect(find.text('Alex Morgan'), findsOneWidget);
  });

  testWidgets('offers Start Trip once arrived, with the charging terms',
      (tester) async {
    when(() => trip.ride('r1'))
        .thenAnswer((_) async => Ok(buildRide('arrived')));

    await tester.pumpWidget(wrap(trip, reasons));
    await tester.pumpAndSettle();

    expect(find.text('Start Trip'), findsOneWidget);
    expect(find.textContaining('free waiting'), findsOneWidget);
  });

  testWidgets('offers Finish Trip while under way', (tester) async {
    when(() => trip.ride('r1'))
        .thenAnswer((_) async => Ok(buildRide('in_progress')));

    await tester.pumpWidget(wrap(trip, reasons));
    await tester.pumpAndSettle();

    expect(find.text('Finish Trip'), findsOneWidget);
  });

  testWidgets('shows the ride reference for support', (tester) async {
    when(() => trip.ride('r1'))
        .thenAnswer((_) async => Ok(buildRide('accepted')));

    await tester.pumpWidget(wrap(trip, reasons));
    await tester.pumpAndSettle();

    expect(find.textContaining('R-1042'), findsOneWidget);
  });

  testWidgets('the cancel sheet lists only pickable reasons', (tester) async {
    when(() => trip.ride('r1'))
        .thenAnswer((_) async => Ok(buildRide('accepted')));

    await tester.pumpWidget(wrap(trip, reasons));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('Vehicle issue'), findsOneWidget);
    expect(find.text("Rider didn't show up"), findsOneWidget);
  });

  testWidgets('a reason carrying a penalty states the exact charge first',
      (tester) async {
    when(() => trip.ride('r1'))
        .thenAnswer((_) async => Ok(buildRide('arrived')));

    await tester.pumpWidget(wrap(trip, reasons));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Rider didn't show up"));
    await tester.pumpAndSettle();

    // The driver sees the amount before the charge, not after.
    expect(find.textContaining('£59.00'), findsOneWidget);
    verifyNever(() => trip.cancel(any(), reasonId: any(named: 'reasonId')));
  });

  testWidgets('an early no-show says how long is left', (tester) async {
    when(() => trip.ride('r1'))
        .thenAnswer((_) async => Ok(buildRide('arrived')));
    when(() => trip.cancel(any(), reasonId: any(named: 'reasonId'))).thenAnswer(
        (_) async => Err(ApiException('NO_SHOW_TOO_EARLY', '', 400,
            fields: {'seconds_remaining': 120})));

    await tester.pumpWidget(wrap(trip, reasons));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Rider didn't show up"));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel ride'));
    await tester.pumpAndSettle();

    expect(find.textContaining('2 min'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/trip/trip_screen_test.dart`
Expected: FAIL — `trip_screen.dart` does not exist

- [ ] **Step 3: Write the cancel sheet**

Create `app/lib/features/trip/ui/widgets/cancel_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../data/cancel_reason_repository.dart';
import '../../data/models/cancel_reason.dart';

/// Reason picker, then a confirmation for any reason that carries a charge.
///
/// Returns the chosen reason id, or null if the driver backed out. Only
/// `pickable` reasons ever reach here, so no slug is displayed and none is
/// prettified client-side.
class CancelSheet extends ConsumerStatefulWidget {
  const CancelSheet({super.key});

  static Future<String?> show(BuildContext context) =>
      showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (_) => const CancelSheet(),
      );

  @override
  ConsumerState<CancelSheet> createState() => _CancelSheetState();
}

class _CancelSheetState extends ConsumerState<CancelSheet> {
  CancelReason? _selected;
  late final Future<List<CancelReason>> _reasons;

  @override
  void initState() {
    super.initState();
    _reasons = ref
        .read(cancelReasonRepositoryProvider)
        .forDriver()
        .then((r) => r.valueOrNull ?? const []);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _selected == null ? _picker() : _confirm(_selected!),
        ),
      );

  Widget _picker() => FutureBuilder<List<CancelReason>>(
        future: _reasons,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const SizedBox(height: 160, child: AppLoading());
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Why are you cancelling?', style: AppText.title),
              const SizedBox(height: 12),
              ...snapshot.data!.map((r) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(r.text, style: AppText.body),
                    subtitle: r.hasPenalty
                        ? Text('${r.penaltyFee!.format()} charge may apply',
                            style: AppText.caption
                                .copyWith(color: AppColors.negative))
                        : null,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => setState(() => _selected = r),
                  )),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Keep the ride'),
              ),
            ],
          );
        },
      );

  Widget _confirm(CancelReason reason) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cancel this ride?', style: AppText.title),
          const SizedBox(height: 8),
          Text(reason.text, style: AppText.bodySecondary),
          if (reason.hasPenalty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.negative.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              // The exact amount, before the driver commits — this is the
              // moment they are agreeing to a charge.
              child: Text(
                'A charge of ${reason.penaltyFee!.format()} may apply to this cancellation.',
                style: AppText.body.copyWith(color: AppColors.negative),
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.negative),
            onPressed: () => Navigator.of(context).pop(reason.id),
            child: const Text('Cancel ride'),
          ),
          TextButton(
            onPressed: () => setState(() => _selected = null),
            child: const Text('Back'),
          ),
        ],
      );
}
```

- [ ] **Step 4: Write the trip screen**

Create `app/lib/features/trip/ui/trip_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app_router.dart';
import '../../../core/api/error_codes.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_loading.dart';
import '../data/models/ride.dart';
import '../logic/trip_controller.dart';
import 'widgets/cancel_sheet.dart';
import 'widgets/rider_card.dart';
import 'widgets/trip_map.dart';
import 'widgets/waiting_timer.dart';

/// One screen for the whole job. The phase comes from the server's status,
/// so the bottom action bar is a function of the ride rather than of local
/// navigation — a ride cancelled elsewhere resolves here on the next read.
class TripScreen extends ConsumerWidget {
  final String rideId;

  const TripScreen({super.key, required this.rideId});

  static const _titles = {
    TripPhase.headingToPickup: 'Heading to pickup',
    TripPhase.waiting: 'Waiting for passenger',
    TripPhase.inTrip: 'On the way',
    TripPhase.completed: 'Trip complete',
    TripPhase.cancelled: 'Trip cancelled',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(tripControllerProvider(rideId));
    final controller = ref.read(tripControllerProvider(rideId).notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[async.value?.phase] ?? 'Trip'),
        actions: [
          if (!(async.value?.ride?.isFinished ?? true))
            IconButton(
              icon: const Icon(Icons.close, color: AppColors.negative),
              onPressed: () => _cancel(context, ref),
            ),
        ],
      ),
      body: async.when(
        loading: () => const AppLoading(),
        error: (e, _) => Center(child: Text('$e', style: AppText.body)),
        data: (state) {
          final ride = state.ride;
          if (ride == null) {
            return AppErrorState(
                error: state.error!, onRetry: controller.refresh);
          }
          return Column(
            children: [
              Expanded(
                child: TripMap(
                  geo: ride.geo,
                  target: ride.phase == TripPhase.inTrip
                      ? ride.geo.dropoff
                      : ride.geo.pickup,
                ),
              ),
              _bottomSheet(context, ref, state, ride),
            ],
          );
        },
      ),
    );
  }

  Widget _bottomSheet(
      BuildContext context, WidgetRef ref, TripState state, Ride ride) {
    final controller = ref.read(tripControllerProvider(rideId).notifier);

    return Container(
      decoration: const BoxDecoration(color: AppColors.surface),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (ride.ref != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(ride.ref!, style: AppText.caption),
              ),
            if (ride.rider != null)
              RiderCard(
                rider: ride.rider!,
                chatUnread: ride.chatUnread,
                onCall: () => _call(ride.rider!.phone),
                onChat: () => context.push('${Routes.trip}/$rideId/chat'),
              ),
            if (ride.phase == TripPhase.waiting && state.policy != null)
              WaitingTimer(policy: state.policy!),
            Padding(
              padding: const EdgeInsets.all(16),
              child: _action(context, ref, state, ride, controller),
            ),
          ],
        ),
      ),
    );
  }

  Widget _action(BuildContext context, WidgetRef ref, TripState state,
      Ride ride, TripController controller) {
    final (label, action) = switch (ride.phase) {
      TripPhase.headingToPickup => ('Arrived at Pickup', controller.arrive),
      TripPhase.waiting => ('Start Trip', controller.start),
      TripPhase.inTrip => ('Finish Trip', controller.complete),
      _ => ('Back to Home', null),
    };

    if (action == null) {
      return FilledButton(
        onPressed: () => context.go(Routes.home),
        child: Text(label),
      );
    }

    return FilledButton(
      onPressed: state.isBusy
          ? null
          : () async {
              final result = await action();
              if (!context.mounted) return;
              result.when(
                ok: (_) {},
                err: (e) => ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(errorCopy(e)))),
              );
            },
      child: Text(label),
    );
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final reasonId = await CancelSheet.show(context);
    if (reasonId == null || !context.mounted) return;

    final result =
        await ref.read(tripControllerProvider(rideId).notifier).cancel(reasonId);
    if (!context.mounted) return;

    result.when(
      ok: (_) => context.go(Routes.home),
      // NO_SHOW_TOO_EARLY renders as a countdown rather than a bare refusal,
      // so the driver knows how long to keep waiting.
      err: (e) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errorCopy(e)))),
    );
  }

  Future<void> _call(String? phone) async {
    if (phone == null) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }
}
```

- [ ] **Step 5: Replace the Batch 3 placeholder route**

In `app/lib/app.dart`, replace the `/trip/:rideId` placeholder `GoRoute` with:

```dart
          GoRoute(
            path: '${Routes.trip}/:rideId',
            builder: (_, state) =>
                TripScreen(rideId: state.pathParameters['rideId']!),
          ),
```

Add the import for `features/trip/ui/trip_screen.dart` and delete `_placeholder` if nothing else uses it.

- [ ] **Step 6: Run the whole suite**

Run: `cd app && flutter test && flutter analyze`
Expected: all PASS, analyzer clean

- [ ] **Step 7: Commit**

```bash
git add app/lib app/test
git commit -m "feat: add the trip screen with all four phases and the cancel flow"
```

---

### Task 7: Ride chat

**Files:**
- Create: `app/lib/features/trip/data/models/ride_message.dart`
- Create: `app/lib/features/trip/data/chat_repository.dart`
- Create: `app/lib/features/trip/logic/chat_controller.dart`
- Create: `app/lib/features/trip/ui/chat_screen.dart`
- Modify: `app/lib/app.dart`
- Test: `app/test/features/trip/chat_test.dart`

**Interfaces:**
- Consumes: `ApiClient` (Batch 1)
- Produces: `RideMessage(id, body, senderRole, status, replyTo, createdAt)` with `.isMine`; `ChatRepository.messages(rideId)` / `.send(rideId, body, replyToId)`; `ChatController` (family on rideId, 5s poll while open); `ChatScreen(rideId)`.

- [ ] **Step 1: Write the failing test**

Create `app/test/features/trip/chat_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_client.dart';
import 'package:hoppin_driver/core/auth/token_store.dart';
import 'package:hoppin_driver/features/trip/data/chat_repository.dart';
import 'package:hoppin_driver/features/trip/data/models/ride_message.dart';
import 'package:mocktail/mocktail.dart';

class _MockAdapter extends Mock implements HttpClientAdapter {}

void main() {
  setUpAll(() => registerFallbackValue(RequestOptions(path: '/')));

  ResponseBody body(String json, int status) =>
      ResponseBody.fromString(json, status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  late _MockAdapter adapter;
  late ChatRepository repo;

  setUp(() {
    adapter = _MockAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    repo = ChatRepository(ApiClient(dio, InMemoryTokenStore()));
  });

  test('marks the driver own messages', () {
    final mine = RideMessage.fromJson({
      'id': 'm1',
      'body': 'On my way',
      'sender_role': 'driver',
      'created_at': '2026-08-30T10:00:00Z',
    });
    final theirs = RideMessage.fromJson({
      'id': 'm2',
      'body': 'Thanks',
      'sender_role': 'rider',
      'created_at': '2026-08-30T10:01:00Z',
    });

    expect(mine.isMine, isTrue);
    expect(theirs.isMine, isFalse);
  });

  test('reads the delivery status', () {
    final m = RideMessage.fromJson({
      'id': 'm1',
      'body': 'Outside',
      'sender_role': 'driver',
      'status': 'read',
      'created_at': '2026-08-30T10:00:00Z',
    });

    expect(m.status, MessageStatus.read);
  });

  test('an unknown status degrades to sent rather than throwing', () {
    final m = RideMessage.fromJson({
      'id': 'm1',
      'body': 'x',
      'sender_role': 'driver',
      'status': 'something_new',
      'created_at': '2026-08-30T10:00:00Z',
    });

    expect(m.status, MessageStatus.sent);
  });

  test('carries the quoted preview when replying', () {
    final m = RideMessage.fromJson({
      'id': 'm2',
      'body': 'Yes',
      'sender_role': 'driver',
      'created_at': '2026-08-30T10:02:00Z',
      'reply_to': {'id': 'm1', 'body': 'Are you close?'},
    });

    expect(m.replyToBody, 'Are you close?');
  });

  test('sends a reply id when quoting', () async {
    when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async => body(
        '{"id":"m3","body":"Yes","sender_role":"driver",'
        '"created_at":"2026-08-30T10:03:00Z"}',
        200));

    await repo.send('r1', 'Yes', replyToId: 'm1');

    final sent = verify(() => adapter.fetch(captureAny(), any(), any()))
        .captured
        .first as RequestOptions;
    expect(sent.data['reply_to_id'], 'm1');
    expect(sent.data['body'], 'Yes');
  });

  test('omits reply_to_id for an ordinary message', () async {
    when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async => body(
        '{"id":"m4","body":"Hi","sender_role":"driver",'
        '"created_at":"2026-08-30T10:04:00Z"}',
        200));

    await repo.send('r1', 'Hi');

    final sent = verify(() => adapter.fetch(captureAny(), any(), any()))
        .captured
        .first as RequestOptions;
    expect(sent.data.containsKey('reply_to_id'), isFalse);
  });

  test('reads a thread', () async {
    when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async => body(
        '{"messages":[{"id":"m1","body":"Hi","sender_role":"rider",'
        '"created_at":"2026-08-30T10:00:00Z"}]}',
        200));

    final r = await repo.messages('r1');

    expect(r.valueOrNull!.single.body, 'Hi');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/trip/chat_test.dart`
Expected: FAIL — chat files do not exist

- [ ] **Step 3: Write the model and repository**

Create `app/lib/features/trip/data/models/ride_message.dart`:

```dart
enum MessageStatus { sent, read }

class RideMessage {
  final String id;
  final String body;
  final String senderRole;
  final MessageStatus status;
  final String? replyToId;
  final String? replyToBody;
  final DateTime createdAt;

  const RideMessage({
    required this.id,
    required this.body,
    required this.senderRole,
    required this.createdAt,
    this.status = MessageStatus.sent,
    this.replyToId,
    this.replyToBody,
  });

  bool get isMine => senderRole == 'driver';

  factory RideMessage.fromJson(Map<String, dynamic> json) {
    final reply = json['reply_to'] as Map?;
    return RideMessage(
      id: json['id'] as String,
      body: (json['body'] as String?) ?? '',
      senderRole: (json['sender_role'] as String?) ?? '',
      status: switch (json['status'] as String?) {
        'read' => MessageStatus.read,
        // Anything unrecognised is treated as merely sent — claiming a
        // message was read when we do not know is the worse error.
        _ => MessageStatus.sent,
      },
      replyToId: (json['reply_to_id'] ?? reply?['id']) as String?,
      replyToBody: reply?['body'] as String?,
      createdAt:
          DateTime.tryParse((json['created_at'] as String?) ?? '') ??
              DateTime.now(),
    );
  }
}
```

Create `app/lib/features/trip/data/chat_repository.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/result.dart';
import 'models/ride_message.dart';

class ChatRepository {
  final ApiClient _api;
  ChatRepository(this._api);

  /// Reading the thread also clears the ride's `chat_unread` badge server-side.
  Future<Result<List<RideMessage>>> messages(String rideId) async {
    final r = await _api.get<dynamic>('/rides/$rideId/messages');
    return r.when(
      ok: (data) {
        final list = data is Map
            ? ((data['messages'] as List?) ?? const [])
            : (data as List? ?? const []);
        return Ok(list
            .map((e) =>
                RideMessage.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList());
      },
      err: (e) => Err(e),
    );
  }

  Future<Result<RideMessage>> send(String rideId, String body,
      {String? replyToId}) async {
    final r = await _api.post<Map<String, dynamic>>(
      '/rides/$rideId/messages',
      body: {
        'body': body,
        if (replyToId != null) 'reply_to_id': replyToId,
      },
    );
    return r.when(
      ok: (json) => Ok(RideMessage.fromJson(json)),
      err: (e) => Err(e),
    );
  }
}

final chatRepositoryProvider = Provider<ChatRepository>(
    (ref) => ChatRepository(ref.watch(apiClientProvider)));
```

- [ ] **Step 4: Write the controller and screen**

Create `app/lib/features/trip/logic/chat_controller.dart`:

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result.dart';
import '../data/chat_repository.dart';
import '../data/models/ride_message.dart';

/// Polls only while the thread is open. There is no socket for the driver
/// app, and a closed thread has the ride's `chat_unread` badge instead.
class ChatController extends FamilyAsyncNotifier<List<RideMessage>, String> {
  Timer? _timer;
  bool _disposed = false;

  @override
  Future<List<RideMessage>> build(String rideId) async {
    ref.onDispose(() {
      _disposed = true;
      _timer?.cancel();
    });
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => refresh());
    final result = await ref.read(chatRepositoryProvider).messages(rideId);
    return result.valueOrNull ?? const [];
  }

  Future<void> refresh() async {
    final result = await ref.read(chatRepositoryProvider).messages(arg);
    if (_disposed) return;
    final messages = result.valueOrNull;
    if (messages != null) state = AsyncData(messages);
  }

  Future<Result<RideMessage>> send(String body, {String? replyToId}) async {
    final result = await ref
        .read(chatRepositoryProvider)
        .send(arg, body, replyToId: replyToId);
    if (!_disposed && result.isOk) await refresh();
    return result;
  }
}

final chatControllerProvider =
    AsyncNotifierProvider.family<ChatController, List<RideMessage>, String>(
        ChatController.new);
```

Create `app/lib/features/trip/ui/chat_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_loading.dart';
import '../data/models/ride_message.dart';
import '../logic/chat_controller.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String rideId;
  const ChatScreen({super.key, required this.rideId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  RideMessage? _replyingTo;
  bool _sending = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    await ref
        .read(chatControllerProvider(widget.rideId).notifier)
        .send(text, replyToId: _replyingTo?.id);
    if (!mounted) return;
    _input.clear();
    setState(() {
      _replyingTo = null;
      _sending = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(chatControllerProvider(widget.rideId));

    return Scaffold(
      appBar: AppBar(title: const Text('Message rider')),
      body: Column(
        children: [
          Expanded(
            child: async.when(
              loading: () => const AppLoading(),
              error: (_, __) => const AppEmptyState(
                  icon: Icons.chat_bubble_outline,
                  title: "Messages aren't available right now"),
              data: (messages) => messages.isEmpty
                  ? const AppEmptyState(
                      icon: Icons.chat_bubble_outline,
                      title: 'No messages yet',
                      message: 'Send a note if you need to reach the rider.')
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (_, i) =>
                          _bubble(messages[messages.length - 1 - i]),
                    ),
            ),
          ),
          if (_replyingTo != null) _replyBanner(),
          _composer(),
        ],
      ),
    );
  }

  Widget _bubble(RideMessage m) => Align(
        alignment: m.isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onLongPress: () => setState(() => _replyingTo = m),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: const BoxConstraints(maxWidth: 280),
            decoration: BoxDecoration(
              color: m.isMine ? AppColors.primary : AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (m.replyToBody != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.background.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(m.replyToBody!,
                        style: AppText.caption, maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ),
                Text(
                  m.body,
                  style: AppText.body.copyWith(
                      color: m.isMine ? Colors.white : AppColors.textPrimary),
                ),
                if (m.isMine)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Icon(
                      m.status == MessageStatus.read
                          ? Icons.done_all
                          : Icons.done,
                      size: 14,
                      color: Colors.white70,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );

  Widget _replyBanner() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: AppColors.background,
        child: Row(
          children: [
            Expanded(
              child: Text('Replying to: ${_replyingTo!.body}',
                  style: AppText.caption, maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => setState(() => _replyingTo = null),
            ),
          ],
        ),
      );

  Widget _composer() => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  enabled: !_sending,
                  decoration: const InputDecoration(
                      hintText: 'Message', border: OutlineInputBorder()),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                icon: const Icon(Icons.send),
                onPressed: _sending ? null : _send,
              ),
            ],
          ),
        ),
      );
}
```

- [ ] **Step 5: Register the route**

In `app/lib/app.dart`, add inside the shell routes:

```dart
          GoRoute(
            path: '${Routes.trip}/:rideId/chat',
            builder: (_, state) =>
                ChatScreen(rideId: state.pathParameters['rideId']!),
          ),
```

- [ ] **Step 6: Run the whole suite**

Run: `cd app && flutter test && flutter analyze`
Expected: all PASS, analyzer clean

- [ ] **Step 7: Commit**

```bash
git add app/lib app/test
git commit -m "feat: add ride chat with read receipts and quoted replies"
```

---

## Batch 4 done when

- `flutter test` passes and `flutter analyze` is clean.
- A driver can move a real ride through arrive → start → complete against `api.hoppin.tech`, with the map drawing the persisted road route.
- The waiting screen states when charging begins, not merely how long has elapsed.
- Cancelling offers only `pickable` reasons, and any reason carrying a fee states the exact amount before the driver commits.
- An early no-show reports the remaining wait rather than a bare refusal.
- No screen renders a third stop, and no Directions API call is made.

**Next:** Batch 5 (Money) — earnings, statement, trips.
