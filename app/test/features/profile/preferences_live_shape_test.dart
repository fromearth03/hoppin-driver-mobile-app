import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_client.dart';
import 'package:hoppin_driver/core/result.dart';
import 'package:hoppin_driver/features/profile/data/models/driver_preferences.dart';
import 'package:hoppin_driver/features/profile/data/preferences_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockApi extends Mock implements ApiClient {}

/// `PATCH /me/preferences` binds the request body *directly* as the patch
/// map and rejects any key outside its whitelist with a 400 listing every
/// offender. The app wrapped its patch in a `preferences` envelope and sent
/// five key names the server has never heard of, so no setting ever saved.
void main() {
  late MockApi api;
  late PreferencesRepository repo;

  setUp(() {
    api = MockApi();
    repo = PreferencesRepository(api);
    when(() => api.patch<dynamic>(any(), body: any(named: 'body')))
        .thenAnswer((_) async => const Ok({'preferences': {}}));
  });

  Map<String, dynamic> capturedBody() =>
      verify(() => api.patch<dynamic>('/me/preferences',
              body: captureAny(named: 'body')))
          .captured
          .single as Map<String, dynamic>;

  test('sends the patch unwrapped, as the handler binds it', () async {
    await repo.save(const DriverPreferences());

    final body = capturedBody();
    // A `preferences` envelope is itself an unknown key: the handler binds
    // the body as the patch map, so the envelope was the whole payload.
    expect(body.containsKey('preferences'), isFalse);
    expect(body['push_trip_updates'], isA<bool>());
  });

  test('sends only keys the server whitelists', () async {
    await repo.save(const DriverPreferences());

    // The whitelist, verbatim from preferenceKeys in preferences_handler.go.
    const allowed = {
      'push_trip_updates',
      'push_promotions',
      'push_payouts',
      'email_receipts',
      'sms_trip_updates',
      'sound_offer_chime',
      'marketing_consent',
      'theme',
      'language',
    };
    expect(capturedBody().keys, everyElement(isIn(allowed)));
  });

  test('maps the toggles onto their server keys', () async {
    await repo.save(const DriverPreferences(
      notificationsEnabled: false,
      rideRequestSound: false,
    ));

    final body = capturedBody();
    expect(body['push_trip_updates'], isFalse);
    expect(body['sound_offer_chime'], isFalse);
  });

  test('reads the toggles back from the server keys', () {
    final p = DriverPreferences.fromJson(const {
      'push_trip_updates': false,
      'sound_offer_chime': false,
      'theme': 'dark',
    });

    expect(p.notificationsEnabled, isFalse);
    expect(p.rideRequestSound, isFalse);
  });

  test('sends every toggle the screen offers', () async {
    await repo.save(const DriverPreferences(
      pushPromotions: false,
      pushPayouts: false,
      emailReceipts: false,
      smsTripUpdates: true,
    ));

    final body = capturedBody();
    expect(body['push_promotions'], isFalse);
    expect(body['push_payouts'], isFalse);
    expect(body['email_receipts'], isFalse);
    expect(body['sms_trip_updates'], isTrue);
  });

  test('carries unknown keys back untouched', () async {
    final loaded = DriverPreferences.fromJson(const {
      'push_trip_updates': true,
      'language': 'en-GB',
    });
    await repo.save(loaded);

    // Another client owns these. Dropping them on save would wipe settings
    // this app knows nothing about.
    expect(capturedBody()['language'], 'en-GB');
  });
}
