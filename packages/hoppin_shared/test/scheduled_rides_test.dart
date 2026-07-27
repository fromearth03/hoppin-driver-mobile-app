import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

/// Scheduled-rides contract acceptance: [ScheduledRide] is part of the
/// public barrel (this file imports it from `package:hoppin_shared` alone)
/// and round-trips the exact `POST/GET /scheduled-rides` shape docs/04
/// documents — `{ id, rider_id, requested_pickup_time, estimated_fare_id,
/// status, active_ride_id }`.
void main() {
  group('ScheduledRide', () {
    const fullJson = <String, dynamic>{
      'id': 'sched-1',
      'rider_id': 'rider-1',
      'requested_pickup_time': '2026-07-01T08:30:00.000',
      'estimated_fare_id': 'fare-1',
      'status': 'pending',
      'active_ride_id': 'ride-1',
    };

    test('round-trips the documented /scheduled-rides shape', () {
      final scheduled = ScheduledRide.fromJson(fullJson);
      expect(scheduled.id, 'sched-1');
      expect(scheduled.riderId, 'rider-1');
      expect(scheduled.requestedPickupTime, DateTime(2026, 7, 1, 8, 30));
      expect(scheduled.estimatedFareId, 'fare-1');
      expect(scheduled.status, 'pending');
      expect(scheduled.activeRideId, 'ride-1');
      expect(jsonDecode(jsonEncode(scheduled.toJson())), fullJson);
    });

    test('nullable fields tolerate the pre-conversion row', () {
      // A freshly booked ride has no fare snapshot and no active ride yet.
      final scheduled = ScheduledRide.fromJson(const {
        'id': 'sched-2',
        'rider_id': null,
        'requested_pickup_time': '2026-07-01T08:30:00.000',
        'estimated_fare_id': null,
        'status': 'pending',
        'active_ride_id': null,
      });
      expect(scheduled.riderId, isNull);
      expect(scheduled.estimatedFareId, isNull);
      expect(scheduled.activeRideId, isNull);
      final reparsed = ScheduledRide.fromJson(
        jsonDecode(jsonEncode(scheduled.toJson())) as Map<String, dynamic>,
      );
      expect(reparsed, scheduled);
    });

    test('status defaults to pending when the server omits it', () {
      final scheduled = ScheduledRide.fromJson(const {
        'id': 'sched-3',
        'requested_pickup_time': '2026-07-01T08:30:00.000',
      });
      expect(scheduled.status, 'pending');
    });
  });
}
