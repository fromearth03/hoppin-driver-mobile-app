import 'package:hoppin_shared/hoppin_shared.dart';

import 'demo_seed.dart';

/// A named point in the demo's Wolverhampton service area.
class DemoPlace {
  const DemoPlace({required this.label, required this.lat, required this.lng});

  final String label;
  final double lat;
  final double lng;
}

/// Wolverhampton landmarks. The six preset coords are copied EXACTLY from the
/// rider app's `wolverhamptonPresets` (apps/rider · booking/place.dart) so a
/// place picked in the picker and a place seeded here are the same point.
abstract final class DemoPlaces {
  static const cityCentre = DemoPlace(
    label: 'City Centre',
    lat: 52.5870,
    lng: -2.1288,
  );
  static const railStation = DemoPlace(
    label: 'Wolverhampton Rail Station',
    lat: 52.5877,
    lng: -2.1200,
  );
  static const university = DemoPlace(
    label: 'University of Wolverhampton',
    lat: 52.5896,
    lng: -2.1276,
  );
  static const newCrossHospital = DemoPlace(
    label: 'New Cross Hospital',
    lat: 52.6046,
    lng: -2.0930,
  );
  static const molineuxStadium = DemoPlace(
    label: 'Molineux Stadium',
    lat: 52.5903,
    lng: -2.1306,
  );
  static const bentleyBridge = DemoPlace(
    label: 'Bentley Bridge Retail Park',
    lat: 52.6006,
    lng: -2.0868,
  );

  /// The rider's home — Tettenhall, a residential-plausible spot.
  static const home = DemoPlace(label: 'Home', lat: 52.594, lng: -2.171);

  /// Same order as the rider app's preset list.
  static const presets = [
    cityCentre,
    railStation,
    university,
    newCrossHospital,
    molineuxStadium,
    bentleyBridge,
  ];

  /// The scripted demo route: short, name-recognizable, fare inside GBP 5-10.
  static const scriptedPickup = railStation;
  static const scriptedDropoff = newCrossHospital;

  /// The rider's two seeded saved locations ("Work" is City Centre).
  static const savedLocations = [
    SavedLocation(
      id: 'c0000000-0000-4000-8000-000000000001',
      userId: DemoSeed.riderId,
      label: 'Home',
      lat: 52.594,
      lng: -2.171,
    ),
    SavedLocation(
      id: 'c0000000-0000-4000-8000-000000000002',
      userId: DemoSeed.riderId,
      label: 'Work',
      lat: 52.5870,
      lng: -2.1288,
    ),
  ];
}
