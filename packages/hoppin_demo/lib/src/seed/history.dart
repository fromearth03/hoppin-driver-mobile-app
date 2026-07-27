import 'package:hoppin_shared/hoppin_shared.dart';

import 'demo_seed.dart';
import 'personas.dart';
import 'places.dart';

/// One completed past trip: the ride row, its receipt, the route, and the
/// driver who ran it — materialized as the same freezed models the screens
/// consume from the live API.
class DemoTrip {
  const DemoTrip({
    required this.ride,
    required this.receipt,
    required this.pickup,
    required this.dropoff,
    required this.driver,
  });

  final Ride ride;
  final Receipt receipt;
  final DemoPlace pickup;
  final DemoPlace dropoff;
  final ({DemoPersona persona, DemoVehicle vehicle}) driver;
}

/// A single completed-trip payout in the driver's seeded morning.
class DemoPayout {
  const DemoPayout({required this.completedAt, required this.amountPence});

  final DateTime completedAt;
  final int amountPence;
}

/// The demo driver's seeded morning: what the earnings tile shows before the
/// scripted live trip ticks it up (there is no live earnings endpoint —
/// DemoWorld owns this state).
class DemoEarnings {
  const DemoEarnings({
    required this.totalPence,
    required this.tripCount,
    required this.onlineSince,
    required this.onlineDuration,
    required this.payouts,
  });

  final int totalPence;
  final int tripCount;
  final DateTime onlineSince;
  final Duration onlineDuration;

  /// Per-trip payouts, oldest first — DemoWorld appends to this as scripted
  /// trips complete.
  final List<DemoPayout> payouts;
}

/// Seeded rider history and driver morning earnings, every timestamp derived
/// from [DemoSeed.anchor] — never the wall clock.
abstract final class DemoHistory {
  /// Seven completed trips over the three weeks before the anchor,
  /// newest first (the order `GET /rides` returns).
  static final List<DemoTrip> trips = List<DemoTrip>.unmodifiable([
    _trip(
      id: 'e0000000-0000-4000-8000-000000000001',
      beforeAnchor: const Duration(hours: 16),
      inCar: const Duration(minutes: 14),
      pickup: DemoPlaces.cityCentre,
      dropoff: DemoPlaces.bentleyBridge,
      driver: DemoPersonas.historyCast[0],
      farePence: 725,
      distanceMiles: 2.6,
    ),
    _trip(
      id: 'e0000000-0000-4000-8000-000000000002',
      beforeAnchor: const Duration(days: 1, hours: 20),
      inCar: const Duration(minutes: 11),
      pickup: DemoPlaces.university,
      dropoff: DemoPlaces.newCrossHospital,
      driver: DemoPersonas.historyCast[1],
      farePence: 640,
      distanceMiles: 2.2,
    ),
    _trip(
      id: 'e0000000-0000-4000-8000-000000000003',
      beforeAnchor: const Duration(days: 4, hours: 1),
      inCar: const Duration(minutes: 9),
      pickup: DemoPlaces.home,
      dropoff: DemoPlaces.railStation,
      driver: DemoPersonas.historyCast[2],
      farePence: 585,
      waitingPence: 120,
      distanceMiles: 1.9,
    ),
    _trip(
      id: 'e0000000-0000-4000-8000-000000000004',
      beforeAnchor: const Duration(days: 6, hours: 22),
      inCar: const Duration(minutes: 15),
      pickup: DemoPlaces.cityCentre,
      dropoff: DemoPlaces.newCrossHospital,
      driver: DemoPersonas.historyCast[3],
      farePence: 690,
      distanceMiles: 2.4,
    ),
    _trip(
      id: 'e0000000-0000-4000-8000-000000000005',
      beforeAnchor: const Duration(days: 9, hours: 20),
      inCar: const Duration(minutes: 10),
      pickup: DemoPlaces.molineuxStadium,
      dropoff: DemoPlaces.bentleyBridge,
      driver: DemoPersonas.historyCast[4],
      farePence: 655,
      distanceMiles: 2.1,
    ),
    _trip(
      id: 'e0000000-0000-4000-8000-000000000006',
      beforeAnchor: const Duration(days: 13, hours: 2),
      inCar: const Duration(minutes: 13),
      pickup: DemoPlaces.newCrossHospital,
      dropoff: DemoPlaces.home,
      driver: DemoPersonas.historyCast[0],
      farePence: 750,
      distanceMiles: 2.7,
    ),
    _trip(
      id: 'e0000000-0000-4000-8000-000000000007',
      beforeAnchor: const Duration(days: 19, hours: 23),
      inCar: const Duration(minutes: 11),
      pickup: DemoPlaces.railStation,
      dropoff: DemoPlaces.newCrossHospital,
      driver: DemoPersonas.historyCast[1],
      farePence: 639,
      distanceMiles: 2.1,
    ),
  ]);

  /// Just the ride rows, newest first — what the fake `history()` serves.
  static final List<Ride> rides = List<Ride>.unmodifiable([
    for (final trip in trips) trip.ride,
  ]);

  /// Receipt lookup by ride id — what the fake `receipt()` serves.
  static final Map<String, Receipt> receiptsByRideId =
      Map<String, Receipt>.unmodifiable({
    for (final trip in trips) trip.ride.id: trip.receipt,
  });

  /// The driver's seeded morning: online since 06:20, five completed trips
  /// since 06:40, GBP 43.75 total, 3h 10m online at the anchor.
  static final DemoEarnings morningEarnings = DemoEarnings(
    totalPence: 4375,
    tripCount: 5,
    onlineSince:
        DemoSeed.anchor.subtract(const Duration(hours: 3, minutes: 10)),
    onlineDuration: const Duration(hours: 3, minutes: 10),
    payouts: List<DemoPayout>.unmodifiable([
      DemoPayout(
        completedAt:
            DemoSeed.anchor.subtract(const Duration(hours: 2, minutes: 50)),
        amountPence: 785,
      ),
      DemoPayout(
        completedAt:
            DemoSeed.anchor.subtract(const Duration(hours: 2, minutes: 15)),
        amountPence: 920,
      ),
      DemoPayout(
        completedAt:
            DemoSeed.anchor.subtract(const Duration(hours: 1, minutes: 32)),
        amountPence: 655,
      ),
      DemoPayout(
        completedAt: DemoSeed.anchor.subtract(const Duration(minutes: 43)),
        amountPence: 1240,
      ),
      DemoPayout(
        completedAt: DemoSeed.anchor.subtract(const Duration(minutes: 18)),
        amountPence: 775,
      ),
    ]),
  );

  static DemoTrip _trip({
    required String id,
    required Duration beforeAnchor,
    required Duration inCar,
    required DemoPlace pickup,
    required DemoPlace dropoff,
    required ({DemoPersona persona, DemoVehicle vehicle}) driver,
    required int farePence,
    required double distanceMiles,
    int waitingPence = 0,
  }) {
    final createdAt = DemoSeed.anchor.subtract(beforeAnchor);
    final pickupTime = createdAt.add(const Duration(minutes: 3));
    final dropoffTime = pickupTime.add(inCar);
    final totalPence = farePence + waitingPence;
    return DemoTrip(
      ride: Ride(
        id: id,
        riderId: DemoSeed.riderId,
        driverId: driver.persona.userId,
        rideCategory: 'standard',
        status: RideStatus.completed,
        createdAt: createdAt,
        updatedAt: dropoffTime,
      ),
      receipt: Receipt(
        rideId: id,
        rideCategory: 'standard',
        farePence: farePence,
        waitingPence: waitingPence,
        totalPence: totalPence,
        platformCommissionPence: (totalPence * 0.20).round(),
        status: 'paid',
        distanceMiles: distanceMiles,
        pickupTime: pickupTime,
        dropoffTime: dropoffTime,
      ),
      pickup: pickup,
      dropoff: dropoff,
      driver: driver,
    );
  }
}
