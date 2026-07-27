import '../api/api_client.dart';
import '../models/sos_event.dart';

/// SOS / panic bindings — `/me/sos` (docs/04 · Safety). `[either]` role.
class SafetyRepository {
  SafetyRepository(this._api);

  final ApiClient _api;

  /// `POST /me/sos` — raise a panic event (lands on the admin safety
  /// dashboard). `triggered_by` is set server-side from the role; every field
  /// here is optional.
  Future<String> raiseSos({
    String? rideId,
    double? lat,
    double? lng,
    String? note,
    String? liveShareUrl,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/me/sos',
      body: {
        'ride_id': ?rideId,
        'lat': ?lat,
        'lng': ?lng,
        if (note != null && note.isNotEmpty) 'note': note,
        'live_share_url': ?liveShareUrl,
      },
    );
    return res.data!['id'] as String;
  }

  /// `GET /me/sos` — my SOS events (active → acknowledged → resolved).
  Future<List<SosEvent>> myEvents() async {
    final res = await _api.get<List<dynamic>>('/me/sos');
    return (res.data ?? [])
        .map((e) => SosEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
