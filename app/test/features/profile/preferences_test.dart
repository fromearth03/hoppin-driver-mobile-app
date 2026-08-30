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

    // Offers and payouts matter to a working driver, so they default on.
    // SMS is the one channel that costs the driver attention uninvited.
    expect(p.notificationsEnabled, isTrue);
    expect(p.rideRequestSound, isTrue);
    expect(p.pushPayouts, isTrue);
    expect(p.smsTripUpdates, isFalse);
  });

  test('round-trips through json', () {
    const original = DriverPreferences(
      notificationsEnabled: false,
      pushPromotions: false,
      smsTripUpdates: true,
    );

    final restored = DriverPreferences.fromJson(original.toJson());

    expect(restored.notificationsEnabled, isFalse);
    expect(restored.pushPromotions, isFalse);
    expect(restored.smsTripUpdates, isTrue);
  });

  test('reads the preferences envelope', () async {
    when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async =>
        body('{"preferences":{"push_trip_updates":false}}', 200));

    final r = await repo.load();

    // The GET wraps its result in an envelope; the PATCH body does not.
    expect(r.valueOrNull!.notificationsEnabled, isFalse);
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
    expect(sent.data['rider_only_setting'], 'keep me');
  });
}
