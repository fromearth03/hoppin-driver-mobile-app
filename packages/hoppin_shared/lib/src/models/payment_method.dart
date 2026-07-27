import 'package:freezed_annotation/freezed_annotation.dart';

part 'payment_method.freezed.dart';
part 'payment_method.g.dart';

/// A saved card — `GET /me/payment-methods` (docs/04). NOTE: these endpoints
/// proxy the Java payment service, which emits **camelCase** keys (unlike the
/// Go endpoints' snake_case).
@freezed
abstract class PaymentMethod with _$PaymentMethod {
  const factory PaymentMethod({
    required String paymentMethodId,
    String? brand,
    String? last4,
    int? expMonth,
    int? expYear,
    @Default(false) bool isDefault,
  }) = _PaymentMethod;

  factory PaymentMethod.fromJson(Map<String, dynamic> json) =>
      _$PaymentMethodFromJson(json);
}

/// `POST /me/payment-methods/setup-intent` — confirm [clientSecret] with the
/// Stripe SDK to attach a reusable card (native mobile builds only).
@freezed
abstract class SetupIntentInfo with _$SetupIntentInfo {
  const factory SetupIntentInfo({
    required String setupIntentId,
    required String clientSecret,
    String? customerId,
    String? provider,
  }) = _SetupIntentInfo;

  factory SetupIntentInfo.fromJson(Map<String, dynamic> json) =>
      _$SetupIntentInfoFromJson(json);
}
