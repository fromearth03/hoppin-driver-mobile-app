// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saved_location.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SavedLocation _$SavedLocationFromJson(Map<String, dynamic> json) =>
    _SavedLocation(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      label: json['label'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );

Map<String, dynamic> _$SavedLocationToJson(_SavedLocation instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'label': instance.label,
      'lat': instance.lat,
      'lng': instance.lng,
    };
