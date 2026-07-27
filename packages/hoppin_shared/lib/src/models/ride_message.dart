import 'package:freezed_annotation/freezed_annotation.dart';

part 'ride_message.freezed.dart';
part 'ride_message.g.dart';

/// One in-trip chat message — `/rides/:id/messages` (docs/04). Only the
/// ride's rider and assigned driver may read/post; posting after completion
/// returns `409 CHAT_CLOSED`.
@freezed
abstract class RideMessage with _$RideMessage {
  const factory RideMessage({
    required String id,
    @JsonKey(name: 'ride_id') String? rideId,
    @JsonKey(name: 'sender_id') required String senderId,
    @JsonKey(name: 'sender_role') String? senderRole,
    required String body,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _RideMessage;

  factory RideMessage.fromJson(Map<String, dynamic> json) =>
      _$RideMessageFromJson(json);
}
