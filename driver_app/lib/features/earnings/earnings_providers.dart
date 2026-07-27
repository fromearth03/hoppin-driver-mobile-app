import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

/// The driver's wallet — `GET /drivers/me/wallet` (seam #47, WIRED).
///
/// Balances and payout runs are real. Everything the Figma earnings frames
/// draw beyond them — per-trip breakdown, commission/VAT split, next-payout
/// date, threshold — has no endpoint, and the earnings screen discloses that
/// rather than deriving it. A breakdown inferred from two balances would be an
/// invented breakdown.
///
/// Not autoDispose: the driver bounces between the dashboard and earnings, and
/// re-fetching balances on every visit is both slow and pointless — the figure
/// only moves at trip completion and at payout.
final driverWalletProvider = FutureProvider<DriverWallet?>((ref) async {
  return ref.watch(driverRepositoryProvider).wallet();
});

/// Stripe Connect payout readiness — `GET /me/payout-account`.
///
/// 🔴 This is the gate on whether ANY of the balance above can ever reach a
/// bank account, and the driver app never asked for it: `POST /me/payout-account`
/// (create the Connect account + get the hosted onboarding link) and this read
/// both shipped on the server and had zero callers. A driver could accrue an
/// available balance with no way to set up where it goes.
///
/// `autoDispose` so returning from the Stripe-hosted flow re-reads rather than
/// showing the pre-onboarding state the driver just finished clearing.
final payoutStatusProvider = FutureProvider.autoDispose<PayoutStatus>((ref) {
  return ref.watch(driverRepositoryProvider).payoutStatus();
});
