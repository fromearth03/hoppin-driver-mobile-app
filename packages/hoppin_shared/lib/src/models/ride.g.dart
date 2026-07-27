// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ride.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Ride _$RideFromJson(Map<String, dynamic> json) => _Ride(
  id: json['id'] as String,
  riderId: json['rider_id'] as String,
  driverId: json['driver_id'] as String?,
  vehicleId: json['vehicle_id'] as String?,
  fareId: json['fare_id'] as String?,
  rideCategory: json['ride_category'] as String?,
  status: $enumDecode(
    _$RideStatusEnumMap,
    json['status'],
    unknownValue: RideStatus.unknown,
  ),
  idempotencyKey: json['idempotency_key'] as String?,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
  updatedAt: json['updated_at'] == null
      ? null
      : DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$RideToJson(_Ride instance) => <String, dynamic>{
  'id': instance.id,
  'rider_id': instance.riderId,
  'driver_id': instance.driverId,
  'vehicle_id': instance.vehicleId,
  'fare_id': instance.fareId,
  'ride_category': instance.rideCategory,
  'status': _$RideStatusEnumMap[instance.status]!,
  'idempotency_key': instance.idempotencyKey,
  'created_at': instance.createdAt?.toIso8601String(),
  'updated_at': instance.updatedAt?.toIso8601String(),
};

const _$RideStatusEnumMap = {
  RideStatus.requested: 'requested',
  RideStatus.matching: 'matching',
  RideStatus.assigned: 'assigned',
  RideStatus.accepted: 'accepted',
  RideStatus.arriving: 'arriving',
  RideStatus.started: 'started',
  RideStatus.completed: 'completed',
  RideStatus.cancelled: 'cancelled',
  RideStatus.unknown: 'unknown',
};
