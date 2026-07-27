// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scheduled_ride.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ScheduledRide _$ScheduledRideFromJson(Map<String, dynamic> json) =>
    _ScheduledRide(
      id: json['id'] as String,
      riderId: json['rider_id'] as String?,
      requestedPickupTime: DateTime.parse(
        json['requested_pickup_time'] as String,
      ),
      estimatedFareId: json['estimated_fare_id'] as String?,
      status: json['status'] as String? ?? 'pending',
      activeRideId: json['active_ride_id'] as String?,
    );

Map<String, dynamic> _$ScheduledRideToJson(_ScheduledRide instance) =>
    <String, dynamic>{
      'id': instance.id,
      'rider_id': instance.riderId,
      'requested_pickup_time': instance.requestedPickupTime.toIso8601String(),
      'estimated_fare_id': instance.estimatedFareId,
      'status': instance.status,
      'active_ride_id': instance.activeRideId,
    };
