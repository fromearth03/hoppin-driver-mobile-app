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
