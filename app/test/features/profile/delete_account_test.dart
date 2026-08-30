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

  test('DELETION_BLOCKED surfaces every blocker, not just the first', () async {
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
