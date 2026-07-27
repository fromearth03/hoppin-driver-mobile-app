// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ride_geo.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_GeoPoint _$GeoPointFromJson(Map<String, dynamic> json) => _GeoPoint(
  lat: (json['lat'] as num).toDouble(),
  lng: (json['lng'] as num).toDouble(),
);

Map<String, dynamic> _$GeoPointToJson(_GeoPoint instance) => <String, dynamic>{
  'lat': instance.lat,
  'lng': instance.lng,
};

_RideGeo _$RideGeoFromJson(Map<String, dynamic> json) => _RideGeo(
  pickupLat: (json['pickup_lat'] as num).toDouble(),
  pickupLng: (json['pickup_lng'] as num).toDouble(),
  dropoffLat: (json['dropoff_lat'] as num).toDouble(),
  dropoffLng: (json['dropoff_lng'] as num).toDouble(),
  route: (json['route'] as List<dynamic>)
      .map((e) => GeoPoint.fromJson(e as Map<String, dynamic>))
      .toList(),
  approach: (json['approach'] as List<dynamic>?)
      ?.map((e) => GeoPoint.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$RideGeoToJson(_RideGeo instance) => <String, dynamic>{
  'pickup_lat': instance.pickupLat,
  'pickup_lng': instance.pickupLng,
  'dropoff_lat': instance.dropoffLat,
  'dropoff_lng': instance.dropoffLng,
  'route': instance.route,
  'approach': instance.approach,
};
