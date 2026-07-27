import 'package:freezed_annotation/freezed_annotation.dart';

part 'ride_offer.freezed.dart';
part 'ride_offer.g.dart';

/// A pending ride offer dispatched to a driver — an element of the array from
/// `GET /drivers/me/offers`. Pass `offer_id` to accept/decline. (docs/04 ·
/// Driver operations.)
@freezed
abstract class RideOffer with _$RideOffer {
  const factory RideOffer({
    @JsonKey(name: 'offer_id') required String offerId,
    @JsonKey(name: 'ride_id') required String rideId,
    @JsonKey(name: 'pickup_lat') required double pickupLat,
    @JsonKey(name: 'pickup_lng') required double pickupLng,
    @JsonKey(name: 'dropoff_lat') required double dropoffLat,
    @JsonKey(name: 'dropoff_lng') required double dropoffLng,
    required double fare,
    @JsonKey(name: 'estimated_miles') required double estimatedMiles,
    @JsonKey(name: 'expires_at') required DateTime expiresAt,
    @JsonKey(name: 'offered_at') required DateTime offeredAt,
  }) = _RideOffer;

  factory RideOffer.fromJson(Map<String, dynamic> json) =>
      _$RideOfferFromJson(json);
}
