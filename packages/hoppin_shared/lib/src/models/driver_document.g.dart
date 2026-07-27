// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'driver_document.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DriverDocument _$DriverDocumentFromJson(Map<String, dynamic> json) =>
    _DriverDocument(
      id: json['id'] as String,
      documentType: json['document_type'] as String,
      verificationStatus: json['verification_status'] as String,
      uploadedAt: DateTime.parse(json['uploaded_at'] as String),
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.parse(json['expires_at'] as String),
    );

Map<String, dynamic> _$DriverDocumentToJson(_DriverDocument instance) =>
    <String, dynamic>{
      'id': instance.id,
      'document_type': instance.documentType,
      'verification_status': instance.verificationStatus,
      'uploaded_at': instance.uploadedAt.toIso8601String(),
      'expires_at': instance.expiresAt?.toIso8601String(),
    };
