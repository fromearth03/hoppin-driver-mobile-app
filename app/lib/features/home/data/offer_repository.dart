import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/result.dart';
import 'models/pending_offer.dart';

class OfferRepository {
  final ApiClient _api;
  OfferRepository(this._api);

  Future<Result<List<PendingOffer>>> offers() async {
    final r = await _api.get<dynamic>('/drivers/me/offers');
    return r.when(
      ok: (data) {
        // Accepts either an {"offers": [...]} envelope or a bare array — the
        // endpoint has used both shapes and either is unambiguous.
        final list = data is Map
            ? ((data['offers'] as List?) ?? const [])
            : (data as List? ?? const []);
        final received = DateTime.now();
        return Ok(list
            .map((e) => PendingOffer.fromJson(
                Map<String, dynamic>.from(e as Map),
                receivedAt: received))
            .toList());
      },
      err: (e) => Err(e),
    );
  }

  /// Returns the ride id to hand to the trip screen.
  Future<Result<String>> accept(String offerId) async {
    final r = await _api.post<Map<String, dynamic>>('/offers/$offerId/accept');
    return r.when(
      ok: (json) => Ok((json['ride_id'] ?? json['id']) as String),
      err: (e) => Err(e),
    );
  }

  Future<Result<void>> decline(String offerId) async {
    final r = await _api.post<dynamic>('/offers/$offerId/decline');
    return r.when(ok: (_) => const Ok(null), err: (e) => Err(e));
  }
}

final offerRepositoryProvider = Provider<OfferRepository>(
    (ref) => OfferRepository(ref.watch(apiClientProvider)));
