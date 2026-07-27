// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ride_driver_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RideDriverInfo _$RideDriverInfoFromJson(Map<String, dynamic> json) =>
    _RideDriverInfo(
      fullName: json['full_name'] as String,
      photoUrl: json['photo_url'] as String?,
      rating: (json['rating'] as num).toDouble(),
      tripsCount: (json['trips_count'] as num).toInt(),
      vehicleMake: json['vehicle_make'] as String,
      vehicleModel: json['vehicle_model'] as String,
      vehicleColour: json['vehicle_colour'] as String,
      plate: json['plate'] as String,
      etaSeconds: (json['eta_seconds'] as num?)?.toInt(),
      originLabel: json['origin_label'] as String?,
      destinationLabel: json['destination_label'] as String?,
    );

Map<String, dynamic> _$RideDriverInfoToJson(_RideDriverInfo instance) =>
    <String, dynamic>{
      'full_name': instance.fullName,
      'photo_url': instance.photoUrl,
      'rating': instance.rating,
      'trips_count': instance.tripsCount,
      'vehicle_make': instance.vehicleMake,
      'vehicle_model': instance.vehicleModel,
      'vehicle_colour': instance.vehicleColour,
      'plate': instance.plate,
      'eta_seconds': instance.etaSeconds,
      'origin_label': instance.originLabel,
      'destination_label': instance.destinationLabel,
    };
