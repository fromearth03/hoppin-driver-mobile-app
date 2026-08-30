/// Whether the driver can actually be paid.
///
/// `connected` means Stripe has an account for them; `payoutsEnabled` means
/// Stripe has cleared it. Both are needed — an account under review is
/// connected but cannot receive money, and telling the driver they are set
/// up would be wrong.
class PayoutStatus {
  final bool connected;
  final bool payoutsEnabled;
  final String? accountId;

  const PayoutStatus({
    this.connected = false,
    this.payoutsEnabled = false,
    this.accountId,
  });

  bool get isReady => connected && payoutsEnabled;

  factory PayoutStatus.fromJson(Map<String, dynamic> json) => PayoutStatus(
        connected: json['connected'] as bool? ?? false,
        payoutsEnabled: json['payouts_enabled'] as bool? ?? false,
        accountId: json['account_id'] as String?,
      );
}

class PayoutOnboarding {
  final String onboardingUrl;
  final String? accountId;
  final bool alreadyEnabled;

  const PayoutOnboarding({
    required this.onboardingUrl,
    this.accountId,
    this.alreadyEnabled = false,
  });

  factory PayoutOnboarding.fromJson(Map<String, dynamic> json) =>
      PayoutOnboarding(
        onboardingUrl: (json['onboarding_url'] as String?) ?? '',
        accountId: json['account_id'] as String?,
        alreadyEnabled: json['already_enabled'] as bool? ?? false,
      );
}
