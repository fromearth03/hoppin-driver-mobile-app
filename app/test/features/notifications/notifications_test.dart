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
