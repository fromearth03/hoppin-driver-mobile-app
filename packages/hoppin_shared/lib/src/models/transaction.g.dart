// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Transaction _$TransactionFromJson(Map<String, dynamic> json) => _Transaction(
  id: json['id'] as String,
  rideId: json['ride_id'] as String?,
  amountPence: (json['amount_pence'] as num).toInt(),
  currency: json['currency'] as String? ?? 'GBP',
  status: json['status'] as String?,
  provider: json['provider'] as String?,
  providerPaymentId: json['provider_payment_id'] as String?,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$TransactionToJson(_Transaction instance) =>
    <String, dynamic>{
      'id': instance.id,
      'ride_id': instance.rideId,
      'amount_pence': instance.amountPence,
      'currency': instance.currency,
      'status': instance.status,
      'provider': instance.provider,
      'provider_payment_id': instance.providerPaymentId,
      'created_at': instance.createdAt?.toIso8601String(),
    };
