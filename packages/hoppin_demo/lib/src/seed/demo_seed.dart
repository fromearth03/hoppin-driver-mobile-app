/// The single fixed moment the whole demo world derives from.
///
/// Every seeded timestamp — history trips, receipts, this morning's earnings —
/// is computed from [anchor]; the package never reads the wall clock, so two
/// runs with the same seed are byte-identical (DEMO-04 by construction).
abstract final class DemoSeed {
  /// Deterministic seed every scripted delay in the demo world derives from.
  static const int seed = 42;

  /// The virtual "now": Tuesday 30 June 2026, 09:30 local — a real past
  /// Tuesday morning. Screens favor relative time, so nothing on screen
  /// contradicts the actual wall clock.
  static final DateTime anchor = DateTime(2026, 6, 30, 9, 30);

  /// Prefilled rider login — demo beat 1 is a real sign-in tap.
  static const ({String email, String password}) riderCredentials = (
    email: 'demo.rider@hoppin.uk',
    password: 'hoppin-demo',
  );

  /// Prefilled driver login.
  static const ({String email, String password}) driverCredentials = (
    email: 'demo.driver@hoppin.uk',
    password: 'hoppin-demo',
  );

  /// The seeded promo code — 20% off (percentage type).
  static const String promoCode = 'HOPPIN20';

  /// Fixed identity of the demo rider (Sophie Bell).
  static const String riderId = 'a0000000-0000-4000-8000-000000000001';

  /// Fixed identity of the demo driver (Gurpreet Singh).
  static const String driverId = 'a0000000-0000-4000-8000-000000000002';

  /// Fixed id of the demo driver's vehicle.
  static const String vehicleId = 'a0000000-0000-4000-8000-000000000003';

  /// The four cancellation reason ids the rider app's cancel sheet offers
  /// (apps/rider · trip/cancellation_reasons.dart). The demo world accepts
  /// exactly these and rejects everything else with VALIDATION_FAILED —
  /// the same contract the live `PATCH /rides/:id/cancel` enforces.
  static const List<String> cancellationReasonIds = [
    '00000000-0000-4000-8000-0000000000c1',
    '00000000-0000-4000-8000-0000000000c2',
    '00000000-0000-4000-8000-0000000000c3',
    '00000000-0000-4000-8000-0000000000c4',
  ];
}
