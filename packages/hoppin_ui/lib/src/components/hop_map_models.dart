/// Pure-Dart vocabulary for HopMap — the ONLY types feature code speaks
/// when driving a map surface.
///
/// Deliberately free of maplibre_gl imports: no map-package type
/// leaks into hoppin_ui's public API, so swapping the tile provider or the
/// whole map engine later stays a one-seam change inside hop_map.dart.
library;

import 'package:flutter/foundation.dart';

/// A WGS84 coordinate — the map seam's own point type.
@immutable
class HopGeoPoint {
  const HopGeoPoint(this.lat, this.lng);

  /// Latitude in decimal degrees.
  final double lat;

  /// Longitude in decimal degrees.
  final double lng;

  @override
  bool operator ==(Object other) =>
      other is HopGeoPoint && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);

  @override
  String toString() => 'HopGeoPoint($lat, $lng)';
}

/// What a pin on the map MEANS — HopMap styles glyph + tone per role from
/// the theme tokens; hosts never pick colours.
enum HopMapPinRole {
  /// Where the rider is collected.
  pickup,

  /// Where the trip ends.
  destination,

  /// The driver's current target (MAP-04 nav context: pickup while heading
  /// there, destination once started).
  objective,
}

/// A styled map pin: a point plus the role that drives its glyph and tone.
@immutable
class HopMapPin {
  const HopMapPin(this.point, this.role);

  /// Where the pin sits.
  final HopGeoPoint point;

  /// What the pin means (drives glyph + tone).
  final HopMapPinRole role;

  @override
  bool operator ==(Object other) =>
      other is HopMapPin && other.point == point && other.role == role;

  @override
  int get hashCode => Object.hash(point, role);

  @override
  String toString() => 'HopMapPin(${role.name}, $point)';
}

/// A route polyline — an ordered list of points drawn as one stroke.
@immutable
class HopMapTrack {
  const HopMapTrack(this.points);

  /// Polyline vertices in draw order.
  final List<HopGeoPoint> points;

  @override
  bool operator ==(Object other) =>
      other is HopMapTrack && listEquals(other.points, points);

  @override
  int get hashCode => Object.hashAll(points);

  @override
  String toString() => 'HopMapTrack(${points.length} points)';
}

/// Declarative camera vocabulary — the host says WHAT to frame; HopMap owns
/// HOW (easing, debounce, gesture-pause). Intents carry value equality so
/// hosts can rebuild cheaply without re-aiming the camera.
sealed class HopMapCameraIntent {
  const HopMapCameraIntent();
}

/// Frame all [points] with padding — MAP-01's driver + pickup fit.
class FitPoints extends HopMapCameraIntent {
  const FitPoints(this.points);

  /// Every point that must stay in frame.
  final List<HopGeoPoint> points;

  @override
  bool operator ==(Object other) =>
      other is FitPoints && listEquals(other.points, points);

  @override
  int get hashCode => Object.hashAll(points);

  @override
  String toString() => 'FitPoints(${points.length} points)';
}

/// Chase [target] with eased, debounced pans — MAP-02/04's follow camera.
class FollowPoint extends HopMapCameraIntent {
  const FollowPoint(this.target);

  /// The point the camera glides after (typically the car).
  final HopGeoPoint target;

  @override
  bool operator ==(Object other) =>
      other is FollowPoint && other.target == target;

  @override
  int get hashCode => target.hashCode;

  @override
  String toString() => 'FollowPoint($target)';
}

/// One eased move to [point], then idle — the completion settle.
class SettleOn extends HopMapCameraIntent {
  const SettleOn(this.point);

  /// Where the camera comes to rest.
  final HopGeoPoint point;

  @override
  bool operator ==(Object other) => other is SettleOn && other.point == point;

  @override
  int get hashCode => point.hashCode;

  @override
  String toString() => 'SettleOn($point)';
}
