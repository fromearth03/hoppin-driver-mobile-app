/// A driver's Stripe Connect payout readiness — `GET /me/payout-account`.
///
/// Two independent facts, and conflating them is the trap:
///  * [connected] — a Stripe Express account EXISTS for this driver.
///  * [payoutsEnabled] — Stripe has cleared them to actually RECEIVE money.
///
/// A driver can be connected and still not payable: Stripe flips
/// `payouts_enabled` only after identity and bank verification pass, which can
/// take hours or bounce back asking for more. Showing "you're all set" on
/// [connected] alone would tell a driver they will be paid when they will not.
class PayoutStatus {
  const PayoutStatus({
    this.connected = false,
    this.payoutsEnabled = false,
    this.accountID,
  });

  factory PayoutStatus.fromJson(Map<String, dynamic> json) {
    final id = (json['account_id'] as String?)?.trim();
    return PayoutStatus(
      connected: json['connected'] as bool? ?? false,
      payoutsEnabled: json['payouts_enabled'] as bool? ?? false,
      accountID: (id == null || id.isEmpty) ? null : id,
    );
  }

  /// A Stripe account exists. Says nothing about whether money can move.
  final bool connected;

  /// Stripe has verified them and payouts can actually land.
  final bool payoutsEnabled;

  /// `acct_…`. Null before onboarding has ever started.
  final String? accountID;

  /// Nothing started — the driver has never opened onboarding.
  bool get notStarted => !connected;

  /// Account exists but Stripe has not cleared payouts. The driver has more to
  /// do (or is waiting on Stripe's review); the UI must say so plainly.
  bool get pendingVerification => connected && !payoutsEnabled;

  /// Fully payable.
  bool get ready => connected && payoutsEnabled;

  Map<String, dynamic> toJson() => {
        'connected': connected,
        'payouts_enabled': payoutsEnabled,
        'account_id': accountID ?? '',
      };

  @override
  bool operator ==(Object other) =>
      other is PayoutStatus &&
      other.connected == connected &&
      other.payoutsEnabled == payoutsEnabled &&
      other.accountID == accountID;

  @override
  int get hashCode => Object.hash(connected, payoutsEnabled, accountID);
}

/// The result of asking to start (or resume) payout onboarding —
/// `POST /me/payout-account`.
///
/// Idempotent server-side: an existing account is reused rather than duplicated.
/// When [alreadyEnabled] is true there is nothing to do and [onboardingURL] is
/// absent — the driver is already payable.
class PayoutOnboarding {
  const PayoutOnboarding({
    this.onboardingURL,
    this.accountID,
    this.alreadyEnabled = false,
  });

  factory PayoutOnboarding.fromJson(Map<String, dynamic> json) {
    final url = (json['onboarding_url'] as String?)?.trim();
    final id = (json['account_id'] as String?)?.trim();
    return PayoutOnboarding(
      onboardingURL: (url == null || url.isEmpty) ? null : url,
      accountID: (id == null || id.isEmpty) ? null : id,
      alreadyEnabled: json['already_enabled'] as bool? ?? false,
    );
  }

  /// Stripe-hosted onboarding link. **Single-use and short-lived** — mint it
  /// when the driver taps, never cache it. Null when [alreadyEnabled].
  final String? onboardingURL;
  final String? accountID;
  final bool alreadyEnabled;

  @override
  bool operator ==(Object other) =>
      other is PayoutOnboarding &&
      other.onboardingURL == onboardingURL &&
      other.accountID == accountID &&
      other.alreadyEnabled == alreadyEnabled;

  @override
  int get hashCode => Object.hash(onboardingURL, accountID, alreadyEnabled);
}
