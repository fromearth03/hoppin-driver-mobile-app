import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
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
  ///
  /// The handler acknowledges with `{"message": ...}` and no ride id, so the
  /// caller supplies the one the offer already carried. Parsing an id out of
  /// that acknowledgement threw on a *successful* accept, leaving the driver
  /// assigned to a ride the app never opened.
  Future<Result<String>> accept(String offerId,
      {required String rideId}) async {
    final r = await _api.post<Map<String, dynamic>>('/offers/$offerId/accept');
    return r.when(
      // `ride_id` is optional on the offer payload and defaults to empty, so
      // a dispatch record missing it would otherwise route the driver to
      // `/trip/` - a path that matches nothing. They would land back on Home
      // with the offer already cleared and no word of what went wrong, while
      // the server holds them assigned to the job.
      ok: (_) => rideId.isEmpty
          ? Err(ApiException('NO_RIDE_ID',
              'the accept succeeded but carried no ride to open', 0))
          : Ok(rideId),
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
