import 'package:freezed_annotation/freezed_annotation.dart';

part 'ride_geo.freezed.dart';
part 'ride_geo.g.dart';

/// One vertex of a route polyline.
@freezed
abstract class GeoPoint with _$GeoPoint {
  const factory GeoPoint({
    required double lat,
    required double lng,
  }) = _GeoPoint;

  factory GeoPoint.fromJson(Map<String, dynamic> json) =>
      _$GeoPointFromJson(json);
}

/// Static route geometry for one ride — the pickup/dropoff pins plus the
/// polylines the map draws.
///
/// `GET /rides/:id` carries no coordinates (CODE-GRAPH §6 #17 / DOCS/06 P1),
/// so [RidesRepository.rideGeo] answers null in production and the demo
/// serves the scripted Wolverhampton track. [approach] (driver start →
/// pickup) is demo-only richness — a future live endpoint will likely omit
/// it, and consumers must tolerate null.
@freezed
abstract class RideGeo with _$RideGeo {
  const factory RideGeo({
    @JsonKey(name: 'pickup_lat') required double pickupLat,
    @JsonKey(name: 'pickup_lng') required double pickupLng,
    @JsonKey(name: 'dropoff_lat') required double dropoffLat,
    @JsonKey(name: 'dropoff_lng') required double dropoffLng,

    /// The pickup→dropoff route polyline, ordered.
    required List<GeoPoint> route,

    /// The driver-start→pickup approach polyline; null when unknown.
    List<GeoPoint>? approach,
  }) = _RideGeo;

  factory RideGeo.fromJson(Map<String, dynamic> json) =>
      _$RideGeoFromJson(json);
}
