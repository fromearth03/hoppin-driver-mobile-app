import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_client.dart';
import 'package:hoppin_driver/core/auth/token_store.dart';
import 'package:hoppin_driver/features/profile/data/models/driver_preferences.dart';
import 'package:hoppin_driver/features/profile/data/preferences_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockAdapter extends Mock implements HttpClientAdapter {}

void main() {
  setUpAll(() => registerFallbackValue(RequestOptions(path: '/')));

  ResponseBody body(String json, int status) =>
      ResponseBody.fromString(json, status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  late _MockAdapter adapter;
  late PreferencesRepository repo;

  setUp(() {
    adapter = _MockAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    repo = PreferencesRepository(ApiClient(dio, InMemoryTokenStore()));
  });

  test('a driver with no saved preferences gets sensible defaults', () {
    final p = DriverPreferences.fromJson(const {});

    expect(p.notificationsEnabled, isTrue);
    expect(p.rideRequestSound, isTrue);
    expect(p.distanceUnit, DistanceUnit.miles);
    expect(p.navApp, NavApp.google);
  });

  test('round-trips through json', () {
    const original = DriverPreferences(
      notificationsEnabled: false,
      keepScreenAwake: true,
      distanceUnit: DistanceUnit.kilometres,
      navApp: NavApp.apple,
    );

    final restored = DriverPreferences.fromJson(original.toJson());

    expect(restored.notificationsEnabled, isFalse);
    expect(restored.keepScreenAwake, isTrue);
    expect(restored.distanceUnit, DistanceUnit.kilometres);
    expect(restored.navApp, NavApp.apple);
  });

  test('an unrecognised unit falls back to miles', () {
    final p = DriverPreferences.fromJson({'distance_unit': 'furlongs'});
    expect(p.distanceUnit, DistanceUnit.miles);
  });

  test('reads the preferences envelope', () async {
    when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async =>
        body('{"preferences":{"distance_unit":"kilometres"}}', 200));

    final r = await repo.load();

    expect(r.valueOrNull!.distanceUnit, DistanceUnit.kilometres);
  });

  test('preserves keys another client may have stored', () async {
    when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async =>
        body('{"preferences":{"rider_only_setting":"keep me"}}', 200));

    final loaded = await repo.load();
    await repo.save(loaded.valueOrNull!);

    final sent = verify(() => adapter.fetch(captureAny(), any(), any()))
        .captured
        .last as RequestOptions;
    // This blob is shared; dropping unknown keys would silently wipe
    // settings this app knows nothing about.
    expect(sent.data['preferences']['rider_only_setting'], 'keep me');
  });
}
