import 'package:freezed_annotation/freezed_annotation.dart';

part 'promo_result.freezed.dart';
part 'promo_result.g.dart';

/// Result of applying a promo code to a ride — `POST /rides/:id/promo`.
/// Amounts in pounds (docs/04).
@freezed
abstract class PromoResult with _$PromoResult {
  const factory PromoResult({
    @JsonKey(name: 'promo_code') required String promoCode,
    @JsonKey(name: 'discount_type') String? discountType,
    @JsonKey(name: 'original_fare') required double originalFare,
    @JsonKey(name: 'discount_amount') required double discountAmount,
    @JsonKey(name: 'new_fare') required double newFare,
  }) = _PromoResult;

  factory PromoResult.fromJson(Map<String, dynamic> json) =>
      _$PromoResultFromJson(json);
}
