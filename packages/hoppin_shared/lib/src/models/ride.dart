import 'package:freezed_annotation/freezed_annotation.dart';

part 'ride.freezed.dart';
part 'ride.g.dart';

/// The ride lifecycle status. Union of the values documented on
/// `POST /rides` and the admin ride model (docs/04 · Ride lifecycle):
/// requested → matching/assigned → accepted → arriving → started
///   → completed | cancelled.
enum RideStatus {
  requested,
  matching,
  assigned,
  accepted,
  arriving,
  started,
  completed,
  cancelled,
  @JsonValue('unknown')
  unknown,
}

extension RideStatusX on RideStatus {
  /// The ride reached an end state — nothing more will happen to it.
  bool get isTerminal =>
      this == RideStatus.completed || this == RideStatus.cancelled;

  /// A live trip the rider/driver is currently involved in.
  bool get isActive => !isTerminal && this != RideStatus.unknown;
}

/// A ride row as returned by `GET /rides/:id`, `GET /rides`, `POST /rides`.
///
/// `driver_id` is null until matched. Money fields are pounds unless the field
/// name ends in `_pence`.
@freezed
abstract class Ride with _$Ride {
  const factory Ride({
    required String id,
    @JsonKey(name: 'rider_id') required String riderId,
    @JsonKey(name: 'driver_id') String? driverId,
    @JsonKey(name: 'vehicle_id') String? vehicleId,
    @JsonKey(name: 'fare_id') String? fareId,
    @JsonKey(name: 'ride_category') String? rideCategory,
    @JsonKey(unknownEnumValue: RideStatus.unknown)
    required RideStatus status,
    @JsonKey(name: 'idempotency_key') String? idempotencyKey,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _Ride;

  factory Ride.fromJson(Map<String, dynamic> json) => _$RideFromJson(json);
}
