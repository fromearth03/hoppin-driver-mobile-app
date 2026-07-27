import 'package:freezed_annotation/freezed_annotation.dart';

part 'driver_position.freezed.dart';
part 'driver_position.g.dart';

/// The driver's live position for one active ride — the MAP-03 geo
/// capability-seam payload.
///
/// Deliberately shaped as the DOCS/06 gap #41 ask
/// (`GET /rides/:id/driver-location` → `{ lat, lng, heading, updated_at }`)
/// so the live implementation is a straight deserialization when the
/// endpoint ships. Until then [RidesRepository.driverPosition] answers null
/// in production and the demo world derives this from its deterministic
/// Wolverhampton geo-track.
@freezed
abstract class DriverPosition with _$DriverPosition {
  const factory DriverPosition({
    required double lat,
    required double lng,

    /// Degrees clockwise from north, `[0, 360)`; null when the source has no
    /// heading (consumers fall back to the track segment's bearing).
    double? heading,
    @JsonKey(name: 'updated_at') required DateTime updatedAt,
  }) = _DriverPosition;

  factory DriverPosition.fromJson(Map<String, dynamic> json) =>
      _$DriverPositionFromJson(json);
}
