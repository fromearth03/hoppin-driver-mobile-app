import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_client.dart';
import 'package:hoppin_driver/core/auth/token_store.dart';
import 'package:hoppin_driver/features/profile/data/models/driver_profile.dart';
import 'package:hoppin_driver/features/profile/data/profile_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockAdapter extends Mock implements HttpClientAdapter {}

void main() {
  setUpAll(() => registerFallbackValue(RequestOptions(path: '/')));

  ResponseBody body(String json, int status) =>
      ResponseBody.fromString(json, status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  late _MockAdapter adapter;
  late ProfileRepository repo;

  setUp(() {
    adapter = _MockAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    repo = ProfileRepository(ApiClient(dio, InMemoryTokenStore()));
  });

  test('parses the profile', () {
    final p = DriverProfile.fromJson({
      'id': 'u1',
      'full_name': 'Alex Morgan',
      'email': 'alex@hoppin.tech',
      'phone_number': '+44 7700 900000',
      'date_of_birth': '1990-05-14',
    });

    expect(p.fullName, 'Alex Morgan');
    expect(p.phoneNumber, '+44 7700 900000');
  });

  test('tolerates a profile with nothing optional set', () {
    final p = DriverProfile.fromJson({'id': 'u1', 'full_name': 'Sam Patel'});

    expect(p.phoneNumber, isNull);
    expect(p.dateOfBirth, isNull);
    expect(p.avatarUrl, isNull);
  });

  test('sends only the fields the driver may change', () async {
    when(() => adapter.fetch(any(), any(), any())).thenAnswer(
        (_) async => body('{"id":"u1","full_name":"Alex Morgan"}', 200));

    await repo.update(phoneNumber: '+44 7700 900111');

    final sent = verify(() => adapter.fetch(captureAny(), any(), any()))
        .captured
        .first as RequestOptions;
    expect(sent.data['phone_number'], '+44 7700 900111');
    // Name is operator-verified; the app must not attempt to change it.
    expect(sent.data.containsKey('full_name'), isFalse);
  });

  test('surfaces PHONE_TAKEN so the driver can pick another', () async {
    when(() => adapter.fetch(any(), any(), any())).thenAnswer(
        (_) async => body('{"code":"PHONE_TAKEN","error":"in use"}', 409));

    final r = await repo.update(phoneNumber: '+44 7700 900111');

    expect(r.errorOrNull!.code, 'PHONE_TAKEN');
  });
}
