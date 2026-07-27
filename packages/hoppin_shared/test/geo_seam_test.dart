import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// MAP-03 seam acceptance: [DriverPosition] and [RideGeo] round-trip the
/// snake_case shapes the missing backend endpoints (DOCS/06 gaps #41/#17)
/// would serve, and the LIVE [RidesRepository] answers null on both geo
/// seams WITHOUT ever touching the network — graceful degradation IS the
/// contract until the endpoints ship.
void main() {
  group('DriverPosition', () {
    const fullJson = <String, dynamic>{
      'lat': 52.5903,
      'lng': -2.1306,
      'heading': 118.5,
      'updated_at': '2026-06-30T09:32:15.000',
    };

    test('round-trips the gap #41 snake_case shape', () {
      final position = DriverPosition.fromJson(fullJson);
      expect(position.lat, 52.5903);
      expect(position.lng, -2.1306);
      expect(position.heading, 118.5);
      expect(position.updatedAt, DateTime(2026, 6, 30, 9, 32, 15));
      expect(jsonDecode(jsonEncode(position.toJson())), fullJson);
    });

    test('heading is null-tolerant', () {
      final json = Map<String, dynamic>.of(fullJson)..remove('heading');
      final position = DriverPosition.fromJson(json);
      expect(position.heading, isNull);
      final reparsed = DriverPosition.fromJson(
        jsonDecode(jsonEncode(position.toJson())) as Map<String, dynamic>,
      );
      expect(reparsed, position);
    });
  });

  group('RideGeo', () {
    const fullJson = <String, dynamic>{
      'pickup_lat': 52.5877,
      'pickup_lng': -2.1200,
      'dropoff_lat': 52.6046,
      'dropoff_lng': -2.0930,
      'route': [
        {'lat': 52.5877, 'lng': -2.1200},
        {'lat': 52.5960, 'lng': -2.1050},
        {'lat': 52.6046, 'lng': -2.0930},
      ],
      'approach': [
        {'lat': 52.5903, 'lng': -2.1306},
        {'lat': 52.5877, 'lng': -2.1200},
      ],
    };

    test('round-trips pickup/dropoff pins plus route and approach polylines',
        () {
      final geo = RideGeo.fromJson(fullJson);
      expect(geo.pickupLat, 52.5877);
      expect(geo.pickupLng, -2.1200);
      expect(geo.dropoffLat, 52.6046);
      expect(geo.dropoffLng, -2.0930);
      expect(geo.route, hasLength(3));
      expect(geo.route.first, const GeoPoint(lat: 52.5877, lng: -2.1200));
      expect(geo.route.last, const GeoPoint(lat: 52.6046, lng: -2.0930));
      expect(geo.approach, isNotNull);
      expect(geo.approach!.first, const GeoPoint(lat: 52.5903, lng: -2.1306));
      expect(jsonDecode(jsonEncode(geo.toJson())), fullJson);
    });

    test('approach is null-tolerant — a live endpoint may omit it', () {
      final json = Map<String, dynamic>.of(fullJson)..remove('approach');
      final geo = RideGeo.fromJson(json);
      expect(geo.approach, isNull);
      expect(geo.route, hasLength(3));
      final reparsed = RideGeo.fromJson(
        jsonDecode(jsonEncode(geo.toJson())) as Map<String, dynamic>,
      );
      expect(reparsed, geo);
    });
  });

  group('live RidesRepository geo seams', () {
    test('driverPosition and rideGeo answer null without any network',
        () async {
      // A real client wired to nowhere: both seams must resolve WITHOUT
      // ever touching the API — the graceful live fallback is the contract
      // (no driver-location read #41; no coords on the ride detail #17).
      final api = ApiClient(
        auth: AuthService(
          SupabaseClient('http://localhost:54321', 'publishable-key'),
        ),
      );
      final repo = RidesRepository(api);
      expect(await repo.driverPosition('x'), isNull);
      expect(await repo.rideGeo('x'), isNull);
    });
  });
}
