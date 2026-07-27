import 'package:freezed_annotation/freezed_annotation.dart';

part 'emergency_contact.freezed.dart';
part 'emergency_contact.g.dart';

/// An emergency contact — `/me/emergency-contacts` (docs/04). With
/// `auto_share_night_trips` the platform can share night-trip details.
@freezed
abstract class EmergencyContact with _$EmergencyContact {
  const factory EmergencyContact({
    required String id,
    @JsonKey(name: 'contact_name') required String contactName,
    @JsonKey(name: 'phone_number') required String phoneNumber,
    String? relationship,
    @JsonKey(name: 'auto_share_night_trips')
    @Default(false)
    bool autoShareNightTrips,
  }) = _EmergencyContact;

  factory EmergencyContact.fromJson(Map<String, dynamic> json) =>
      _$EmergencyContactFromJson(json);
}
