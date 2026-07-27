// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_method.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PaymentMethod _$PaymentMethodFromJson(Map<String, dynamic> json) =>
    _PaymentMethod(
      paymentMethodId: json['paymentMethodId'] as String,
      brand: json['brand'] as String?,
      last4: json['last4'] as String?,
      expMonth: (json['expMonth'] as num?)?.toInt(),
      expYear: (json['expYear'] as num?)?.toInt(),
      isDefault: json['isDefault'] as bool? ?? false,
    );

Map<String, dynamic> _$PaymentMethodToJson(_PaymentMethod instance) =>
    <String, dynamic>{
      'paymentMethodId': instance.paymentMethodId,
      'brand': instance.brand,
      'last4': instance.last4,
      'expMonth': instance.expMonth,
      'expYear': instance.expYear,
      'isDefault': instance.isDefault,
    };

_SetupIntentInfo _$SetupIntentInfoFromJson(Map<String, dynamic> json) =>
    _SetupIntentInfo(
      setupIntentId: json['setupIntentId'] as String,
      clientSecret: json['clientSecret'] as String,
      customerId: json['customerId'] as String?,
      provider: json['provider'] as String?,
    );

Map<String, dynamic> _$SetupIntentInfoToJson(_SetupIntentInfo instance) =>
    <String, dynamic>{
      'setupIntentId': instance.setupIntentId,
      'clientSecret': instance.clientSecret,
      'customerId': instance.customerId,
      'provider': instance.provider,
    };
