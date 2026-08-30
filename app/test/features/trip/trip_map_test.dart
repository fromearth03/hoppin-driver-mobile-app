import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/trip/data/models/ride.dart';
import 'package:hoppin_driver/features/trip/ui/widgets/trip_map.dart';

void main() {
  test('bounds span every point on the route', () {
    final bounds = TripMap.boundsFor(const [
      GeoPoint(lat: 52.58, lng: -2.12),
      GeoPoint(lat: 52.60, lng: -2.20),
      GeoPoint(lat: 52.55, lng: -2.05),
    ]);

    expect(bounds.southwest.latitude, 52.55);
    expect(bounds.southwest.longitude, -2.20);
    expect(bounds.northeast.latitude, 52.60);
    expect(bounds.northeast.longitude, -2.05);
  });

  test('a single point still yields usable bounds', () {
    final bounds = TripMap.boundsFor(const [GeoPoint(lat: 52.58, lng: -2.12)]);

    expect(bounds.southwest.latitude, lessThanOrEqualTo(52.58));
    expect(bounds.northeast.latitude, greaterThanOrEqualTo(52.58));
  });

  test('an empty route falls back rather than throwing', () {
    // A ride whose polyline failed to persist still has to render a map.
    expect(() => TripMap.boundsFor(const []), returnsNormally);
  });
}
