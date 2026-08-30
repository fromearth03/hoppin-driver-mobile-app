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
