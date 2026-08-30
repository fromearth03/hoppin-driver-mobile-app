# Driver App — Batch 5: Money Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A driver can see what they have earned, every individual credit and charge against them in the server's own words, their trip history including cancellations, and their payout status — with no invented line ever rendered.

**Architecture:** Three repositories over the Batch 1 `ApiClient` — earnings, ledger, trips — each with its own controller. The Statement screen is the one place debt appears; it renders `display_title` and `display_reason` verbatim and never synthesises copy. Trips and the ledger both page by cursor, so a shared `CursorList` widget handles the load-more mechanics once.

**Tech Stack:** Flutter, Riverpod, Dio.

**Spec:** `docs/superpowers/specs/2026-08-30-driver-app-phase1-design.md` §4.4, §4.5, §4.6

## Global Constraints

- **Render a line only if its value is non-zero, or if it is Net.** `tax_pence` and `penalty_pence` are written as literal `0` at settlement, so VAT and penalty rows never appear in a breakdown.
- **Server-owned copy is rendered verbatim** — `display_title`, `display_reason`, `cancel_reason`. Never synthesised from `entry_type`, never prettified from a slug.
- **`/drivers/me/wallet` returns `float64` pounds**, the one endpoint predating the pence convention. Convert with `Pence.fromPounds` at the repository boundary and nowhere else.
- **A negative balance means the driver owes.** Show it plainly and signed. No "auto-deducted from your next payout" copy — the backend deliberately declined to write it and the app must not assert it.
- **Payouts are read-only.** No Retry, no payout-method capture; the operator runs them weekly or monthly.
- **No tips, no bonuses invented.** `recent_bonuses` exists on the wallet and is rendered if populated; tipping does not exist in the product and no row is drawn for it.
- Light theme tokens only.

---

### Task 1: Wallet and earnings

**Files:**
- Create: `app/lib/features/earnings/data/models/wallet.dart`
- Create: `app/lib/features/earnings/data/models/ride_earnings.dart`
- Create: `app/lib/features/earnings/data/earnings_repository.dart`
- Test: `app/test/features/earnings/earnings_repository_test.dart`

**Interfaces:**
- Consumes: `ApiClient`, `Pence`, `Result` (Batch 1)
- Produces:
  - `Payout(id, amount, status, transferredAt, failureReason)`; `Wallet(availableBalance, pendingBalance, currency, lastPayoutAt, recentPayouts, recentBonuses)` with `.owes`.
  - `EarningsLine(label, amount)`; `RideEarnings(base, distance, time, surge, waiting, commission, net)` with `.lines` returning only the non-zero rows plus Net.
  - `EarningsSummary(period, totalPence, tripCount)`.
  - `EarningsRepository.wallet()`, `.summary(period)`, `.rideEarnings(rideId)`.
  - Provider `earningsRepositoryProvider`.

- [ ] **Step 1: Write the failing test**

Create `app/test/features/earnings/earnings_repository_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_client.dart';
import 'package:hoppin_driver/core/auth/token_store.dart';
import 'package:hoppin_driver/core/money.dart';
import 'package:hoppin_driver/features/earnings/data/earnings_repository.dart';
import 'package:hoppin_driver/features/earnings/data/models/ride_earnings.dart';
import 'package:hoppin_driver/features/earnings/data/models/wallet.dart';
import 'package:mocktail/mocktail.dart';

class _MockAdapter extends Mock implements HttpClientAdapter {}

void main() {
  setUpAll(() => registerFallbackValue(RequestOptions(path: '/')));

  ResponseBody body(String json, int status) =>
      ResponseBody.fromString(json, status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  late _MockAdapter adapter;
  late EarningsRepository repo;

  setUp(() {
    adapter = _MockAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    repo = EarningsRepository(ApiClient(dio, InMemoryTokenStore()));
  });

  group('Wallet', () {
    test('converts the float pounds this endpoint still sends', () {
      final w = Wallet.fromJson({
        'available_balance': 210.5,
        'pending_balance': 42.0,
        'currency': 'GBP',
        'recent_payouts': <dynamic>[],
      });

      expect(w.availableBalance, const Pence(21050));
      expect(w.pendingBalance, const Pence(4200));
    });

    test('a negative balance means the driver owes', () {
      final w = Wallet.fromJson({
        'available_balance': -50.0,
        'pending_balance': 0.0,
        'currency': 'GBP',
      });

      expect(w.owes, isTrue);
      expect(w.availableBalance.format(), '−£50.00');
    });

    test('reads payout history including a failure reason', () {
      final w = Wallet.fromJson({
        'available_balance': 0.0,
        'pending_balance': 0.0,
        'currency': 'GBP',
        'recent_payouts': [
          {
            'id': 'p1',
            'amount': 210.5,
            'status': 'paid',
            'transferred_at': '2026-08-25T09:00:00Z'
          },
          {
            'id': 'p2',
            'amount': 88.0,
            'status': 'failed',
            'failure_reason': 'Bank rejected the transfer'
          },
        ],
      });

      expect(w.recentPayouts, hasLength(2));
      expect(w.recentPayouts.first.amount, const Pence(21050));
      expect(w.recentPayouts.last.failureReason, 'Bank rejected the transfer');
    });

    test('a driver with no wallet row reads as zero, not as an error', () {
      final w = Wallet.fromJson({'currency': 'GBP'});

      expect(w.availableBalance.isZero, isTrue);
      expect(w.recentPayouts, isEmpty);
    });
  });

  group('RideEarnings', () {
    test('renders only the lines that carry a value, plus Net', () {
      final e = RideEarnings.fromJson({
        'base_pence': 1405,
        'distance_pence': 305,
        'time_pence': 0,
        'surge_pence': 0,
        'waiting_pence': 90,
        'commission_pence': -360,
        'tax_pence': 0,
        'penalty_pence': 0,
        'net_pence': 1440,
      });

      final labels = e.lines.map((l) => l.label).toList();
      expect(labels, ['Base fare', 'Distance', 'Waiting', 'Commission', 'Net']);
      // tax and penalty are written as literal 0 at settlement; a "VAT £0.00"
      // row would assert a treatment nobody has signed off.
      expect(labels.contains('VAT'), isFalse);
      expect(labels.contains('Penalty'), isFalse);
    });

    test('a historical ride falls back to Net and Commission only', () {
      final e = RideEarnings.fromJson({
        'base_pence': 0,
        'distance_pence': 0,
        'time_pence': 0,
        'surge_pence': 0,
        'waiting_pence': 0,
        'commission_pence': -300,
        'tax_pence': 0,
        'penalty_pence': 0,
        'net_pence': 1200,
      });

      expect(e.lines.map((l) => l.label), ['Commission', 'Net']);
    });

    test('Net renders even when it is zero', () {
      final e = RideEarnings.fromJson({'net_pence': 0});

      expect(e.lines.map((l) => l.label), ['Net']);
    });
  });

  group('EarningsRepository', () {
    test('reads the wallet', () async {
      when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async =>
          body('{"available_balance":210.5,"pending_balance":0.0,'
              '"currency":"GBP"}', 200));

      final r = await repo.wallet();

      expect(r.valueOrNull!.availableBalance.pence, 21050);
    });

    test('asks the summary endpoint for the chosen period', () async {
      when(() => adapter.fetch(any(), any(), any())).thenAnswer(
          (_) async => body('{"total_pence":24000,"trip_count":12}', 200));

      await repo.summary('week');

      final sent = verify(() => adapter.fetch(captureAny(), any(), any()))
          .captured
          .first as RequestOptions;
      expect(sent.queryParameters['period'], 'week');
    });

    test('a ride with no breakdown yet surfaces as an error, not zeros',
        () async {
      when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async =>
          body('{"code":"NOT_FOUND","error":"no earnings"}', 404));

      final r = await repo.rideEarnings('r1');

      expect(r.errorOrNull!.code, 'NOT_FOUND');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/earnings/`
Expected: FAIL — files do not exist

- [ ] **Step 3: Write the models**

Create `app/lib/features/earnings/data/models/wallet.dart`:

```dart
import '../../../../core/money.dart';

class Payout {
  final String id;
  final Pence amount;
  final String status;
  final DateTime? transferredAt;
  final String? failureReason;

  const Payout({
    required this.id,
    required this.amount,
    required this.status,
    this.transferredAt,
    this.failureReason,
  });

  factory Payout.fromJson(Map<String, dynamic> json) => Payout(
        id: (json['id'] as String?) ?? '',
        amount: Pence.fromPounds(((json['amount'] as num?) ?? 0).toDouble()),
        status: (json['status'] as String?) ?? '',
        transferredAt: json['transferred_at'] == null
            ? null
            : DateTime.tryParse(json['transferred_at'] as String),
        failureReason: json['failure_reason'] as String?,
      );
}

class DriverBonus {
  final String label;
  final Pence amount;
  final DateTime? awardedAt;

  const DriverBonus(
      {required this.label, required this.amount, this.awardedAt});

  factory DriverBonus.fromJson(Map<String, dynamic> json) => DriverBonus(
        label: (json['label'] ?? json['reason'] ?? 'Bonus') as String,
        amount: Pence.fromPounds(((json['amount'] as num?) ?? 0).toDouble()),
        awardedAt: json['awarded_at'] == null
            ? null
            : DateTime.tryParse(json['awarded_at'] as String),
      );
}

/// The driver's balance and payout history.
///
/// This endpoint predates the integer-pence convention and still sends float
/// pounds, so it is the one place `Pence.fromPounds` is used. Everything
/// downstream sees integers.
class Wallet {
  final Pence availableBalance;
  final Pence pendingBalance;
  final String currency;
  final DateTime? lastPayoutAt;
  final List<Payout> recentPayouts;
  final List<DriverBonus> recentBonuses;

  const Wallet({
    required this.availableBalance,
    required this.pendingBalance,
    this.currency = 'GBP',
    this.lastPayoutAt,
    this.recentPayouts = const [],
    this.recentBonuses = const [],
  });

  /// Negative means the driver owes the company.
  bool get owes => availableBalance.isNegative;

  factory Wallet.fromJson(Map<String, dynamic> json) => Wallet(
        availableBalance:
            Pence.fromPounds(((json['available_balance'] as num?) ?? 0).toDouble()),
        pendingBalance:
            Pence.fromPounds(((json['pending_balance'] as num?) ?? 0).toDouble()),
        currency: (json['currency'] as String?) ?? 'GBP',
        lastPayoutAt: json['last_payout_at'] == null
            ? null
            : DateTime.tryParse(json['last_payout_at'] as String),
        recentPayouts: ((json['recent_payouts'] as List?) ?? const [])
            .map((e) => Payout.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        recentBonuses: ((json['recent_bonuses'] as List?) ?? const [])
            .map((e) =>
                DriverBonus.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}
```

Create `app/lib/features/earnings/data/models/ride_earnings.dart`:

```dart
import '../../../../core/money.dart';

class EarningsLine {
  final String label;
  final Pence amount;
  const EarningsLine(this.label, this.amount);
}

/// The per-trip breakdown from `GET /rides/:id/earnings`.
///
/// Nine fields come back, but settlement writes `tax_pence` and
/// `penalty_pence` as literal zero — VAT is not modelled and penalties are
/// separate ledger entries. Rendering "VAT £0.00" would assert a tax
/// treatment nobody has signed off, so [lines] omits any zero row. Net is
/// always shown, because a trip that earned nothing is still an answer.
class RideEarnings {
  final Pence base;
  final Pence distance;
  final Pence time;
  final Pence surge;
  final Pence waiting;
  final Pence commission;
  final Pence net;

  const RideEarnings({
    required this.base,
    required this.distance,
    required this.time,
    required this.surge,
    required this.waiting,
    required this.commission,
    required this.net,
  });

  static Pence _p(Map<String, dynamic> json, String key) =>
      Pence((json[key] as num?)?.toInt() ?? 0);

  factory RideEarnings.fromJson(Map<String, dynamic> json) => RideEarnings(
        base: _p(json, 'base_pence'),
        distance: _p(json, 'distance_pence'),
        time: _p(json, 'time_pence'),
        surge: _p(json, 'surge_pence'),
        waiting: _p(json, 'waiting_pence'),
        commission: _p(json, 'commission_pence'),
        net: _p(json, 'net_pence'),
      );

  List<EarningsLine> get lines => [
        if (!base.isZero) EarningsLine('Base fare', base),
        if (!distance.isZero) EarningsLine('Distance', distance),
        if (!time.isZero) EarningsLine('Time', time),
        if (!surge.isZero) EarningsLine('Surge', surge),
        if (!waiting.isZero) EarningsLine('Waiting', waiting),
        if (!commission.isZero) EarningsLine('Commission', commission),
        EarningsLine('Net', net),
      ];
}

class EarningsSummary {
  final Pence total;
  final int tripCount;

  const EarningsSummary({required this.total, this.tripCount = 0});

  factory EarningsSummary.fromJson(Map<String, dynamic> json) =>
      EarningsSummary(
        total: Pence((json['total_pence'] as num?)?.toInt() ?? 0),
        tripCount: (json['trip_count'] as num?)?.toInt() ?? 0,
      );
}
```

- [ ] **Step 4: Write the repository**

Create `app/lib/features/earnings/data/earnings_repository.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/result.dart';
import 'models/ride_earnings.dart';
import 'models/wallet.dart';

class EarningsRepository {
  final ApiClient _api;
  EarningsRepository(this._api);

  Future<Result<Wallet>> wallet() async {
    final r = await _api.get<Map<String, dynamic>>('/drivers/me/wallet');
    return r.when(ok: (json) => Ok(Wallet.fromJson(json)), err: (e) => Err(e));
  }

  /// `period` is one of today | week | month | all.
  Future<Result<EarningsSummary>> summary(String period) async {
    final r = await _api.get<Map<String, dynamic>>(
        '/drivers/me/earnings/summary',
        query: {'period': period});
    return r.when(
      ok: (json) => Ok(EarningsSummary.fromJson(json)),
      err: (e) => Err(e),
    );
  }

  Future<Result<RideEarnings>> rideEarnings(String rideId) async {
    final r = await _api.get<Map<String, dynamic>>('/rides/$rideId/earnings');
    return r.when(
      ok: (json) => Ok(RideEarnings.fromJson(json)),
      err: (e) => Err(e),
    );
  }
}

final earningsRepositoryProvider = Provider<EarningsRepository>(
    (ref) => EarningsRepository(ref.watch(apiClientProvider)));
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd app && flutter test test/features/earnings/`
Expected: PASS, 10 tests

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/earnings app/test/features/earnings
git commit -m "feat: add wallet and per-trip earnings with non-zero line rule"
```

---

### Task 2: The ledger

**Files:**
- Create: `app/lib/features/statement/data/models/ledger_entry.dart`
- Create: `app/lib/features/statement/data/ledger_repository.dart`
- Test: `app/test/features/statement/ledger_test.dart`

**Interfaces:**
- Consumes: `ApiClient`, `Pence`, `Result` (Batch 1)
- Produces: `LedgerEntry(id, createdAt, amount, entryType, displayTitle, displayReason, rideId, runningBalance)` with `.isCredit`; `LedgerPage(balance, entries, nextCursor)`; `LedgerRepository.page({cursor, limit})`, `.summary(period)`. Provider `ledgerRepositoryProvider`.

- [ ] **Step 1: Write the failing test**

Create `app/test/features/statement/ledger_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_client.dart';
import 'package:hoppin_driver/core/auth/token_store.dart';
import 'package:hoppin_driver/features/statement/data/ledger_repository.dart';
import 'package:hoppin_driver/features/statement/data/models/ledger_entry.dart';
import 'package:mocktail/mocktail.dart';

class _MockAdapter extends Mock implements HttpClientAdapter {}

void main() {
  setUpAll(() => registerFallbackValue(RequestOptions(path: '/')));

  ResponseBody body(String json, int status) =>
      ResponseBody.fromString(json, status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  late _MockAdapter adapter;
  late LedgerRepository repo;

  setUp(() {
    adapter = _MockAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    repo = LedgerRepository(ApiClient(dio, InMemoryTokenStore()));
  });

  test('renders the server copy and never synthesises from entry_type', () {
    final e = LedgerEntry.fromJson({
      'id': 'e1',
      'created_at': '2026-08-30T09:12:00Z',
      'amount_pence': -300,
      'entry_type': 'penalty',
      'display_title': 'Late arrival penalty',
      'display_reason': 'A penalty for arriving late to a pickup.',
      'ride_id': 'r1',
      'running_balance_pence': -5000,
    });

    expect(e.displayTitle, 'Late arrival penalty');
    expect(e.displayReason, 'A penalty for arriving late to a pickup.');
    expect(e.amount.pence, -300);
    expect(e.isCredit, isFalse);
    expect(e.runningBalance.pence, -5000);
  });

  test('an unmapped entry keeps the server neutral title', () {
    final e = LedgerEntry.fromJson({
      'id': 'e2',
      'created_at': '2026-08-30T09:12:00Z',
      'amount_pence': 500,
      'entry_type': 'something_new',
      'display_title': 'Adjustment',
      'running_balance_pence': 500,
    });

    // "Adjustment" with no reason is the honest rendering of a row we do not
    // have copy for — inventing one would be worse than a neutral label.
    expect(e.displayTitle, 'Adjustment');
    expect(e.displayReason, isNull);
    expect(e.isCredit, isTrue);
  });

  test('reads a page with its signed balance and cursor', () async {
    when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async => body(
        '{"balance_pence":-5000,"currency":"GBP","entries":['
        '{"id":"e1","created_at":"2026-08-30T09:12:00Z","amount_pence":-300,'
        '"entry_type":"penalty","display_title":"Late arrival penalty",'
        '"running_balance_pence":-5000}],"next_cursor":"abc"}',
        200));

    final r = await repo.page();

    expect(r.valueOrNull!.balance.pence, -5000);
    expect(r.valueOrNull!.entries, hasLength(1));
    expect(r.valueOrNull!.nextCursor, 'abc');
  });

  test('a final page reports no cursor', () async {
    when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async => body(
        '{"balance_pence":0,"currency":"GBP","entries":[],'
        '"next_cursor":null}',
        200));

    final r = await repo.page();

    expect(r.valueOrNull!.nextCursor, isNull);
  });

  test('passes the cursor when paging', () async {
    when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async =>
        body('{"balance_pence":0,"currency":"GBP","entries":[]}', 200));

    await repo.page(cursor: 'abc');

    final sent = verify(() => adapter.fetch(captureAny(), any(), any()))
        .captured
        .first as RequestOptions;
    expect(sent.queryParameters['cursor'], 'abc');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/statement/`
Expected: FAIL — files do not exist

- [ ] **Step 3: Write the model and repository**

Create `app/lib/features/statement/data/models/ledger_entry.dart`:

```dart
import '../../../../core/money.dart';

/// One movement on the driver's account.
///
/// `displayTitle` and `displayReason` are written by the server and rendered
/// verbatim. They are correctable by a backend release rather than an app
/// release, and they deliberately make no VAT or deduction claim — which is
/// exactly why the app must never compose its own copy from `entryType`.
class LedgerEntry {
  final String id;
  final DateTime createdAt;
  final Pence amount;
  final String entryType;
  final String displayTitle;
  final String? displayReason;
  final String? rideId;
  final Pence runningBalance;

  const LedgerEntry({
    required this.id,
    required this.createdAt,
    required this.amount,
    required this.entryType,
    required this.displayTitle,
    required this.runningBalance,
    this.displayReason,
    this.rideId,
  });

  bool get isCredit => amount.pence > 0;

  factory LedgerEntry.fromJson(Map<String, dynamic> json) => LedgerEntry(
        id: json['id'] as String,
        createdAt:
            DateTime.tryParse((json['created_at'] as String?) ?? '') ??
                DateTime.now(),
        amount: Pence((json['amount_pence'] as num?)?.toInt() ?? 0),
        entryType: (json['entry_type'] as String?) ?? '',
        displayTitle: (json['display_title'] as String?) ?? 'Adjustment',
        displayReason: json['display_reason'] as String?,
        rideId: json['ride_id'] as String?,
        runningBalance:
            Pence((json['running_balance_pence'] as num?)?.toInt() ?? 0),
      );
}

class LedgerPage {
  final Pence balance;
  final String currency;
  final List<LedgerEntry> entries;
  final String? nextCursor;

  const LedgerPage({
    required this.balance,
    required this.entries,
    this.currency = 'GBP',
    this.nextCursor,
  });

  factory LedgerPage.fromJson(Map<String, dynamic> json) => LedgerPage(
        balance: Pence((json['balance_pence'] as num?)?.toInt() ?? 0),
        currency: (json['currency'] as String?) ?? 'GBP',
        entries: ((json['entries'] as List?) ?? const [])
            .map((e) =>
                LedgerEntry.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        nextCursor: json['next_cursor'] as String?,
      );
}
```

Create `app/lib/features/statement/data/ledger_repository.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/result.dart';
import 'models/ledger_entry.dart';

class LedgerRepository {
  final ApiClient _api;
  LedgerRepository(this._api);

  Future<Result<LedgerPage>> page({String? cursor, int limit = 50}) async {
    final r = await _api.get<Map<String, dynamic>>('/drivers/me/ledger',
        query: {
          'limit': limit,
          if (cursor != null) 'cursor': cursor,
        });
    return r.when(
      ok: (json) => Ok(LedgerPage.fromJson(json)),
      err: (e) => Err(e),
    );
  }

  Future<Result<Map<String, dynamic>>> summary(String period) =>
      _api.get<Map<String, dynamic>>('/drivers/me/ledger/summary',
          query: {'period': period});
}

final ledgerRepositoryProvider = Provider<LedgerRepository>(
    (ref) => LedgerRepository(ref.watch(apiClientProvider)));
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/features/statement/`
Expected: PASS, 5 tests

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/statement app/test/features/statement
git commit -m "feat: add the ledger with server-owned copy rendered verbatim"
```

---

### Task 3: Driver trips

**Files:**
- Create: `app/lib/features/trips/data/models/driver_trip.dart`
- Create: `app/lib/features/trips/data/trips_repository.dart`
- Test: `app/test/features/trips/trips_repository_test.dart`

**Interfaces:**
- Consumes: `ApiClient`, `Pence`, `Result` (Batch 1)
- Produces: `TripFilter` enum (`all`, `completed`, `cancelled`); `DriverTrip(id, ref, completedAt, status, pickupLabel, dropoffLabel, distanceMiles, earnings, penalty, cancelledBy, cancelReason)` with `.isCancelled`, `.cancelledByLabel`; `TripsPage(trips, nextCursor, hasMore)`; `TripsRepository.page({filter, cursor, cancelledBy})`. Provider `tripsRepositoryProvider`.

- [ ] **Step 1: Write the failing test**

Create `app/test/features/trips/trips_repository_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_client.dart';
import 'package:hoppin_driver/core/auth/token_store.dart';
import 'package:hoppin_driver/features/trips/data/models/driver_trip.dart';
import 'package:hoppin_driver/features/trips/data/trips_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockAdapter extends Mock implements HttpClientAdapter {}

void main() {
  setUpAll(() => registerFallbackValue(RequestOptions(path: '/')));

  ResponseBody body(String json, int status) =>
      ResponseBody.fromString(json, status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  late _MockAdapter adapter;
  late TripsRepository repo;

  setUp(() {
    adapter = _MockAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    repo = TripsRepository(ApiClient(dio, InMemoryTokenStore()));
  });

  test('parses a completed trip', () {
    final t = DriverTrip.fromJson({
      'id': 'r1',
      'ref': 'R-1042',
      'completed_at': '2026-08-30T09:30:00Z',
      'status': 'completed',
      'pickup_label': 'City Centre',
      'dropoff_label': 'Railway Station',
      'distance_miles': 3.2,
      'driver_earnings_pence': 830,
      'penalty_pence': 0,
    });

    expect(t.ref, 'R-1042');
    expect(t.earnings.pence, 830);
    expect(t.isCancelled, isFalse);
    expect(t.penalty.isZero, isTrue);
  });

  test('states who cancelled, in words the driver can act on', () {
    DriverTrip cancelledBy(String who) => DriverTrip.fromJson({
          'id': 'r2',
          'status': 'cancelled',
          'pickup_label': 'A',
          'dropoff_label': 'B',
          'cancelled_by': who,
        });

    expect(cancelledBy('driver').cancelledByLabel, 'You cancelled');
    expect(cancelledBy('rider').cancelledByLabel, 'Cancelled by rider');
    expect(cancelledBy('admin').cancelledByLabel, 'Cancelled by Hoppin');
    // A watchdog timeout is explicitly not the driver's fault, and the
    // wording has to say so — it feeds their cancellation rate otherwise.
    expect(cancelledBy('system').cancelledByLabel, 'Cancelled automatically');
  });

  test('carries the human-readable cancel reason when there is one', () {
    final t = DriverTrip.fromJson({
      'id': 'r2',
      'status': 'cancelled',
      'pickup_label': 'A',
      'dropoff_label': 'B',
      'cancelled_by': 'rider',
      'cancel_reason': "Rider didn't show up",
      'penalty_pence': 5900,
    });

    expect(t.cancelReason, "Rider didn't show up");
    expect(t.penalty.pence, 5900);
  });

  test('a completed trip has no cancellation fields', () {
    final t = DriverTrip.fromJson({
      'id': 'r1',
      'status': 'completed',
      'pickup_label': 'A',
      'dropoff_label': 'B',
    });

    expect(t.cancelledBy, isNull);
    expect(t.cancelledByLabel, isNull);
  });

  test('filters server-side rather than in the client', () async {
    when(() => adapter.fetch(any(), any(), any()))
        .thenAnswer((_) async => body('{"trips":[],"has_more":false}', 200));

    await repo.page(filter: TripFilter.cancelled);

    final sent = verify(() => adapter.fetch(captureAny(), any(), any()))
        .captured
        .first as RequestOptions;
    // Filtering client-side would page fifty rows and display twelve.
    expect(sent.queryParameters['status'], 'cancelled');
  });

  test('omits the status parameter for the All filter', () async {
    when(() => adapter.fetch(any(), any(), any()))
        .thenAnswer((_) async => body('{"trips":[],"has_more":false}', 200));

    await repo.page(filter: TripFilter.all);

    final sent = verify(() => adapter.fetch(captureAny(), any(), any()))
        .captured
        .first as RequestOptions;
    expect(sent.queryParameters.containsKey('status'), isFalse);
  });

  test('can separate cancels the driver made from cancels made on them',
      () async {
    when(() => adapter.fetch(any(), any(), any()))
        .thenAnswer((_) async => body('{"trips":[],"has_more":false}', 200));

    await repo.page(filter: TripFilter.cancelled, cancelledBy: 'others');

    final sent = verify(() => adapter.fetch(captureAny(), any(), any()))
        .captured
        .first as RequestOptions;
    expect(sent.queryParameters['cancelled_by'], 'others');
  });

  test('reads the cursor for the next page', () async {
    when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async => body(
        '{"trips":[],"next_cursor":"2026-08-29T00:00:00Z","has_more":true}',
        200));

    final r = await repo.page();

    expect(r.valueOrNull!.nextCursor, '2026-08-29T00:00:00Z');
    expect(r.valueOrNull!.hasMore, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/trips/`
Expected: FAIL — files do not exist

- [ ] **Step 3: Write the model and repository**

Create `app/lib/features/trips/data/models/driver_trip.dart`:

```dart
import '../../../../core/money.dart';

enum TripFilter { all, completed, cancelled }

class DriverTrip {
  final String id;
  final String? ref;
  final DateTime? completedAt;
  final String status;
  final String pickupLabel;
  final String dropoffLabel;
  final double? distanceMiles;
  final Pence earnings;
  final Pence penalty;

  /// `driver` | `rider` | `admin` | `system`, null on a completed trip.
  final String? cancelledBy;

  /// Server-owned prose. Rendered verbatim when present.
  final String? cancelReason;

  const DriverTrip({
    required this.id,
    required this.status,
    required this.pickupLabel,
    required this.dropoffLabel,
    required this.earnings,
    required this.penalty,
    this.ref,
    this.completedAt,
    this.distanceMiles,
    this.cancelledBy,
    this.cancelReason,
  });

  bool get isCancelled => status == 'cancelled' || status == 'canceled';

  /// Who cancelled, in words. This is the first question a driver has about
  /// a cancelled trip — and `system` matters most, because a matching
  /// timeout is explicitly not their fault even though it appears in their
  /// history.
  String? get cancelledByLabel => switch (cancelledBy) {
        'driver' => 'You cancelled',
        'rider' => 'Cancelled by rider',
        'admin' => 'Cancelled by Hoppin',
        'system' => 'Cancelled automatically',
        _ => null,
      };

  factory DriverTrip.fromJson(Map<String, dynamic> json) => DriverTrip(
        id: json['id'] as String,
        ref: json['ref'] as String?,
        completedAt: json['completed_at'] == null
            ? null
            : DateTime.tryParse(json['completed_at'] as String),
        status: (json['status'] as String?) ?? '',
        pickupLabel: (json['pickup_label'] as String?) ?? '',
        dropoffLabel: (json['dropoff_label'] as String?) ?? '',
        distanceMiles: (json['distance_miles'] as num?)?.toDouble(),
        earnings:
            Pence((json['driver_earnings_pence'] as num?)?.toInt() ?? 0),
        penalty: Pence((json['penalty_pence'] as num?)?.toInt() ?? 0),
        cancelledBy: json['cancelled_by'] as String?,
        cancelReason: json['cancel_reason'] as String?,
      );
}

class TripsPage {
  final List<DriverTrip> trips;
  final String? nextCursor;
  final bool hasMore;

  const TripsPage({
    required this.trips,
    this.nextCursor,
    this.hasMore = false,
  });

  factory TripsPage.fromJson(Map<String, dynamic> json) => TripsPage(
        trips: ((json['trips'] as List?) ?? const [])
            .map((e) => DriverTrip.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        nextCursor: json['next_cursor'] as String?,
        hasMore: json['has_more'] as bool? ?? false,
      );
}
```

Create `app/lib/features/trips/data/trips_repository.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/result.dart';
import 'models/driver_trip.dart';

class TripsRepository {
  final ApiClient _api;
  TripsRepository(this._api);

  /// Filtering is server-side: doing it in the client would fetch fifty rows
  /// and display twelve, and paging would then be meaningless.
  Future<Result<TripsPage>> page({
    TripFilter filter = TripFilter.all,
    String? cursor,
    String? cancelledBy,
    int limit = 50,
  }) async {
    final r = await _api.get<Map<String, dynamic>>('/drivers/me/trips', query: {
      'limit': limit,
      if (filter == TripFilter.completed) 'status': 'completed',
      if (filter == TripFilter.cancelled) 'status': 'cancelled',
      if (cursor != null) 'cursor': cursor,
      if (cancelledBy != null) 'cancelled_by': cancelledBy,
    });
    return r.when(
      ok: (json) => Ok(TripsPage.fromJson(json)),
      err: (e) => Err(e),
    );
  }
}

final tripsRepositoryProvider = Provider<TripsRepository>(
    (ref) => TripsRepository(ref.watch(apiClientProvider)));
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/features/trips/`
Expected: PASS, 8 tests

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/trips app/test/features/trips
git commit -m "feat: add driver trips with cancellation attribution"
```

---

### Task 4: A shared cursor-paged list

**Files:**
- Create: `app/lib/shared/widgets/cursor_list.dart`
- Test: `app/test/shared/cursor_list_test.dart`

**Interfaces:**
- Consumes: nothing
- Produces: `CursorList<T>({items, hasMore, isLoadingMore, onLoadMore, itemBuilder, separatorBuilder, emptyState, header})`. Used by both the Statement and Trips screens.

- [ ] **Step 1: Write the failing test**

Create `app/test/shared/cursor_list_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/shared/widgets/cursor_list.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('renders each item', (tester) async {
    await tester.pumpWidget(wrap(CursorList<String>(
      items: const ['a', 'b', 'c'],
      itemBuilder: (_, item) => Text(item),
    )));

    expect(find.text('a'), findsOneWidget);
    expect(find.text('c'), findsOneWidget);
  });

  testWidgets('shows the empty state instead of a blank screen',
      (tester) async {
    await tester.pumpWidget(wrap(CursorList<String>(
      items: const [],
      itemBuilder: (_, item) => Text(item),
      emptyState: const Text('No cancelled trips'),
    )));

    expect(find.text('No cancelled trips'), findsOneWidget);
  });

  testWidgets('offers load-more only when there is another page',
      (tester) async {
    await tester.pumpWidget(wrap(CursorList<String>(
      items: const ['a'],
      hasMore: true,
      onLoadMore: () {},
      itemBuilder: (_, item) => Text(item),
    )));
    expect(find.text('Load more'), findsOneWidget);

    await tester.pumpWidget(wrap(CursorList<String>(
      items: const ['a'],
      itemBuilder: (_, item) => Text(item),
    )));
    expect(find.text('Load more'), findsNothing);
  });

  testWidgets('load-more fires once and then shows progress', (tester) async {
    var calls = 0;
    await tester.pumpWidget(wrap(CursorList<String>(
      items: const ['a'],
      hasMore: true,
      onLoadMore: () => calls++,
      itemBuilder: (_, item) => Text(item),
    )));

    await tester.tap(find.text('Load more'));
    expect(calls, 1);

    await tester.pumpWidget(wrap(CursorList<String>(
      items: const ['a'],
      hasMore: true,
      isLoadingMore: true,
      onLoadMore: () => calls++,
      itemBuilder: (_, item) => Text(item),
    )));
    // A second tap while the page is in flight would duplicate the request.
    expect(find.text('Load more'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('renders a header above the list', (tester) async {
    await tester.pumpWidget(wrap(CursorList<String>(
      items: const ['a'],
      header: const Text('Balance'),
      itemBuilder: (_, item) => Text(item),
    )));

    expect(find.text('Balance'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/shared/cursor_list_test.dart`
Expected: FAIL — `cursor_list.dart` does not exist

- [ ] **Step 3: Write the widget**

Create `app/lib/shared/widgets/cursor_list.dart`:

```dart
import 'package:flutter/material.dart';

import '../../core/theme/typography.dart';

/// A list backed by cursor pagination.
///
/// Both the statement and trip history page the same way, so the load-more
/// mechanics — and the rule that a page in flight cannot be requested twice
/// — live in one place.
class CursorList<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(BuildContext, T) itemBuilder;
  final bool hasMore;
  final bool isLoadingMore;
  final VoidCallback? onLoadMore;
  final Widget? emptyState;
  final Widget? header;
  final Future<void> Function()? onRefresh;

  const CursorList({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.onLoadMore,
    this.emptyState,
    this.header,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final list = ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      // header + items + footer
      itemCount: (header == null ? 0 : 1) + items.length + 1,
      itemBuilder: (context, index) {
        if (header != null && index == 0) return header!;
        final offset = header == null ? 0 : 1;
        final i = index - offset;

        if (i < items.length) return itemBuilder(context, items[i]);

        if (items.isEmpty && emptyState != null) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 64),
            child: emptyState!,
          );
        }
        if (isLoadingMore) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (hasMore && onLoadMore != null) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: TextButton(
                onPressed: onLoadMore,
                child: Text('Load more', style: AppText.body),
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );

    if (onRefresh == null) return list;
    return RefreshIndicator(onRefresh: onRefresh!, child: list);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/shared/cursor_list_test.dart`
Expected: PASS, 5 tests

- [ ] **Step 5: Commit**

```bash
git add app/lib/shared/widgets/cursor_list.dart app/test/shared/cursor_list_test.dart
git commit -m "feat: add a shared cursor-paged list"
```

---

### Task 5: The Statement screen

**Files:**
- Create: `app/lib/features/statement/logic/statement_controller.dart`
- Create: `app/lib/features/statement/ui/statement_screen.dart`
- Create: `app/lib/features/statement/ui/widgets/ledger_row.dart`
- Modify: `app/lib/app.dart`
- Test: `app/test/features/statement/statement_screen_test.dart`

**Interfaces:**
- Consumes: `LedgerRepository` (Task 2), `CursorList` (Task 4)
- Produces: `StatementState(balance, entries, nextCursor, isLoadingMore)`; `StatementController`; `StatementScreen`; `LedgerRow(entry, {onDispute})`. Route `Routes.statement`.

- [ ] **Step 1: Write the failing test**

Create `app/test/features/statement/statement_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/money.dart';
import 'package:hoppin_driver/core/result.dart';
import 'package:hoppin_driver/features/statement/data/ledger_repository.dart';
import 'package:hoppin_driver/features/statement/data/models/ledger_entry.dart';
import 'package:hoppin_driver/features/statement/ui/statement_screen.dart';
import 'package:mocktail/mocktail.dart';

class MockLedgerRepo extends Mock implements LedgerRepository {}

LedgerEntry entry({
  int amount = -300,
  String title = 'Late arrival penalty',
  String? reason = 'A penalty for arriving late to a pickup.',
}) =>
    LedgerEntry(
      id: 'e1',
      createdAt: DateTime.utc(2026, 8, 30, 9, 12),
      amount: Pence(amount),
      entryType: 'penalty',
      displayTitle: title,
      displayReason: reason,
      runningBalance: const Pence(-5000),
    );

Widget wrap(MockLedgerRepo repo) => ProviderScope(
      overrides: [ledgerRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: StatementScreen()),
    );

void main() {
  late MockLedgerRepo repo;
  setUp(() => repo = MockLedgerRepo());

  testWidgets('shows a negative balance plainly and signed', (tester) async {
    when(() => repo.page(cursor: any(named: 'cursor'))).thenAnswer(
        (_) async => Ok(LedgerPage(balance: const Pence(-5000), entries: [entry()])));

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    // Debt is stated, not euphemised.
    expect(find.text('−£50.00'), findsOneWidget);
  });

  testWidgets('renders the server title and reason verbatim', (tester) async {
    when(() => repo.page(cursor: any(named: 'cursor'))).thenAnswer(
        (_) async => Ok(LedgerPage(balance: const Pence(-5000), entries: [entry()])));

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('Late arrival penalty'), findsOneWidget);
    expect(
        find.text('A penalty for arriving late to a pickup.'), findsOneWidget);
  });

  testWidgets('never asserts a deduction the backend refused to write',
      (tester) async {
    when(() => repo.page(cursor: any(named: 'cursor'))).thenAnswer(
        (_) async => Ok(LedgerPage(balance: const Pence(-5000), entries: [entry()])));

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    expect(find.textContaining('deducted'), findsNothing);
    expect(find.textContaining('VAT'), findsNothing);
  });

  testWidgets('a positive balance is what the company owes', (tester) async {
    when(() => repo.page(cursor: any(named: 'cursor'))).thenAnswer((_) async =>
        Ok(LedgerPage(
            balance: const Pence(21050),
            entries: [entry(amount: 830, title: 'Trip earnings', reason: null)])));

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('£210.50'), findsOneWidget);
    expect(find.textContaining('owe'), findsNothing);
  });

  testWidgets('offers Dispute on a charge but not on a credit', (tester) async {
    when(() => repo.page(cursor: any(named: 'cursor'))).thenAnswer((_) async =>
        Ok(LedgerPage(balance: const Pence(-5000), entries: [
          entry(),
          entry(amount: 830, title: 'Trip earnings', reason: null),
        ])));

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    // Disputing money you were paid makes no sense; only charges get it.
    expect(find.text('Dispute'), findsOneWidget);
  });

  testWidgets('an empty statement says so', (tester) async {
    when(() => repo.page(cursor: any(named: 'cursor'))).thenAnswer(
        (_) async => const Ok(LedgerPage(balance: Pence(0), entries: [])));

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    expect(find.textContaining('No entries'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/statement/statement_screen_test.dart`
Expected: FAIL — screen files do not exist

- [ ] **Step 3: Write the controller**

Create `app/lib/features/statement/logic/statement_controller.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/money.dart';
import '../data/ledger_repository.dart';
import '../data/models/ledger_entry.dart';

class StatementState {
  final Pence balance;
  final List<LedgerEntry> entries;
  final String? nextCursor;
  final bool isLoadingMore;
  final ApiException? error;

  const StatementState({
    this.balance = const Pence(0),
    this.entries = const [],
    this.nextCursor,
    this.isLoadingMore = false,
    this.error,
  });

  bool get hasMore => nextCursor != null;

  StatementState copyWith({
    Pence? balance,
    List<LedgerEntry>? entries,
    String? nextCursor,
    bool? isLoadingMore,
    ApiException? error,
    bool clearCursor = false,
    bool clearError = false,
  }) =>
      StatementState(
        balance: balance ?? this.balance,
        entries: entries ?? this.entries,
        nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        error: clearError ? null : (error ?? this.error),
      );
}

class StatementController extends AsyncNotifier<StatementState> {
  bool _disposed = false;

  @override
  Future<StatementState> build() async {
    ref.onDispose(() => _disposed = true);
    final result = await ref.read(ledgerRepositoryProvider).page();
    return result.when(
      ok: (page) => StatementState(
        balance: page.balance,
        entries: page.entries,
        nextCursor: page.nextCursor,
      ),
      err: (e) => StatementState(error: e),
    );
  }

  StatementState get _current => state.value ?? const StatementState();

  void _emit(StatementState next) {
    if (_disposed) return;
    state = AsyncData(next);
  }

  Future<void> refresh() async {
    final result = await ref.read(ledgerRepositoryProvider).page();
    result.when(
      ok: (page) => _emit(StatementState(
        balance: page.balance,
        entries: page.entries,
        nextCursor: page.nextCursor,
      )),
      err: (e) => _emit(_current.copyWith(error: e)),
    );
  }

  Future<void> loadMore() async {
    final cursor = _current.nextCursor;
    // Guarded rather than merely hidden in the UI: a double tap or a rebuild
    // mid-flight would otherwise append the same page twice.
    if (cursor == null || _current.isLoadingMore) return;

    _emit(_current.copyWith(isLoadingMore: true));
    final result =
        await ref.read(ledgerRepositoryProvider).page(cursor: cursor);
    result.when(
      ok: (page) => _emit(_current.copyWith(
        entries: [..._current.entries, ...page.entries],
        nextCursor: page.nextCursor,
        clearCursor: page.nextCursor == null,
        isLoadingMore: false,
      )),
      err: (e) => _emit(_current.copyWith(isLoadingMore: false, error: e)),
    );
  }
}

final statementControllerProvider =
    AsyncNotifierProvider<StatementController, StatementState>(
        StatementController.new);
```

- [ ] **Step 4: Write the row and screen**

Create `app/lib/features/statement/ui/widgets/ledger_row.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../data/models/ledger_entry.dart';

/// One movement, in the server's words.
///
/// Nothing here composes copy: `displayTitle` and `displayReason` are printed
/// as received. Dispute is a per-row action so the support ticket cites the
/// exact entry rather than asking the driver to re-identify it.
class LedgerRow extends StatelessWidget {
  final LedgerEntry entry;
  final void Function(LedgerEntry)? onDispute;

  const LedgerRow({super.key, required this.entry, this.onDispute});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(entry.displayTitle, style: AppText.body),
                ),
                Text(
                  entry.amount.formatSigned(),
                  style: AppText.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: entry.isCredit
                        ? AppColors.positive
                        : AppColors.negative,
                  ),
                ),
              ],
            ),
            if (entry.displayReason != null) ...[
              const SizedBox(height: 4),
              Text(entry.displayReason!, style: AppText.caption),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '${DateFormat('d MMM').format(entry.createdAt)} · '
                  'Balance ${entry.runningBalance.format()}',
                  style: AppText.caption,
                ),
                const Spacer(),
                // Only a charge can be disputed — offering it on money the
                // driver was paid would be nonsense.
                if (!entry.isCredit && onDispute != null)
                  TextButton(
                    onPressed: () => onDispute!(entry),
                    child: const Text('Dispute'),
                  ),
              ],
            ),
            const Divider(height: 20, color: AppColors.border),
          ],
        ),
      );
}
```

Create `app/lib/features/statement/ui/statement_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_loading.dart';
import '../../../shared/widgets/cursor_list.dart';
import '../data/models/ledger_entry.dart';
import '../logic/statement_controller.dart';
import 'widgets/ledger_row.dart';

/// Both money directions in one place. A negative balance is what the driver
/// owes; a positive one is what the company owes them. The figure is stated
/// plainly — never softened, and never accompanied by a claim about how it
/// will be collected.
class StatementScreen extends ConsumerWidget {
  const StatementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(statementControllerProvider);
    final controller = ref.read(statementControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Statement')),
      body: async.when(
        loading: () => const AppLoading(),
        error: (e, _) => Center(child: Text('$e', style: AppText.body)),
        data: (state) {
          if (state.entries.isEmpty && state.error != null) {
            return AppErrorState(
                error: state.error!, onRetry: controller.refresh);
          }
          return CursorList<LedgerEntry>(
            items: state.entries,
            hasMore: state.hasMore,
            isLoadingMore: state.isLoadingMore,
            onLoadMore: controller.loadMore,
            onRefresh: controller.refresh,
            header: _balanceHeader(state),
            emptyState: const AppEmptyState(
              icon: Icons.receipt_long,
              title: 'No entries yet',
              message: 'Earnings and charges will appear here.',
            ),
            itemBuilder: (_, entry) => LedgerRow(
              entry: entry,
              onDispute: (e) => _dispute(context, e),
            ),
          );
        },
      ),
    );
  }

  Widget _balanceHeader(StatementState state) {
    final owes = state.balance.isNegative;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(owes ? 'You owe' : 'Your balance', style: AppText.caption),
          const SizedBox(height: 4),
          Text(
            state.balance.format(),
            style: AppText.money.copyWith(
              color: owes ? AppColors.negative : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  void _dispute(BuildContext context, LedgerEntry entry) {
    // Files a support ticket citing this ledger entry — wired in Batch 7
    // alongside the rest of the support surface.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Disputing "${entry.displayTitle}"')),
    );
  }
}
```

- [ ] **Step 5: Register the route**

In `app/lib/app.dart`, replace the Statement placeholder (or add, if absent) inside the shell routes:

```dart
          GoRoute(
              path: Routes.statement,
              builder: (_, __) => const StatementScreen()),
```

- [ ] **Step 6: Run test to verify it passes**

Run: `cd app && flutter test test/features/statement/`
Expected: PASS, 11 tests

- [ ] **Step 7: Commit**

```bash
git add app/lib app/test
git commit -m "feat: add the statement screen showing both money directions"
```

---

### Task 6: The Trips screen

**Files:**
- Create: `app/lib/features/trips/logic/trips_controller.dart`
- Create: `app/lib/features/trips/ui/trips_screen.dart`
- Create: `app/lib/features/trips/ui/widgets/trip_row.dart`
- Modify: `app/lib/app.dart`
- Test: `app/test/features/trips/trips_screen_test.dart`

**Interfaces:**
- Consumes: `TripsRepository` (Task 3), `CursorList` (Task 4)
- Produces: `TripsState(filter, trips, nextCursor, isLoadingMore)`; `TripsController` with `.setFilter()`, `.loadMore()`; `TripsScreen`; `TripRow(trip)`; `groupByDay(List<DriverTrip>)`. Route `Routes.trips`.

- [ ] **Step 1: Write the failing test**

Create `app/test/features/trips/trips_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/money.dart';
import 'package:hoppin_driver/core/result.dart';
import 'package:hoppin_driver/features/trips/data/models/driver_trip.dart';
import 'package:hoppin_driver/features/trips/data/trips_repository.dart';
import 'package:hoppin_driver/features/trips/ui/trips_screen.dart';
import 'package:mocktail/mocktail.dart';

class MockTripsRepo extends Mock implements TripsRepository {}

DriverTrip completed() => DriverTrip(
      id: 'r1',
      ref: 'R-1042',
      status: 'completed',
      pickupLabel: 'City Centre',
      dropoffLabel: 'Railway Station',
      distanceMiles: 3.2,
      earnings: const Pence(830),
      penalty: const Pence(0),
      completedAt: DateTime.now(),
    );

DriverTrip cancelled({int penalty = 5900, String by = 'rider'}) => DriverTrip(
      id: 'r2',
      ref: 'R-1038',
      status: 'cancelled',
      pickupLabel: 'Bilston Road',
      dropoffLabel: 'City Centre',
      earnings: const Pence(0),
      penalty: Pence(penalty),
      cancelledBy: by,
      completedAt: DateTime.now(),
    );

Widget wrap(MockTripsRepo repo) => ProviderScope(
      overrides: [tripsRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: TripsScreen()),
    );

void main() {
  late MockTripsRepo repo;
  setUp(() => repo = MockTripsRepo());

  void stub(List<DriverTrip> trips) {
    when(() => repo.page(
        filter: any(named: 'filter'),
        cursor: any(named: 'cursor'))).thenAnswer((_) async => Ok(TripsPage(trips: trips)));
  }

  testWidgets('shows the three filters', (tester) async {
    stub([completed()]);

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Cancelled'), findsOneWidget);
  });

  testWidgets('shows the reference so a driver can quote it', (tester) async {
    stub([completed()]);

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    expect(find.textContaining('R-1042'), findsOneWidget);
  });

  testWidgets('shows earnings on a completed trip', (tester) async {
    stub([completed()]);

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('+£8.30'), findsOneWidget);
  });

  testWidgets('states who cancelled and shows the penalty', (tester) async {
    stub([cancelled()]);

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('Cancelled by rider'), findsOneWidget);
    expect(find.text('−£59.00'), findsOneWidget);
  });

  testWidgets('a cancellation with no penalty shows an em dash, not £0.00',
      (tester) async {
    stub([cancelled(penalty: 0)]);

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('—'), findsOneWidget);
    expect(find.text('£0.00'), findsNothing);
  });

  testWidgets('changing the filter refetches server-side', (tester) async {
    stub([completed()]);

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelled'));
    await tester.pumpAndSettle();

    verify(() => repo.page(
        filter: TripFilter.cancelled, cursor: any(named: 'cursor'))).called(1);
  });

  testWidgets('the empty state names the filter', (tester) async {
    stub([]);

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelled'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No cancelled trips'), findsOneWidget);
  });

  testWidgets('shows no totals — that is the Earnings screen job',
      (tester) async {
    stub([completed(), completed()]);

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    // Two screens computing the same total is two screens that can disagree.
    expect(find.textContaining('Total'), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/trips/trips_screen_test.dart`
Expected: FAIL — screen files do not exist

- [ ] **Step 3: Write the controller**

Create `app/lib/features/trips/logic/trips_controller.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../data/models/driver_trip.dart';
import '../data/trips_repository.dart';

class TripsState {
  final TripFilter filter;
  final List<DriverTrip> trips;
  final String? nextCursor;
  final bool isLoadingMore;
  final ApiException? error;

  const TripsState({
    this.filter = TripFilter.all,
    this.trips = const [],
    this.nextCursor,
    this.isLoadingMore = false,
    this.error,
  });

  bool get hasMore => nextCursor != null;

  TripsState copyWith({
    TripFilter? filter,
    List<DriverTrip>? trips,
    String? nextCursor,
    bool? isLoadingMore,
    ApiException? error,
    bool clearCursor = false,
    bool clearError = false,
  }) =>
      TripsState(
        filter: filter ?? this.filter,
        trips: trips ?? this.trips,
        nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        error: clearError ? null : (error ?? this.error),
      );
}

class TripsController extends AsyncNotifier<TripsState> {
  bool _disposed = false;

  @override
  Future<TripsState> build() async {
    ref.onDispose(() => _disposed = true);
    return _fetch(TripFilter.all);
  }

  TripsState get _current => state.value ?? const TripsState();

  void _emit(TripsState next) {
    if (_disposed) return;
    state = AsyncData(next);
  }

  Future<TripsState> _fetch(TripFilter filter) async {
    final result = await ref.read(tripsRepositoryProvider).page(filter: filter);
    return result.when(
      ok: (page) => TripsState(
        filter: filter,
        trips: page.trips,
        nextCursor: page.nextCursor,
      ),
      err: (e) => TripsState(filter: filter, error: e),
    );
  }

  Future<void> setFilter(TripFilter filter) async {
    if (filter == _current.filter) return;
    // Refetched rather than filtered in place: the server owns which rows
    // belong to a filter, and a client-side filter would page wrongly.
    state = const AsyncLoading();
    final next = await _fetch(filter);
    _emit(next);
  }

  Future<void> refresh() async => _emit(await _fetch(_current.filter));

  Future<void> loadMore() async {
    final cursor = _current.nextCursor;
    if (cursor == null || _current.isLoadingMore) return;

    _emit(_current.copyWith(isLoadingMore: true));
    final result = await ref
        .read(tripsRepositoryProvider)
        .page(filter: _current.filter, cursor: cursor);
    result.when(
      ok: (page) => _emit(_current.copyWith(
        trips: [..._current.trips, ...page.trips],
        nextCursor: page.nextCursor,
        clearCursor: page.nextCursor == null,
        isLoadingMore: false,
      )),
      err: (e) => _emit(_current.copyWith(isLoadingMore: false, error: e)),
    );
  }
}

final tripsControllerProvider =
    AsyncNotifierProvider<TripsController, TripsState>(TripsController.new);
```

- [ ] **Step 4: Write the row and screen**

Create `app/lib/features/trips/ui/widgets/trip_row.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../data/models/driver_trip.dart';

/// One trip. Cancelled trips are present but visually demoted: they are a
/// third of all activity and they drive the cancellation-rate stat, so
/// hiding them would leave a driver unable to check their own record — but
/// they should not compete with work that earned money.
class TripRow extends StatelessWidget {
  final DriverTrip trip;

  const TripRow({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    final cancelled = trip.isCancelled;
    final labelColour =
        cancelled ? AppColors.textSecondary : AppColors.textPrimary;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (cancelled)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(Icons.block, size: 15, color: AppColors.textSecondary),
                ),
              Expanded(
                child: Text(trip.pickupLabel,
                    style: AppText.body.copyWith(color: labelColour),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '→ ${trip.dropoffLabel}',
            style: AppText.body.copyWith(
              color: labelColour,
              decoration: cancelled ? TextDecoration.lineThrough : null,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Text(_meta(), style: AppText.caption)),
              Text(_amount(), style: _amountStyle()),
            ],
          ),
          if (trip.cancelReason != null) ...[
            const SizedBox(height: 4),
            Text(trip.cancelReason!, style: AppText.caption),
          ],
        ],
      ),
    );
  }

  String _meta() {
    final parts = <String>[
      if (trip.ref != null) trip.ref!,
      if (trip.completedAt != null)
        DateFormat('HH:mm').format(trip.completedAt!.toLocal()),
      if (!trip.isCancelled && trip.distanceMiles != null)
        '${trip.distanceMiles!.toStringAsFixed(1)} mi',
      if (trip.cancelledByLabel != null) trip.cancelledByLabel!,
    ];
    return parts.join(' · ');
  }

  /// A cancellation that cost nothing shows an em dash. "£0.00" would read
  /// as a charge of zero rather than no charge at all.
  String _amount() {
    if (trip.isCancelled) {
      return trip.penalty.isZero ? '—' : trip.penalty.format().replaceFirst('£', '−£');
    }
    return trip.earnings.formatSigned();
  }

  TextStyle _amountStyle() => AppText.body.copyWith(
        fontWeight: FontWeight.w600,
        color: trip.isCancelled
            ? (trip.penalty.isZero ? AppColors.textSecondary : AppColors.negative)
            : AppColors.positive,
      );
}
```

Create `app/lib/features/trips/ui/trips_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_loading.dart';
import '../../../shared/widgets/cursor_list.dart';
import '../data/models/driver_trip.dart';
import '../logic/trips_controller.dart';
import 'widgets/trip_row.dart';

/// The driver's own record of work done. Deliberately carries no totals —
/// that is the Earnings screen's job, and two screens computing the same
/// figure are two screens that can disagree.
class TripsScreen extends ConsumerWidget {
  const TripsScreen({super.key});

  static const _filters = {
    TripFilter.all: 'All',
    TripFilter.completed: 'Completed',
    TripFilter.cancelled: 'Cancelled',
  };

  static String dayLabel(DateTime when) {
    final now = DateTime.now();
    final date = DateTime(when.year, when.month, when.day);
    final today = DateTime(now.year, now.month, now.day);
    final difference = today.difference(date).inDays;
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    return DateFormat('EEE d MMM').format(when);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(tripsControllerProvider);
    final controller = ref.read(tripsControllerProvider.notifier);
    final filter = async.value?.filter ?? TripFilter.all;

    return Scaffold(
      appBar: AppBar(title: const Text('Trips')),
      body: Column(
        children: [
          _filterBar(filter, controller),
          Expanded(
            child: async.when(
              loading: () => const AppLoading(),
              error: (e, _) => Center(child: Text('$e', style: AppText.body)),
              data: (state) {
                if (state.trips.isEmpty && state.error != null) {
                  return AppErrorState(
                      error: state.error!, onRetry: controller.refresh);
                }
                return CursorList<DriverTrip>(
                  items: state.trips,
                  hasMore: state.hasMore,
                  isLoadingMore: state.isLoadingMore,
                  onLoadMore: controller.loadMore,
                  onRefresh: controller.refresh,
                  emptyState: AppEmptyState(
                    icon: Icons.route_outlined,
                    title: switch (state.filter) {
                      TripFilter.cancelled => 'No cancelled trips',
                      TripFilter.completed => 'No completed trips yet',
                      TripFilter.all => 'No trips yet',
                    },
                  ),
                  itemBuilder: (context, trip) {
                    final index = state.trips.indexOf(trip);
                    final showHeader = index == 0 ||
                        dayLabel(trip.completedAt ?? DateTime.now()) !=
                            dayLabel(state.trips[index - 1].completedAt ??
                                DateTime.now());
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showHeader)
                          Padding(
                            padding:
                                const EdgeInsets.fromLTRB(16, 16, 16, 4),
                            child: Text(
                                dayLabel(trip.completedAt ?? DateTime.now()),
                                style: AppText.caption),
                          ),
                        TripRow(trip: trip),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterBar(TripFilter active, TripsController controller) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: _filters.entries
              .map((e) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(e.value),
                      selected: active == e.key,
                      onSelected: (_) => controller.setFilter(e.key),
                      selectedColor: AppColors.primary.withValues(alpha: 0.15),
                    ),
                  ))
              .toList(),
        ),
      );
}
```

- [ ] **Step 5: Register the route**

In `app/lib/app.dart`, replace the Trips placeholder:

```dart
          GoRoute(path: Routes.trips, builder: (_, __) => const TripsScreen()),
```

- [ ] **Step 6: Run test to verify it passes**

Run: `cd app && flutter test test/features/trips/`
Expected: PASS, 16 tests

- [ ] **Step 7: Commit**

```bash
git add app/lib app/test
git commit -m "feat: add the trips screen with filters and cancellation attribution"
```

---

### Task 7: The Earnings screen

**Files:**
- Create: `app/lib/features/earnings/logic/earnings_controller.dart`
- Create: `app/lib/features/earnings/ui/earnings_screen.dart`
- Create: `app/lib/features/earnings/ui/widgets/payout_row.dart`
- Modify: `app/lib/app.dart`
- Test: `app/test/features/earnings/earnings_screen_test.dart`

**Interfaces:**
- Consumes: `EarningsRepository` (Task 1)
- Produces: `EarningsState(period, summary, wallet)`; `EarningsController` with `.setPeriod()`; `EarningsScreen`; `PayoutRow(payout)`. Replaces the Earnings placeholder route.

- [ ] **Step 1: Write the failing test**

Create `app/test/features/earnings/earnings_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/money.dart';
import 'package:hoppin_driver/core/result.dart';
import 'package:hoppin_driver/features/earnings/data/earnings_repository.dart';
import 'package:hoppin_driver/features/earnings/data/models/ride_earnings.dart';
import 'package:hoppin_driver/features/earnings/data/models/wallet.dart';
import 'package:hoppin_driver/features/earnings/ui/earnings_screen.dart';
import 'package:mocktail/mocktail.dart';

class MockEarningsRepo extends Mock implements EarningsRepository {}

Widget wrap(MockEarningsRepo repo) => ProviderScope(
      overrides: [earningsRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: EarningsScreen()),
    );

void main() {
  late MockEarningsRepo repo;

  setUp(() {
    repo = MockEarningsRepo();
    when(() => repo.summary(any())).thenAnswer((_) async =>
        const Ok(EarningsSummary(total: Pence(24000), tripCount: 12)));
    when(() => repo.wallet()).thenAnswer((_) async => const Ok(Wallet(
        availableBalance: Pence(21050), pendingBalance: Pence(4200))));
  });

  testWidgets('shows the period total', (tester) async {
    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('£240.00'), findsOneWidget);
    expect(find.textContaining('12'), findsWidgets);
  });

  testWidgets('changing the period refetches', (tester) async {
    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();

    verify(() => repo.summary('month')).called(1);
  });

  testWidgets('shows payout history read-only, with no retry', (tester) async {
    when(() => repo.wallet()).thenAnswer((_) async => Ok(Wallet(
          availableBalance: const Pence(0),
          pendingBalance: const Pence(0),
          recentPayouts: [
            Payout(
                id: 'p1',
                amount: const Pence(21050),
                status: 'paid',
                transferredAt: DateTime.utc(2026, 8, 25)),
            const Payout(
                id: 'p2',
                amount: Pence(8800),
                status: 'failed',
                failureReason: 'Bank rejected the transfer'),
          ],
        )));

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('£210.50'), findsOneWidget);
    expect(find.text('Bank rejected the transfer'), findsOneWidget);
    // Payouts are operator-run; a Retry the driver cannot action would be
    // a button that lies.
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('offers no way to add a payout method', (tester) async {
    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    expect(find.textContaining('Add payment'), findsNothing);
    expect(find.textContaining('Add bank'), findsNothing);
  });

  testWidgets('a driver in debt sees it here too', (tester) async {
    when(() => repo.wallet()).thenAnswer((_) async => const Ok(Wallet(
        availableBalance: Pence(-5000), pendingBalance: Pence(0))));

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('−£50.00'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/earnings/earnings_screen_test.dart`
Expected: FAIL — screen files do not exist

- [ ] **Step 3: Write the controller**

Create `app/lib/features/earnings/logic/earnings_controller.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../data/earnings_repository.dart';
import '../data/models/ride_earnings.dart';
import '../data/models/wallet.dart';

class EarningsState {
  final String period;
  final EarningsSummary? summary;
  final Wallet? wallet;
  final ApiException? error;

  const EarningsState({
    this.period = 'today',
    this.summary,
    this.wallet,
    this.error,
  });
}

class EarningsController extends AsyncNotifier<EarningsState> {
  bool _disposed = false;

  @override
  Future<EarningsState> build() async {
    ref.onDispose(() => _disposed = true);
    return _fetch('today');
  }

  Future<EarningsState> _fetch(String period) async {
    final repo = ref.read(earningsRepositoryProvider);
    final summary = await repo.summary(period);
    final wallet = await repo.wallet();

    return EarningsState(
      period: period,
      summary: summary.valueOrNull,
      wallet: wallet.valueOrNull,
      error: summary.errorOrNull ?? wallet.errorOrNull,
    );
  }

  Future<void> setPeriod(String period) async {
    if (period == state.value?.period) return;
    state = const AsyncLoading();
    final next = await _fetch(period);
    if (_disposed) return;
    state = AsyncData(next);
  }

  Future<void> refresh() async {
    final next = await _fetch(state.value?.period ?? 'today');
    if (_disposed) return;
    state = AsyncData(next);
  }
}

final earningsControllerProvider =
    AsyncNotifierProvider<EarningsController, EarningsState>(
        EarningsController.new);
```

- [ ] **Step 4: Write the payout row and screen**

Create `app/lib/features/earnings/ui/widgets/payout_row.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../data/models/wallet.dart';

/// One payout, read-only.
///
/// Payouts are run by the operator on a weekly or monthly cycle. A failed
/// one shows the reason, but there is deliberately no Retry: the driver
/// cannot re-run an operator's transfer, and a button that cannot work is
/// worse than none.
class PayoutRow extends StatelessWidget {
  final Payout payout;

  const PayoutRow({super.key, required this.payout});

  bool get _failed => payout.status == 'failed';

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              _failed ? Icons.error_outline : Icons.check_circle_outline,
              size: 18,
              color: _failed ? AppColors.negative : AppColors.positive,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    payout.transferredAt == null
                        ? payout.status
                        : DateFormat('d MMM yyyy')
                            .format(payout.transferredAt!.toLocal()),
                    style: AppText.body,
                  ),
                  if (payout.failureReason != null)
                    Text(payout.failureReason!,
                        style: AppText.caption
                            .copyWith(color: AppColors.negative)),
                ],
              ),
            ),
            Text(payout.amount.format(), style: AppText.body),
          ],
        ),
      );
}
```

Create `app/lib/features/earnings/ui/earnings_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app_router.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_loading.dart';
import '../logic/earnings_controller.dart';
import 'widgets/payout_row.dart';

class EarningsScreen extends ConsumerWidget {
  const EarningsScreen({super.key});

  static const _periods = {
    'today': 'Today',
    'week': 'Week',
    'month': 'Month',
    'all': 'All time',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(earningsControllerProvider);
    final controller = ref.read(earningsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Earnings')),
      body: async.when(
        loading: () => const AppLoading(),
        error: (e, _) => Center(child: Text('$e', style: AppText.body)),
        data: (state) {
          if (state.summary == null && state.error != null) {
            return AppErrorState(
                error: state.error!, onRetry: controller.refresh);
          }
          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                _periodBar(state.period, controller),
                _totalCard(state),
                _balanceTile(context, state),
                if ((state.wallet?.recentPayouts ?? []).isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: Text('Payouts', style: AppText.heading),
                  ),
                  ...state.wallet!.recentPayouts
                      .map((p) => PayoutRow(payout: p)),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Payouts are issued by your operator.',
                      style: AppText.caption,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _periodBar(String active, EarningsController controller) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: _periods.entries
              .map((e) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(e.value),
                      selected: active == e.key,
                      onSelected: (_) => controller.setPeriod(e.key),
                      selectedColor: AppColors.primary.withValues(alpha: 0.15),
                    ),
                  ))
              .toList(),
        ),
      );

  Widget _totalCard(EarningsState state) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You earned', style: AppText.caption),
            const SizedBox(height: 4),
            Text(state.summary?.total.format() ?? '—', style: AppText.money),
            const SizedBox(height: 4),
            Text('${state.summary?.tripCount ?? 0} trips',
                style: AppText.caption),
          ],
        ),
      );

  /// The balance links to the Statement, which is the one place every
  /// individual credit and charge is itemised in the server's own words.
  Widget _balanceTile(BuildContext context, EarningsState state) {
    final balance = state.wallet?.availableBalance;
    if (balance == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: ListTile(
        tileColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Text(balance.isNegative ? 'You owe' : 'Your balance',
            style: AppText.body),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              balance.format(),
              style: AppText.body.copyWith(
                fontWeight: FontWeight.w600,
                color: balance.isNegative
                    ? AppColors.negative
                    : AppColors.textPrimary,
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
        onTap: () => context.push(Routes.statement),
      ),
    );
  }
}
```

- [ ] **Step 5: Register the route**

In `app/lib/app.dart`, replace the Earnings placeholder:

```dart
          GoRoute(
              path: Routes.earnings,
              builder: (_, __) => const EarningsScreen()),
```

- [ ] **Step 6: Run the whole suite**

Run: `cd app && flutter test && flutter analyze`
Expected: all PASS, analyzer clean

- [ ] **Step 7: Commit**

```bash
git add app/lib app/test
git commit -m "feat: add the earnings screen with read-only payout history"
```

---

## Batch 5 done when

- `flutter test` passes and `flutter analyze` is clean.
- A per-trip breakdown renders only the lines that carry a value, plus Net — no "VAT £0.00", no "Penalty £0.00".
- The Statement shows a signed balance in both directions, every entry in the server's own words, and no claim about how a debt will be collected.
- Trips filters server-side, groups by day, states who cancelled, and shows an em dash rather than £0.00 for a cancellation that cost nothing.
- Payout history is visible and inert: no Retry, no payout-method capture.
- No screen renders a tip or an invented bonus row.

**Next:** Batch 6 (Compliance) — documents, stats, penalties, appeals.
