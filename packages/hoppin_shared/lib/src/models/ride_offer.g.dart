// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ride_offer.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RideOffer _$RideOfferFromJson(Map<String, dynamic> json) => _RideOffer(
  offerId: json['offer_id'] as String,
  rideId: json['ride_id'] as String,
  pickupLat: (json['pickup_lat'] as num).toDouble(),
  pickupLng: (json['pickup_lng'] as num).toDouble(),
  dropoffLat: (json['dropoff_lat'] as num).toDouble(),
  dropoffLng: (json['dropoff_lng'] as num).toDouble(),
  fare: (json['fare'] as num).toDouble(),
  estimatedMiles: (json['estimated_miles'] as num).toDouble(),
  expiresAt: DateTime.parse(json['expires_at'] as String),
  offeredAt: DateTime.parse(json['offered_at'] as String),
);

Map<String, dynamic> _$RideOfferToJson(_RideOffer instance) =>
    <String, dynamic>{
      'offer_id': instance.offerId,
      'ride_id': instance.rideId,
      'pickup_lat': instance.pickupLat,
      'pickup_lng': instance.pickupLng,
      'dropoff_lat': instance.dropoffLat,
      'dropoff_lng': instance.dropoffLng,
      'fare': instance.fare,
      'estimated_miles': instance.estimatedMiles,
      'expires_at': instance.expiresAt.toIso8601String(),
      'offered_at': instance.offeredAt.toIso8601String(),
    };
