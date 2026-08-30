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
    // charge they meant. The endpoint has no field for it and drops unknown
    // keys silently, so it has to travel in the body a human reads.
    expect(sent.data.containsKey('ledger_entry_id'), isFalse);
    expect(sent.data['body'], contains('e1'));
    expect(sent.data['body'], contains('I arrived on time.'));
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
