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
          (_) async => body('{"net_pence":24000,"trips":12}', 200));

      await repo.summary('week');

      final sent = verify(() => adapter.fetch(captureAny(), any(), any()))
          .captured
          .first as RequestOptions;
      expect(sent.queryParameters['period'], 'week');
    });

    test('asks the report endpoint for CSV over an inclusive range', () async {
      when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async =>
          ResponseBody.fromString('date,ride_id\n', 200, headers: {
            Headers.contentTypeHeader: ['text/csv']
          }));

      final r = await repo.report(
          from: DateTime(2026, 8, 1), to: DateTime(2026, 8, 18));

      final sent = verify(() => adapter.fetch(captureAny(), any(), any()))
          .captured
          .first as RequestOptions;
      expect(sent.queryParameters['from'], '2026-08-01');
      expect(sent.queryParameters['to'], '2026-08-18');
      // The service rejects any other format with a 400, so nothing else is
      // ever asked for — the design's PDF option would be a guaranteed error.
      expect(sent.queryParameters['format'], 'csv');
      expect(r.valueOrNull, contains('ride_id'));
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
