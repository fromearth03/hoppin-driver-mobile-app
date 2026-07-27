import 'package:dio/dio.dart';

import '../api/api_client.dart';
import '../models/emergency_contact.dart';
import '../models/saved_location.dart';

/// Typed bindings for the `/me/*` profile endpoints on `:8080` (docs/04 ·
/// Account, payments, safety & support).
class ProfileRepository {
  ProfileRepository(this._api);

  final ApiClient _api;

  /// The ceiling the server enforces on a profile photo (8 MB). Exposed so the
  /// picker can refuse an oversized file before spending the upload.
  static const int maxAvatarBytes = 8 * 1024 * 1024;

  /// `POST /me/avatar/upload` — set the caller's profile photo. `[either]`
  ///
  /// Multipart, field name `file`. Works for riders and drivers alike: the
  /// server takes the identity from the JWT, so there is no role branch here.
  ///
  /// Send the ORIGINAL file. The server re-encodes to JPEG and downscales
  /// anything over 1024 px on its long edge, and that re-encode is also what
  /// strips EXIF — so a photo taken at home does not carry its GPS coordinates
  /// into storage. Pre-compressing on the client would not remove EXIF and only
  /// costs quality.
  ///
  /// Returns the absolute `avatar_url` to render. That URL is on the
  /// authenticated `/images/*` route, so loading it needs the bearer — pass
  /// `imageAuthHeadersProvider` to `HopAvatar.headers`.
  ///
  /// Throws [ApiException] on failure; `FILE_TOO_LARGE` is the oversized case
  /// and is worth catching by code to show the limit.
  Future<String> uploadAvatar({
    required List<int> bytes,
    required String filename,
  }) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final res = await _api.post<Map<String, dynamic>>(
      '/me/avatar/upload',
      body: form,
    );
    return (res.data?['avatar_url'] as String?)?.trim() ?? '';
  }

  // ── Saved locations `[rider]` ────────────────────────────────────────────

  /// `GET /me/saved-locations` — the rider's saved places (`[]` when none).
  Future<List<SavedLocation>> savedLocations() async {
    final res = await _api.get<List<dynamic>>('/me/saved-locations');
    return (res.data ?? [])
        .map((e) => SavedLocation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `POST /me/saved-locations` — save a place.
  Future<SavedLocation> addSavedLocation({
    required String label,
    required double lat,
    required double lng,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/me/saved-locations',
      body: {'label': label, 'lat': lat, 'lng': lng},
    );
    return SavedLocation.fromJson(res.data!);
  }

  /// `DELETE /me/saved-locations/:id` — remove a place.
  Future<void> deleteSavedLocation(String id) =>
      _api.delete<Map<String, dynamic>>('/me/saved-locations/$id');

  // ── Emergency contacts `[rider]` ─────────────────────────────────────────

  /// `GET /me/emergency-contacts` (`[]` when none).
  Future<List<EmergencyContact>> emergencyContacts() async {
    final res = await _api.get<List<dynamic>>('/me/emergency-contacts');
    return (res.data ?? [])
        .map((e) => EmergencyContact.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `POST /me/emergency-contacts` — add a contact.
  Future<EmergencyContact> addEmergencyContact({
    required String contactName,
    required String phoneNumber,
    String? relationship,
    bool autoShareNightTrips = false,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/me/emergency-contacts',
      body: {
        'contact_name': contactName,
        'phone_number': phoneNumber,
        if (relationship != null && relationship.isNotEmpty)
          'relationship': relationship,
        'auto_share_night_trips': autoShareNightTrips,
      },
    );
    return EmergencyContact.fromJson(res.data!);
  }

  /// `DELETE /me/emergency-contacts/:id`.
  Future<void> deleteEmergencyContact(String id) =>
      _api.delete<Map<String, dynamic>>('/me/emergency-contacts/$id');

  // ── Device tokens (push) `[either]` ──────────────────────────────────────

  /// `POST /me/device-tokens` — register this device's FCM token.
  /// [deviceOs] must be `"ios"` or `"android"`. Note: pushes are only sent
  /// once the backend has `FCM_CREDENTIALS_FILE` configured (docs/04).
  Future<void> registerDeviceToken({
    required String fcmToken,
    required String deviceOs,
  }) =>
      _api.post<Map<String, dynamic>>(
        '/me/device-tokens',
        body: {'fcm_token': fcmToken, 'device_os': deviceOs},
      );
}
