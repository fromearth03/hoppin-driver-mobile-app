import 'package:freezed_annotation/freezed_annotation.dart';

part 'fare_estimate.freezed.dart';
part 'fare_estimate.g.dart';

/// The breakdown returned inside `POST /rides/estimate` — the same `Quote()`
/// dispatch and the final charge use, so the app shows exactly what will be
/// charged. All amounts are GBP. `total = max(gross, minimum)`.
@freezed
abstract class Quote with _$Quote {
  const factory Quote({
    required double base,
    required double distance,
    required double time,
    @JsonKey(name: 'service_fee') required double serviceFee,
    required double subtotal,
    required double multiplier,
    required double surge,
    required double gross,
    required double minimum,
    required double total,
  }) = _Quote;

  factory Quote.fromJson(Map<String, dynamic> json) => _$QuoteFromJson(json);
}

/// The full `POST /rides/estimate` response. There is no `fare_id` here — the
/// on-demand booking path (`POST /rides/request`) re-prices server-side; the
/// low-level `POST /rides` path needs a pre-computed `fare_id` obtained
/// elsewhere.
@freezed
abstract class FareEstimate with _$FareEstimate {
  const factory FareEstimate({
    required Quote estimate,
    @JsonKey(name: 'distance_meters') required int distanceMeters,
    @JsonKey(name: 'duration_seconds') required int durationSeconds,
    @JsonKey(name: 'vehicle_category_id') String? vehicleCategoryId,
  }) = _FareEstimate;

  factory FareEstimate.fromJson(Map<String, dynamic> json) =>
      _$FareEstimateFromJson(json);
}
