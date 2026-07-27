// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'receipt.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Receipt _$ReceiptFromJson(Map<String, dynamic> json) => _Receipt(
  rideId: json['ride_id'] as String,
  rideCategory: json['ride_category'] as String?,
  farePence: (json['fare_pence'] as num).toInt(),
  waitingPence: (json['waiting_pence'] as num?)?.toInt() ?? 0,
  totalPence: (json['total_pence'] as num).toInt(),
  platformCommissionPence: (json['platform_commission_pence'] as num?)?.toInt(),
  currency: json['currency'] as String? ?? 'GBP',
  status: json['status'] as String?,
  distanceMiles: (json['distance_miles'] as num?)?.toDouble(),
  pickupTime: json['pickup_time'] == null
      ? null
      : DateTime.parse(json['pickup_time'] as String),
  dropoffTime: json['dropoff_time'] == null
      ? null
      : DateTime.parse(json['dropoff_time'] as String),
  providerPaymentId: json['provider_payment_id'] as String?,
);

Map<String, dynamic> _$ReceiptToJson(_Receipt instance) => <String, dynamic>{
  'ride_id': instance.rideId,
  'ride_category': instance.rideCategory,
  'fare_pence': instance.farePence,
  'waiting_pence': instance.waitingPence,
  'total_pence': instance.totalPence,
  'platform_commission_pence': instance.platformCommissionPence,
  'currency': instance.currency,
  'status': instance.status,
  'distance_miles': instance.distanceMiles,
  'pickup_time': instance.pickupTime?.toIso8601String(),
  'dropoff_time': instance.dropoffTime?.toIso8601String(),
  'provider_payment_id': instance.providerPaymentId,
};
