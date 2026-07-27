import '../api/api_client.dart';
import '../models/ad.dart';

/// In-app ads — `GET /ads` + engagement reporting (docs/04). `[either]`;
/// the audience comes from the JWT role, the app never sends it.
class AdsRepository {
  AdsRepository(this._api);

  final ApiClient _api;

  /// `GET /ads` — active, audience-matched banners (`[]` when none).
  Future<List<Ad>> activeAds() async {
    final res = await _api.get<List<dynamic>>('/ads');
    return (res.data ?? [])
        .map((e) => Ad.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `POST /ads/:id/impression` — fire-and-forget; failures are swallowed
  /// (analytics must never break the UI).
  Future<void> reportImpression(String adId) async {
    try {
      await _api.post<Map<String, dynamic>>('/ads/$adId/impression');
    } on Exception {
      // ignore — engagement reporting is best-effort
    }
  }

  /// `POST /ads/:id/click` — same best-effort contract.
  Future<void> reportClick(String adId) async {
    try {
      await _api.post<Map<String, dynamic>>('/ads/$adId/click');
    } on Exception {
      // ignore
    }
  }
}
