import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction.freezed.dart';
part 'transaction.g.dart';

/// A payment transaction — `GET /me/transactions` (docs/04). Local-DB read
/// (snake_case, works even when the payment service is down). Amounts in
/// integer pence.
@freezed
abstract class Transaction with _$Transaction {
  const factory Transaction({
    required String id,
    @JsonKey(name: 'ride_id') String? rideId,
    @JsonKey(name: 'amount_pence') required int amountPence,
    @Default('GBP') String currency,
    String? status,
    String? provider,
    @JsonKey(name: 'provider_payment_id') String? providerPaymentId,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _Transaction;

  factory Transaction.fromJson(Map<String, dynamic> json) =>
      _$TransactionFromJson(json);
}
