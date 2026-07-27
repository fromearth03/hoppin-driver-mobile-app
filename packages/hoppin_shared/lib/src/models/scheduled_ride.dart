import 'package:freezed_annotation/freezed_annotation.dart';

part 'scheduled_ride.freezed.dart';
part 'scheduled_ride.g.dart';

/// A future booking — `/scheduled-rides` (docs/04). Must be ≥30 minutes out;
/// a server-side watchdog converts it to an active ride near pickup time.
/// Status: pending | searching_for_driver | converted_to_active_ride.
@freezed
abstract class ScheduledRide with _$ScheduledRide {
  const factory ScheduledRide({
    required String id,
    @JsonKey(name: 'rider_id') String? riderId,
    @JsonKey(name: 'requested_pickup_time') required DateTime requestedPickupTime,
    @JsonKey(name: 'estimated_fare_id') String? estimatedFareId,
    @Default('pending') String status,
    @JsonKey(name: 'active_ride_id') String? activeRideId,
  }) = _ScheduledRide;

  factory ScheduledRide.fromJson(Map<String, dynamic> json) =>
      _$ScheduledRideFromJson(json);
}
