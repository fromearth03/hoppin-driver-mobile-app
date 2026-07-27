// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ride_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RideMessage _$RideMessageFromJson(Map<String, dynamic> json) => _RideMessage(
  id: json['id'] as String,
  rideId: json['ride_id'] as String?,
  senderId: json['sender_id'] as String,
  senderRole: json['sender_role'] as String?,
  body: json['body'] as String,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$RideMessageToJson(_RideMessage instance) =>
    <String, dynamic>{
      'id': instance.id,
      'ride_id': instance.rideId,
      'sender_id': instance.senderId,
      'sender_role': instance.senderRole,
      'body': instance.body,
      'created_at': instance.createdAt?.toIso8601String(),
    };
