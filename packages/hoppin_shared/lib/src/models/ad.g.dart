// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ad.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Ad _$AdFromJson(Map<String, dynamic> json) => _Ad(
  id: json['id'] as String,
  title: json['title'] as String,
  body: json['body'] as String?,
  imageUrl: json['image_url'] as String?,
  targetUrl: json['target_url'] as String?,
  audience: json['audience'] as String?,
  isActive: json['is_active'] as bool? ?? true,
  startsAt: json['starts_at'] == null
      ? null
      : DateTime.parse(json['starts_at'] as String),
  endsAt: json['ends_at'] == null
      ? null
      : DateTime.parse(json['ends_at'] as String),
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$AdToJson(_Ad instance) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'body': instance.body,
  'image_url': instance.imageUrl,
  'target_url': instance.targetUrl,
  'audience': instance.audience,
  'is_active': instance.isActive,
  'starts_at': instance.startsAt?.toIso8601String(),
  'ends_at': instance.endsAt?.toIso8601String(),
  'created_at': instance.createdAt?.toIso8601String(),
};
