// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'driver_position.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DriverPosition _$DriverPositionFromJson(Map<String, dynamic> json) =>
    _DriverPosition(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      heading: (json['heading'] as num?)?.toDouble(),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$DriverPositionToJson(_DriverPosition instance) =>
    <String, dynamic>{
      'lat': instance.lat,
      'lng': instance.lng,
      'heading': instance.heading,
      'updated_at': instance.updatedAt.toIso8601String(),
    };
