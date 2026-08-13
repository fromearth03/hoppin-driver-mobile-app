import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// DEMO-07 seam acceptance: [RideDriverInfo] round-trips the snake_case
/// shape a future backend endpoint would serve, derives display initials
/// defensively, and the LIVE [RidesRepository.driverInfo] answers null —
/// graceful degradation IS the contract (`:8080` has no driver-identity
/// or telemetry endpoint).
void main() {
  const fullJson = <String, dynamic>{
    'full_name': 'Gurpreet Singh',
    'photo_url': 'https://cdn.hoppin.uk/drivers/gurpreet.jpg',
    'rating': 4.9,
    'rating_count': 12,
    'recent_comments': <String>['Smooth ride'],
    'trips_count': 1480,
    'vehicle_make': 'Toyota',
    'vehicle_model': 'Prius',
    'vehicle_colour': 'Silver',
    'plate': 'BK72 WNH',
    'eta_seconds': 120,
    'origin_label': 'Wolverhampton Rail Station',
    'destination_label': 'New Cross Hospital',
  };

  test('constructs with full fields and round-trips JSON', () {
    final info = RideDriverInfo.fromJson(fullJson);
    expect(info.fullName, 'Gurpreet Singh');
    expect(info.photoUrl, 'https://cdn.hoppin.uk/drivers/gurpreet.jpg');
    expect(info.rating, 4.9);
    expect(info.ratingCount, 12);
    expect(info.recentComments, ['Smooth ride']);
    expect(info.tripsCount, 1480);
    expect(info.vehicleMake, 'Toyota');
    expect(info.vehicleModel, 'Prius');
    expect(info.vehicleColour, 'Silver');
    expect(info.plate, 'BK72 WNH');
    expect(info.etaSeconds, 120);
    expect(info.originLabel, 'Wolverhampton Rail Station');
    expect(info.destinationLabel, 'New Cross Hospital');
    expect(info.toJson(), fullJson);
  });

  group('initials', () {
    test("derive from a two-word name: 'Gurpreet Singh' -> 'GS'", () {
      final info = RideDriverInfo.fromJson(fullJson);
      expect(info.initials, 'GS');
    });

    test('single-word name yields its first letter', () {
      final info = RideDriverInfo.fromJson({...fullJson, 'full_name': 'Cher'});
      expect(info.initials, 'C');
    });

    test('defensive on an empty name — never throws', () {
      final info = RideDriverInfo.fromJson({...fullJson, 'full_name': ''});
      expect(info.initials, '?');
    });

    test('whitespace-only name is treated as empty', () {
      final info =
          RideDriverInfo.fromJson({...fullJson, 'full_name': '   '});
      expect(info.initials, '?');
    });
  });

  test('nullable telemetry fields default null when absent from JSON', () {
    final json = Map<String, dynamic>.of(fullJson)
      ..remove('photo_url')
      ..remove('eta_seconds')
      ..remove('origin_label')
      ..remove('destination_label');
    final info = RideDriverInfo.fromJson(json);
    expect(info.photoUrl, isNull);
    expect(info.etaSeconds, isNull);
    expect(info.originLabel, isNull);
    expect(info.destinationLabel, isNull);
  });

  test('null rating + missing comments is an honest new driver', () {
    final json = Map<String, dynamic>.of(fullJson)
      ..['rating'] = null
      ..remove('rating_count')
      ..remove('recent_comments');
    final info = RideDriverInfo.fromJson(json);
    expect(info.rating, isNull);
    expect(info.ratingCount, 0);
    expect(info.recentComments, isEmpty);
  });

  test('live RidesRepository.driverInfo returns null', () async {
    // A real client wired to nowhere: the seam must resolve WITHOUT ever
    // touching the API — the graceful live fallback is the contract.
    final api = ApiClient(
      auth: AuthService(
        SupabaseClient('http://localhost:54321', 'publishable-key'),
      ),
    );
    final repo = RidesRepository(api);
    expect(await repo.driverInfo('any-id'), isNull);
  });
}
