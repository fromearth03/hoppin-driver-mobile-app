import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_client.dart';
import 'package:hoppin_driver/core/auth/token_store.dart';
import 'package:hoppin_driver/features/stats/data/appeals_repository.dart';
import 'package:hoppin_driver/features/stats/data/models/appeal.dart';
import 'package:mocktail/mocktail.dart';

class _MockAdapter extends Mock implements HttpClientAdapter {}

void main() {
  setUpAll(() => registerFallbackValue(RequestOptions(path: '/')));

  ResponseBody body(String json, int status) =>
      ResponseBody.fromString(json, status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  late _MockAdapter adapter;
  late AppealsRepository repo;

  setUp(() {
    adapter = _MockAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    repo = AppealsRepository(ApiClient(dio, InMemoryTokenStore()));
  });

  test('a decision carries the reviewer own words', () {
    final a = Appeal.fromJson({
      'id': 'a1',
      'document_type': 'vehicle_insurance',
      'reason': 'The document was in date when I uploaded it.',
      'status': 'approved',
      'review_note': 'Confirmed — the certificate was valid. Reinstated.',
      'reviewed_at': '2026-08-29T14:00:00Z',
      'created_at': '2026-08-28T10:00:00Z',
    });

    expect(a.status, AppealStatus.approved);
    // Admins must supply a note on approve and reject alike, so an outcome
    // reaching the driver without an explanation is a backend bug.
    expect(a.reviewNote, 'Confirmed — the certificate was valid. Reinstated.');
    expect(a.isResolved, isTrue);
  });

  test('an open appeal has no note yet', () {
    final a = Appeal.fromJson({
      'id': 'a2',
      'reason': 'Please review',
      'status': 'pending',
      'created_at': '2026-08-28T10:00:00Z',
    });

    expect(a.status, AppealStatus.underReview);
    expect(a.reviewNote, isNull);
    expect(a.isResolved, isFalse);
  });

  test('a rejection is resolved too', () {
    final a = Appeal.fromJson({
      'id': 'a3',
      'reason': 'x',
      'status': 'rejected',
      'review_note': 'The expiry date had passed at the time of the trip.',
      'created_at': '2026-08-28T10:00:00Z',
    });

    expect(a.status, AppealStatus.rejected);
    expect(a.isResolved, isTrue);
  });

  test('an unknown status reads as under review', () {
    final a = Appeal.fromJson({
      'id': 'a4',
      'reason': 'x',
      'status': 'something_new',
      'created_at': '2026-08-28T10:00:00Z',
    });

    expect(a.status, AppealStatus.underReview);
  });

  test('filing sends the driver reason', () async {
    when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async => body(
        '{"id":"a5","reason":"It was valid","status":"pending",'
        '"created_at":"2026-08-30T10:00:00Z"}',
        200));

    await repo.file(documentType: 'vehicle_insurance', reason: 'It was valid');

    final sent = verify(() => adapter.fetch(captureAny(), any(), any()))
        .captured
        .first as RequestOptions;
    expect(sent.data['reason'], 'It was valid');
    expect(sent.data['document_type'], 'vehicle_insurance');
  });

  test('reads the appeal history', () async {
    when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async => body(
        '[{"id":"a1","reason":"x","status":"approved",'
        '"review_note":"Reinstated.","created_at":"2026-08-28T10:00:00Z"}]',
        200));

    final r = await repo.mine();

    expect(r.valueOrNull!.single.reviewNote, 'Reinstated.');
  });
}
