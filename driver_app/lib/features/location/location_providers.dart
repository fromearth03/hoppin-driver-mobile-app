import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'location_service.dart';

/// The driver-app-local location seam.
///
/// It lives HERE, not in `hoppin_shared/providers.dart`, on purpose: the
/// isolation contract says `geolocator` / `permission_handler` imports never
/// leak into `hoppin_shared` / `hoppin_demo` / `hoppin_ui`. The default IS the
/// live implementation; the demo composition overrides it with
/// [FakeDriverLocationService], and tests override it with scripted doubles.
// In a demo build (DEMO_MODE) use the fake fixed-location service so the web
// demo never needs real GPS or a permission dialog and the driver still emits
// a Wolverhampton location into dispatch. Production defaults to the real
// geolocator implementation.
const _demoModeEnabled = bool.fromEnvironment('DEMO_MODE', defaultValue: false);

final driverLocationServiceProvider = Provider<DriverLocationService>(
  (ref) => _demoModeEnabled
      ? const FakeDriverLocationService()
      : const GeolocatorDriverLocationService(),
);

/// The demo/dev location double — a fixed fix near the `DemoSeed` origin
/// (Wolverhampton). It never touches an OS API, so the demo build never
/// triggers a permission dialog and never depends on a machine having GPS.
class FakeDriverLocationService implements DriverLocationService {
  const FakeDriverLocationService();

  /// Wolverhampton — the demo world's origin.
  static const ({double lat, double lng}) fix = (lat: 52.5862, lng: -2.1281);

  @override
  Future<DriverLocationPermission> requestPermission() async =>
      DriverLocationPermission.granted;

  @override
  Future<DriverLocationPermission> requestBackgroundPermission() async =>
      DriverLocationPermission.granted;

  @override
  Future<DriverLocationCoverage> coverage() async =>
      DriverLocationCoverage.full;

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<({double lat, double lng})?> currentPosition({
    Duration timeout = const Duration(seconds: 10),
  }) async =>
      fix;

  /// The demo world is PARKED: a confident zero.
  ///
  /// Not `null` — null would mean "the platform does not know", and the demo
  /// platform knows perfectly well. A confident 0.0 m/s keeps the demo driver's
  /// composer and controls all live, which is what a demo needs.
  @override
  Future<DriverFix?> currentFix({
    Duration timeout = const Duration(seconds: 10),
  }) async =>
      (lat: fix.lat, lng: fix.lng, speedMps: 0.0);

  @override
  Future<bool> openSettings() async => true;
}
