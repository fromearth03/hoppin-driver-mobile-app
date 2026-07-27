import 'package:freezed_annotation/freezed_annotation.dart';

part 'saved_location.freezed.dart';
part 'saved_location.g.dart';

/// A rider's saved place — `GET/POST /me/saved-locations` (docs/04).
/// List items are `{ id, label, lat, lng }`; create also returns `user_id`.
@freezed
abstract class SavedLocation with _$SavedLocation {
  const factory SavedLocation({
    required String id,
    @JsonKey(name: 'user_id') String? userId,
    required String label,
    required double lat,
    required double lng,
  }) = _SavedLocation;

  factory SavedLocation.fromJson(Map<String, dynamic> json) =>
      _$SavedLocationFromJson(json);
}
