import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/home/data/models/driver_today.dart';

/// The shape GET /drivers/me/today really returns.
Map<String, dynamic> live({String? activeRideId}) => {
      'online': true,
      'earnings_pence': 8450,
      'trip_count': 6,
      'online_seconds': 8100,
      'active_ride_id': activeRideId,
      'pickup_eta_seconds': null,
    };

void main() {
  test('reads the day so far', () {
    final t = DriverToday.fromJson(live());

    expect(t.earnings.pence, 8450);
    expect(t.tripCount, 6);
    expect(t.onlineTime, const Duration(seconds: 8100));
  });

  test('formats online time without seconds', () {
    expect(DriverToday.fromJson(live()).onlineLabel, '2h 15m');
    expect(
      DriverToday.fromJson({'online_seconds': 2700}).onlineLabel,
      '45m',
    );
  });

  test('a day with no activity reads as zero, not an error', () {
    final t = DriverToday.fromJson(const {});

    expect(t.earnings.pence, 0);
    expect(t.tripCount, 0);
    expect(t.onlineLabel, '0m');
    expect(t.hasActiveRide, isFalse);
  });

  test('surfaces a ride still in progress', () {
    final t = DriverToday.fromJson(live(activeRideId: 'r9'));

    // Without this a driver who force-quits mid-job has no route back to
    // Arrive, Start or Complete.
    expect(t.hasActiveRide, isTrue);
    expect(t.activeRideId, 'r9');
  });
}
