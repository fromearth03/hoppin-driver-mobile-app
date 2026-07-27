import 'package:freezed_annotation/freezed_annotation.dart';

part 'sos_event.freezed.dart';
part 'sos_event.g.dart';

/// A panic/SOS event — `POST/GET /me/sos` (docs/04 · Safety). Surfaces on the
/// admin safety dashboard. Status flows active → acknowledged → resolved.
@freezed
abstract class SosEvent with _$SosEvent {
  const factory SosEvent({
    required String id,
    @JsonKey(name: 'ride_id') String? rideId,
    @JsonKey(name: 'triggered_by') String? triggeredBy,
    required String status,
    double? lat,
    double? lng,
    @JsonKey(name: 'live_share_url') String? liveShareUrl,
    String? note,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _SosEvent;

  factory SosEvent.fromJson(Map<String, dynamic> json) =>
      _$SosEventFromJson(json);
}
