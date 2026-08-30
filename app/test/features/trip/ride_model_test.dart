import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/money.dart';
import 'package:hoppin_driver/features/trip/data/models/ride.dart';
import 'package:hoppin_driver/features/trip/data/models/waiting_policy.dart';

void main() {
  group('Ride', () {
    test('derives the phase from the server status, not from local state', () {
      Ride phaseOf(String status) => Ride.fromJson({
            'id': 'r1',
            'status': status,
            'geo': {
              'pickup': {'lat': 52.58, 'lng': -2.12},
              'dropoff': {'lat': 52.59, 'lng': -2.13},
              'route': <dynamic>[],
            },
          });

      expect(phaseOf('accepted').phase, TripPhase.headingToPickup);
      expect(phaseOf('arrived').phase, TripPhase.waiting);
      expect(phaseOf('in_progress').phase, TripPhase.inTrip);
      expect(phaseOf('completed').phase, TripPhase.completed);
      expect(phaseOf('cancelled').phase, TripPhase.cancelled);
    });

    test('an unrecognised status does not crash the trip screen', () {
      final ride = Ride.fromJson({
        'id': 'r1',
        'status': 'some_new_state',
        'geo': {
          'pickup': {'lat': 1.0, 'lng': 2.0},
          'dropoff': {'lat': 3.0, 'lng': 4.0},
          'route': <dynamic>[],
        },
      });
      expect(ride.phase, TripPhase.headingToPickup);
    });

    test('reads the road-following route the backend persisted', () {
      final ride = Ride.fromJson({
        'id': 'r1',
        'status': 'accepted',
        'geo': {
          'pickup': {'lat': 52.58, 'lng': -2.12, 'label': 'City Centre'},
          'dropoff': {'lat': 52.59, 'lng': -2.13, 'label': 'Station'},
          'route': [
            {'lat': 52.58, 'lng': -2.12},
            {'lat': 52.585, 'lng': -2.125},
            {'lat': 52.59, 'lng': -2.13},
          ],
        },
      });

      expect(ride.geo.route, hasLength(3));
      expect(ride.geo.pickup.label, 'City Centre');
    });

    test('ignores waypoints entirely — the app is single-stop', () {
      final ride = Ride.fromJson({
        'id': 'r1',
        'status': 'accepted',
        'geo': {
          'pickup': {'lat': 1.0, 'lng': 2.0},
          'dropoff': {'lat': 3.0, 'lng': 4.0},
          'waypoints': [
            {'lat': 9.0, 'lng': 9.0}
          ],
          'route': <dynamic>[],
        },
      });

      // There is nowhere in the model to put a waypoint, so a server that
      // starts sending them cannot make the map grow a third pin.
      expect(ride.toString().contains('9.0'), isFalse);
    });

    test('carries the full rider identity, which is allowed after accepting',
        () {
      final ride = Ride.fromJson({
        'id': 'r1',
        'status': 'accepted',
        'ref': 'R-1042',
        'chat_unread': 2,
        'geo': {
          'pickup': {'lat': 1.0, 'lng': 2.0},
          'dropoff': {'lat': 3.0, 'lng': 4.0},
          'route': <dynamic>[],
        },
        'rider': {
          'id': 'u1',
          'full_name': 'Alex Morgan',
          'rating': 4.8,
          'rating_count': 12,
        },
      });

      expect(ride.rider!.fullName, 'Alex Morgan');
      expect(ride.rider!.rating, 4.8);
      expect(ride.ref, 'R-1042');
      expect(ride.chatUnread, 2);
    });

    test('tolerates a ride with no rider block yet', () {
      final ride = Ride.fromJson({
        'id': 'r1',
        'status': 'accepted',
        'geo': {
          'pickup': {'lat': 1.0, 'lng': 2.0},
          'dropoff': {'lat': 3.0, 'lng': 4.0},
          'route': <dynamic>[],
        },
      });
      expect(ride.rider, isNull);
      expect(ride.chatUnread, 0);
    });
  });

  group('WaitingPolicy', () {
    test('parses the charging terms', () {
      final p = WaitingPolicy.fromJson({
        'arrived_at': '2026-08-30T10:00:00Z',
        'free_wait_seconds': 180,
        'per_minute_pence': 30,
        'no_show_after_seconds': 300,
        'no_show_fee_pence': 5900,
        'billable_from': '2026-08-30T10:03:00Z',
        'currency': 'GBP',
      });

      expect(p.freeWaitSeconds, 180);
      expect(p.perMinutePence, const Pence(30));
      expect(p.noShowFeePence, const Pence(5900));
      expect(p.noShowAfterSeconds, 300);
    });

    test('reports free seconds remaining from billable_from', () {
      final p = WaitingPolicy.fromJson({
        'free_wait_seconds': 180,
        'per_minute_pence': 30,
        'no_show_fee_pence': 0,
        'billable_from': DateTime.now()
            .toUtc()
            .add(const Duration(seconds: 60))
            .toIso8601String(),
        'currency': 'GBP',
      });

      expect(p.freeSecondsRemaining, closeTo(60, 2));
      expect(p.isBillable, isFalse);
    });

    test('reports billable once the free period has passed', () {
      final p = WaitingPolicy.fromJson({
        'free_wait_seconds': 180,
        'per_minute_pence': 30,
        'no_show_fee_pence': 0,
        'billable_from': DateTime.now()
            .toUtc()
            .subtract(const Duration(seconds: 10))
            .toIso8601String(),
        'currency': 'GBP',
      });

      expect(p.isBillable, isTrue);
      expect(p.freeSecondsRemaining, 0);
    });

    test('a policy with no billable_from is not billable', () {
      final p = WaitingPolicy.fromJson({
        'free_wait_seconds': 180,
        'per_minute_pence': 30,
        'no_show_fee_pence': 0,
        'currency': 'GBP',
      });
      expect(p.isBillable, isFalse);
    });
  });
}
