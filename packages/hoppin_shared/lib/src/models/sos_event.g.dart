// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sos_event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SosEvent _$SosEventFromJson(Map<String, dynamic> json) => _SosEvent(
  id: json['id'] as String,
  rideId: json['ride_id'] as String?,
  triggeredBy: json['triggered_by'] as String?,
  status: json['status'] as String,
  lat: (json['lat'] as num?)?.toDouble(),
  lng: (json['lng'] as num?)?.toDouble(),
  liveShareUrl: json['live_share_url'] as String?,
  note: json['note'] as String?,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$SosEventToJson(_SosEvent instance) => <String, dynamic>{
  'id': instance.id,
  'ride_id': instance.rideId,
  'triggered_by': instance.triggeredBy,
  'status': instance.status,
  'lat': instance.lat,
  'lng': instance.lng,
  'live_share_url': instance.liveShareUrl,
  'note': instance.note,
  'created_at': instance.createdAt?.toIso8601String(),
};
