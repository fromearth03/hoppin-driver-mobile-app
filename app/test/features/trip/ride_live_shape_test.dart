import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/trip/data/models/ride.dart';

/// Guards the model against the shapes the service actually returns, as
/// distinct from the shapes the plan assumed. Every payload below is copied
/// from the Go structs in `Go_ride_service`, not invented.
void main() {
  group('GET /rides/:id', () {
    test('reads timestamps from the nested block the service sends', () {
      // rideTimestampsBlock — the handler nests these under "timestamps",
      // not at the top level.
      final ride = Ride.fromJson({
        'id': 'r1',
        'status': 'arrived',
        'geo': {
          'pickup': {'lat': 52.58, 'lng': -2.12},
          'dropoff': {'lat': 52.59, 'lng': -2.13},
          'route': <dynamic>[],
        },
        'timestamps': {
          'accepted_at': '2026-08-30T09:00:00Z',
          'arrived_at': '2026-08-30T09:12:00Z',
          'started_at': null,
          'completed_at': null,
        },
      });

      expect(ride.acceptedAt, DateTime.utc(2026, 8, 30, 9));
      expect(ride.arrivedAt, DateTime.utc(2026, 8, 30, 9, 12));
      expect(ride.startedAt, isNull);
    });

    test('still reads top-level timestamps if the service ever flattens them',
        () {
      final ride = Ride.fromJson({
        'id': 'r1',
        'status': 'accepted',
        'geo': {
          'pickup': {'lat': 1.0, 'lng': 2.0},
          'dropoff': {'lat': 3.0, 'lng': 4.0},
          'route': <dynamic>[],
        },
        'accepted_at': '2026-08-30T09:00:00Z',
      });

      expect(ride.acceptedAt, DateTime.utc(2026, 8, 30, 9));
    });

    test('carries chat_unread and ref from the real payload', () {
      final ride = Ride.fromJson({
        'id': 'r1',
        'status': 'in_progress',
        'ref': 'R-1042',
        'chat_unread': 3,
        'geo': {
          'pickup': {'lat': 1.0, 'lng': 2.0},
          'dropoff': {'lat': 3.0, 'lng': 4.0},
          'route': <dynamic>[],
        },
      });

      expect(ride.ref, 'R-1042');
      expect(ride.chatUnread, 3);
    });

    test('ignores the driver block — that describes the car to the rider', () {
      // This endpoint is shared between rider and driver. Its `driver` block
      // is for the rider's benefit; the driver's own passenger comes from
      // /rides/:id/rider-context.
      final ride = Ride.fromJson({
        'id': 'r1',
        'status': 'accepted',
        'geo': {
          'pickup': {'lat': 1.0, 'lng': 2.0},
          'dropoff': {'lat': 3.0, 'lng': 4.0},
          'route': <dynamic>[],
        },
        'driver': {'full_name': 'The Driver Themselves', 'rating': 4.9},
      });

      expect(ride.rider, isNull);
    });

    test('a ride with no geo block parses instead of throwing', () {
      // `geo` is a pointer server-side. A hard cast would throw inside the
      // repository and escape Result as an unhandled async error, rather
      // than reaching the screen as a failure it can render.
      expect(
        () => Ride.fromJson({'id': 'r1', 'status': 'accepted'}),
        returnsNormally,
      );
    });
  });

  group('GET /rides/:id/rider-context', () {
    test('reads the field names the driver endpoint actually sends', () {
      // RideRiderContextView sends `name` (first name only) and `photo_url`,
      // not `full_name` / `avatar_url`.
      final rider = Rider.fromJson({
        'name': 'Alex',
        'photo_url': 'https://cdn.hoppin.tech/a.jpg',
        'rating': 4.8,
        'rating_count': 12,
      });

      expect(rider.fullName, 'Alex');
      expect(rider.avatarUrl, 'https://cdn.hoppin.tech/a.jpg');
      expect(rider.rating, 4.8);
      expect(rider.ratingCount, 12);
    });

    test('an omitted photo_url leaves the avatar null for a fallback initial',
        () {
      // The Go field is `omitempty`, so it is absent rather than empty when
      // the rider has set no photo.
      final rider = Rider.fromJson({'name': 'Sam', 'rating': null});

      expect(rider.avatarUrl, isNull);
      expect(rider.rating, isNull);
      expect(rider.fullName, 'Sam');
    });
  });
}
