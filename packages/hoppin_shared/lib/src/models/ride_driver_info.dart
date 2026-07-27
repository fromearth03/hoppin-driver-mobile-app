import 'package:freezed_annotation/freezed_annotation.dart';

part 'ride_driver_info.freezed.dart';
part 'ride_driver_info.g.dart';

/// The matched driver's identity, vehicle, and live-trip telemetry for one
/// ride — the DEMO-07 capability-seam payload.
///
/// The live ride-service (`:8080`) exposes no driver-identity or telemetry
/// endpoint yet, so [RidesRepository.driverInfo] answers null in production
/// and the demo world assembles this from its seeded cast. JSON keys are
/// snake_case so a future backend endpoint slots in without model churn.
@freezed
abstract class RideDriverInfo with _$RideDriverInfo {
  const RideDriverInfo._();

  const factory RideDriverInfo({
    @JsonKey(name: 'full_name') required String fullName,
    @JsonKey(name: 'photo_url') String? photoUrl,
    required double rating,
    @JsonKey(name: 'trips_count') required int tripsCount,
    @JsonKey(name: 'vehicle_make') required String vehicleMake,
    @JsonKey(name: 'vehicle_model') required String vehicleModel,
    @JsonKey(name: 'vehicle_colour') required String vehicleColour,
    required String plate,

    /// Seconds until the driver reaches the pickup — non-null only while a
    /// live ride is en route (the demo serves the world's clock-delta value).
    @JsonKey(name: 'eta_seconds') int? etaSeconds,

    /// Journey origin label (e.g. 'Wolverhampton Rail Station'); null when
    /// the route cannot be resolved to a named place.
    @JsonKey(name: 'origin_label') String? originLabel,

    /// Journey destination label; null when unresolvable.
    @JsonKey(name: 'destination_label') String? destinationLabel,
  }) = _RideDriverInfo;

  factory RideDriverInfo.fromJson(Map<String, dynamic> json) =>
      _$RideDriverInfoFromJson(json);

  /// Avatar fallback initials derived from [fullName]: first letter of the
  /// first and last words ('Gurpreet Singh' -> 'GS'), a single word's first
  /// letter, or '?' for an empty name — never throws.
  String get initials {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}
