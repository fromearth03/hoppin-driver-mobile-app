import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/result.dart';
import 'models/payout_status.dart';

class PayoutRepository {
  final ApiClient _api;
  PayoutRepository(this._api);

  Future<Result<PayoutStatus>> status() async {
    final r = await _api.get<Map<String, dynamic>>('/me/payout-account');
    return r.when(
      ok: (json) => Ok(PayoutStatus.fromJson(json)),
      err: (e) => Err(e),
    );
  }

  /// Returns a Stripe-hosted onboarding link. The driver enters their bank
  /// details on Stripe's page, never in this app.
  Future<Result<PayoutOnboarding>> startOnboarding() async {
    final r = await _api.post<Map<String, dynamic>>('/me/payout-account');
    return r.when(
      ok: (json) => Ok(PayoutOnboarding.fromJson(json)),
      err: (e) => Err(e),
    );
  }
}

final payoutRepositoryProvider = Provider<PayoutRepository>(
    (ref) => PayoutRepository(ref.watch(apiClientProvider)));
