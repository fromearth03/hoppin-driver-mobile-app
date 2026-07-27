import 'package:freezed_annotation/freezed_annotation.dart';

part 'receipt.freezed.dart';
part 'receipt.g.dart';

/// Itemised receipt for a completed ride — `GET /rides/:id/receipt`.
/// Amounts are **integer pence** (docs/04), currency GBP.
@freezed
abstract class Receipt with _$Receipt {
  const factory Receipt({
    @JsonKey(name: 'ride_id') required String rideId,
    @JsonKey(name: 'ride_category') String? rideCategory,
    @JsonKey(name: 'fare_pence') required int farePence,
    @JsonKey(name: 'waiting_pence') @Default(0) int waitingPence,
    @JsonKey(name: 'total_pence') required int totalPence,
    @JsonKey(name: 'platform_commission_pence') int? platformCommissionPence,
    @Default('GBP') String currency,
    String? status,
    @JsonKey(name: 'distance_miles') double? distanceMiles,
    @JsonKey(name: 'pickup_time') DateTime? pickupTime,
    @JsonKey(name: 'dropoff_time') DateTime? dropoffTime,
    @JsonKey(name: 'provider_payment_id') String? providerPaymentId,
  }) = _Receipt;

  factory Receipt.fromJson(Map<String, dynamic> json) =>
      _$ReceiptFromJson(json);
}
