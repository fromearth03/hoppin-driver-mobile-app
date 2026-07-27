// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'promo_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PromoResult _$PromoResultFromJson(Map<String, dynamic> json) => _PromoResult(
  promoCode: json['promo_code'] as String,
  discountType: json['discount_type'] as String?,
  originalFare: (json['original_fare'] as num).toDouble(),
  discountAmount: (json['discount_amount'] as num).toDouble(),
  newFare: (json['new_fare'] as num).toDouble(),
);

Map<String, dynamic> _$PromoResultToJson(_PromoResult instance) =>
    <String, dynamic>{
      'promo_code': instance.promoCode,
      'discount_type': instance.discountType,
      'original_fare': instance.originalFare,
      'discount_amount': instance.discountAmount,
      'new_fare': instance.newFare,
    };
