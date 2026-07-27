import '../api/api_client.dart';
import '../models/payment_method.dart';
import '../models/transaction.dart';

/// Payment bindings (docs/04 · Payment methods + transactions).
///
/// The card endpoints proxy the Java payment service (Stripe): when it's off
/// they return `503 PAYMENTS_DISABLED`; provider failures are
/// `502 PAYMENT_ERROR` with a sanitised message. `GET /me/transactions` reads
/// the local DB and works regardless.
class PaymentsRepository {
  PaymentsRepository(this._api);

  final ApiClient _api;

  /// `POST /me/payment-methods/setup-intent` — start saving a card. Confirm
  /// the returned `clientSecret` with the Stripe SDK (native builds) to
  /// attach a reusable card.
  Future<SetupIntentInfo> createSetupIntent() async {
    final res = await _api
        .post<Map<String, dynamic>>('/me/payment-methods/setup-intent');
    return SetupIntentInfo.fromJson(res.data!);
  }

  /// `GET /me/payment-methods` — saved cards (`[]` when none).
  Future<List<PaymentMethod>> paymentMethods() async {
    final res = await _api.get<List<dynamic>>('/me/payment-methods');
    return (res.data ?? [])
        .map((e) => PaymentMethod.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `POST /me/payment-methods/:pmId/default` — the card used for
  /// off-session ride charges.
  Future<void> setDefault(String paymentMethodId) =>
      _api.post<Map<String, dynamic>>(
        '/me/payment-methods/$paymentMethodId/default',
      );

  /// `DELETE /me/payment-methods/:pmId` — detach a card.
  Future<void> removeCard(String paymentMethodId) =>
      _api.delete<Map<String, dynamic>>(
        '/me/payment-methods/$paymentMethodId',
      );

  /// `GET /me/transactions` — my payment history, integer pence.
  Future<List<Transaction>> transactions({int limit = 50}) async {
    final res =
        await _api.get<List<dynamic>>('/me/transactions', query: {
      'limit': limit,
    });
    return (res.data ?? [])
        .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
