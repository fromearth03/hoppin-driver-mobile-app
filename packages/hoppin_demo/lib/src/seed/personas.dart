import 'demo_seed.dart';

/// A seeded person in the demo world.
class DemoPersona {
  const DemoPersona({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.roleClaim,
    required this.rating,
    required this.tripsCount,
  });

  final String userId;
  final String fullName;
  final String email;

  /// The `user_role` app-metadata claim: `'rider'` or `'driver'`.
  final String roleClaim;

  /// Star rating shown in the apps.
  final double rating;

  /// Lifetime completed trips — the social-proof line on identity cards.
  final int tripsCount;
}

/// A seeded vehicle.
class DemoVehicle {
  const DemoVehicle({
    required this.make,
    required this.model,
    required this.colour,
    required this.plate,
  });

  final String make;
  final String model;
  final String colour;

  /// Current GB plate with the Birmingham DVLA memory tag (B — covers
  /// Wolverhampton and the West Midlands).
  final String plate;
}

/// The demo cast. The signed-in pair (rider + driver) plus the drivers who
/// ran the seeded history trips — Phase 4's capability seam consumes the
/// driver identity and vehicle from here.
abstract final class DemoPersonas {
  /// The rider the demo signs in as.
  static const rider = DemoPersona(
    userId: DemoSeed.riderId,
    fullName: 'Sophie Bell',
    email: 'demo.rider@hoppin.uk',
    roleClaim: 'rider',
    rating: 4.8,
    tripsCount: 86,
  );

  /// The driver the demo signs in as.
  static const driver = DemoPersona(
    userId: DemoSeed.driverId,
    fullName: 'Gurpreet Singh',
    email: 'demo.driver@hoppin.uk',
    roleClaim: 'driver',
    rating: 4.9,
    tripsCount: 1480,
  );

  /// The demo driver's car.
  static const driverVehicle = DemoVehicle(
    make: 'Toyota',
    model: 'Prius',
    colour: 'Silver',
    plate: 'BK72 WNH',
  );

  /// Drivers for the seeded past trips, each with a valid West Midlands
  /// plate. History screens render these names and cars.
  static const historyCast = <({DemoPersona persona, DemoVehicle vehicle})>[
    (
      persona: DemoPersona(
        userId: 'b0000000-0000-4000-8000-000000000001',
        fullName: 'Amara Okafor',
        email: 'amara.okafor@hoppin.uk',
        roleClaim: 'driver',
        rating: 4.9,
        tripsCount: 2350,
      ),
      vehicle: DemoVehicle(
        make: 'Skoda',
        model: 'Octavia',
        colour: 'Grey',
        plate: 'BD23 VXA',
      ),
    ),
    (
      persona: DemoPersona(
        userId: 'b0000000-0000-4000-8000-000000000002',
        fullName: 'Tomasz Kowalski',
        email: 'tomasz.kowalski@hoppin.uk',
        roleClaim: 'driver',
        rating: 4.8,
        tripsCount: 890,
      ),
      vehicle: DemoVehicle(
        make: 'Volkswagen',
        model: 'Passat',
        colour: 'Black',
        plate: 'BG70 KTM',
      ),
    ),
    (
      persona: DemoPersona(
        userId: 'b0000000-0000-4000-8000-000000000003',
        fullName: 'Fatima Begum',
        email: 'fatima.begum@hoppin.uk',
        roleClaim: 'driver',
        rating: 5.0,
        tripsCount: 640,
      ),
      vehicle: DemoVehicle(
        make: 'Kia',
        model: 'Niro',
        colour: 'White',
        plate: 'BJ21 RFD',
      ),
    ),
    (
      persona: DemoPersona(
        userId: 'b0000000-0000-4000-8000-000000000004',
        fullName: 'Rhian Evans',
        email: 'rhian.evans@hoppin.uk',
        roleClaim: 'driver',
        rating: 4.7,
        tripsCount: 1710,
      ),
      vehicle: DemoVehicle(
        make: 'Ford',
        model: 'Focus',
        colour: 'Blue',
        plate: 'BL69 HWS',
      ),
    ),
    (
      persona: DemoPersona(
        userId: 'b0000000-0000-4000-8000-000000000005',
        fullName: 'Mohammed Hussain',
        email: 'mohammed.hussain@hoppin.uk',
        roleClaim: 'driver',
        rating: 4.9,
        tripsCount: 2900,
      ),
      vehicle: DemoVehicle(
        make: 'Toyota',
        model: 'Corolla',
        colour: 'Red',
        plate: 'BV24 NCP',
      ),
    ),
  ];
}
