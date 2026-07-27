import 'package:hoppin_shared/hoppin_shared.dart';

import '../world/demo_world.dart';

/// The `/me/*` profile surface over [DemoWorld] — saved locations delegate
/// to the world (seeded Home + Work, session add/delete); emergency contacts
/// and device tokens are off-script constants and no-ops.
class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository(this._world);

  final DemoWorld _world;

  /// The fixed contact any add returns — 07700 900xxx is Ofcom's reserved
  /// fictional mobile range, so the number can never dial a real person.
  static const EmergencyContact _seededContact = EmergencyContact(
    id: 'c2000000-0000-4000-8000-000000000001',
    contactName: 'Hannah Bell',
    phoneNumber: '+44 7700 900123',
    relationship: 'Sister',
  );

  /// Demo avatar upload: accepts the bytes and hands back a stable fake URL.
  /// Nothing is stored — the demo has no object store — but the call must
  /// SUCCEED so the profile screen exercises its real post-upload path rather
  /// than its error path.
  @override
  Future<String> uploadAvatar({
    required List<int> bytes,
    required String filename,
  }) async =>
      'https://demo.hoppin.tech/api/v1/images/avatars/users/demo/avatar.jpg';

  @override
  Future<List<SavedLocation>> savedLocations() async =>
      _world.savedLocations();

  @override
  Future<SavedLocation> addSavedLocation({
    required String label,
    required double lat,
    required double lng,
  }) async =>
      _world.addSavedLocation(label: label, lat: lat, lng: lng);

  @override
  Future<void> deleteSavedLocation(String id) async =>
      _world.deleteSavedLocation(id);

  @override
  Future<List<EmergencyContact>> emergencyContacts() async => const [];

  @override
  Future<EmergencyContact> addEmergencyContact({
    required String contactName,
    required String phoneNumber,
    String? relationship,
    bool autoShareNightTrips = false,
  }) async =>
      _seededContact;

  @override
  Future<void> deleteEmergencyContact(String id) async {}

  @override
  Future<void> registerDeviceToken({
    required String fcmToken,
    required String deviceOs,
  }) async {}
}
