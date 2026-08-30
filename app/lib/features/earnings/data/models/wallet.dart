import '../../../../core/money.dart';

class Payout {
  final String id;
  final Pence amount;
  final String status;
  final DateTime? transferredAt;
  final String? failureReason;

  const Payout({
    required this.id,
    required this.amount,
    required this.status,
    this.transferredAt,
    this.failureReason,
  });

  factory Payout.fromJson(Map<String, dynamic> json) => Payout(
        id: (json['id'] as String?) ?? '',
        amount: Pence.fromPounds(((json['amount'] as num?) ?? 0).toDouble()),
        status: (json['status'] as String?) ?? '',
        transferredAt: json['transferred_at'] == null
            ? null
            : DateTime.tryParse(json['transferred_at'] as String),
        failureReason: json['failure_reason'] as String?,
      );
}

class DriverBonus {
  final String label;
  final Pence amount;
  final DateTime? awardedAt;

  const DriverBonus(
      {required this.label, required this.amount, this.awardedAt});

  factory DriverBonus.fromJson(Map<String, dynamic> json) => DriverBonus(
        label: (json['label'] ?? json['reason'] ?? 'Bonus') as String,
        amount: Pence.fromPounds(((json['amount'] as num?) ?? 0).toDouble()),
        awardedAt: json['awarded_at'] == null
            ? null
            : DateTime.tryParse(json['awarded_at'] as String),
      );
}

/// The driver's balance and payout history.
///
/// This endpoint predates the integer-pence convention and still sends float
/// pounds, so it is the one place `Pence.fromPounds` is used. Everything
/// downstream sees integers.
class Wallet {
  final Pence availableBalance;
  final Pence pendingBalance;
  final String currency;
  final DateTime? lastPayoutAt;
  final List<Payout> recentPayouts;
  final List<DriverBonus> recentBonuses;

  const Wallet({
    required this.availableBalance,
    required this.pendingBalance,
    this.currency = 'GBP',
    this.lastPayoutAt,
    this.recentPayouts = const [],
    this.recentBonuses = const [],
  });

  /// Negative means the driver owes the company.
  bool get owes => availableBalance.isNegative;

  factory Wallet.fromJson(Map<String, dynamic> json) => Wallet(
        availableBalance: Pence.fromPounds(
            ((json['available_balance'] as num?) ?? 0).toDouble()),
        pendingBalance: Pence.fromPounds(
            ((json['pending_balance'] as num?) ?? 0).toDouble()),
        currency: (json['currency'] as String?) ?? 'GBP',
        lastPayoutAt: json['last_payout_at'] == null
            ? null
            : DateTime.tryParse(json['last_payout_at'] as String),
        recentPayouts: ((json['recent_payouts'] as List?) ?? const [])
            .map((e) => Payout.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        recentBonuses: ((json['recent_bonuses'] as List?) ?? const [])
            .map((e) =>
                DriverBonus.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}
