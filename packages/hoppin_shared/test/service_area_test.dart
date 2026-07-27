import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

/// BOOK-07 — the client geofence pre-flight is pure geometry: a ray-casting
/// point-in-polygon over the committed (disclosed-approximate) Wolverhampton
/// licensing boundary. The server `422 OUTSIDE_SERVICE_AREA` stays the
/// enforcement authority; this function is a fast, honest UX pre-flight.
///
/// Inside → true, clearly-outside → false. No I/O, no widgets — pure Dart.
void main() {
  group('isInsideServiceArea', () {
    test('seeded Wolverhampton landmarks read as inside', () {
      // The six preset coords the demo/rider share (places.dart / place.dart).
      expect(isInsideServiceArea(52.5870, -2.1288), isTrue,
          reason: 'City Centre is inside the licensing area');
      expect(isInsideServiceArea(52.5877, -2.1200), isTrue,
          reason: 'Rail Station is inside');
      expect(isInsideServiceArea(52.6046, -2.0930), isTrue,
          reason: 'New Cross Hospital is inside');
      expect(isInsideServiceArea(52.594, -2.171), isTrue,
          reason: 'Home (Tettenhall) is inside');
    });

    test('clearly-distant cities read as outside', () {
      expect(isInsideServiceArea(51.507, -0.127), isFalse,
          reason: 'London is far outside');
      expect(isInsideServiceArea(52.4862, -1.8904), isFalse,
          reason: 'Birmingham centre is outside the Wolverhampton polygon');
      expect(isInsideServiceArea(53.4808, -2.2426), isFalse,
          reason: 'Manchester is far outside');
    });

    test('a point just north of the boundary is outside', () {
      // Well beyond the northern ring (~52.63) — must be excluded.
      expect(isInsideServiceArea(52.75, -2.12), isFalse);
    });

    test('the committed boundary is a real polygon, not a two-point box', () {
      expect(kWolverhamptonBoundary.length, greaterThanOrEqualTo(4),
          reason: 'a ring needs enough vertices to be a polygon');
    });
  });
}
