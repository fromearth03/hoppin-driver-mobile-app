// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fare_estimate.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Quote _$QuoteFromJson(Map<String, dynamic> json) => _Quote(
  base: (json['base'] as num).toDouble(),
  distance: (json['distance'] as num).toDouble(),
  time: (json['time'] as num).toDouble(),
  serviceFee: (json['service_fee'] as num).toDouble(),
  subtotal: (json['subtotal'] as num).toDouble(),
  multiplier: (json['multiplier'] as num).toDouble(),
  surge: (json['surge'] as num).toDouble(),
  gross: (json['gross'] as num).toDouble(),
  minimum: (json['minimum'] as num).toDouble(),
  total: (json['total'] as num).toDouble(),
);

Map<String, dynamic> _$QuoteToJson(_Quote instance) => <String, dynamic>{
  'base': instance.base,
  'distance': instance.distance,
  'time': instance.time,
  'service_fee': instance.serviceFee,
  'subtotal': instance.subtotal,
  'multiplier': instance.multiplier,
  'surge': instance.surge,
  'gross': instance.gross,
  'minimum': instance.minimum,
  'total': instance.total,
};

_FareEstimate _$FareEstimateFromJson(Map<String, dynamic> json) =>
    _FareEstimate(
      estimate: Quote.fromJson(json['estimate'] as Map<String, dynamic>),
      distanceMeters: (json['distance_meters'] as num).toInt(),
      durationSeconds: (json['duration_seconds'] as num).toInt(),
      vehicleCategoryId: json['vehicle_category_id'] as String?,
    );

Map<String, dynamic> _$FareEstimateToJson(_FareEstimate instance) =>
    <String, dynamic>{
      'estimate': instance.estimate,
      'distance_meters': instance.distanceMeters,
      'duration_seconds': instance.durationSeconds,
      'vehicle_category_id': instance.vehicleCategoryId,
    };
