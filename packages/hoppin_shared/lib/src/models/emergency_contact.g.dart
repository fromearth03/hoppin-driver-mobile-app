// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'emergency_contact.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_EmergencyContact _$EmergencyContactFromJson(Map<String, dynamic> json) =>
    _EmergencyContact(
      id: json['id'] as String,
      contactName: json['contact_name'] as String,
      phoneNumber: json['phone_number'] as String,
      relationship: json['relationship'] as String?,
      autoShareNightTrips: json['auto_share_night_trips'] as bool? ?? false,
    );

Map<String, dynamic> _$EmergencyContactToJson(_EmergencyContact instance) =>
    <String, dynamic>{
      'id': instance.id,
      'contact_name': instance.contactName,
      'phone_number': instance.phoneNumber,
      'relationship': instance.relationship,
      'auto_share_night_trips': instance.autoShareNightTrips,
    };
