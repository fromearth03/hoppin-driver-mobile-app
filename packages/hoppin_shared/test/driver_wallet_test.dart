import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

import 'support/fake_auth_service.dart';
import 'support/scripted_http_adapter.dart';

/// `GET /drivers/me/wallet` — the POUNDS→PENCE boundary.
///
/// 🔴 WHY THIS FILE EXISTS AT ALL.
///
/// The two driver money endpoints disagree about units, and the disagreement is
/// invisible at every call site because both are just numbers:
///
///   `GET /drivers/me/today`  → `earnings_pence`     int, PENCE
///   `GET /drivers/me/wallet` → `available_balance`  float, POUNDS
///
/// `driver_wallets.available_balance` is `DECIMAL(10,2)` and the handler serves
/// it unmultiplied, while `/today` does its own `SUM(amount) * 100` in SQL. So
/// the client sees two money fields, one 100× the other, with nothing in the
/// type system to tell them apart.
///
/// Get it backwards and £245.80 renders as £2.45 on the screen a self-employed
/// person uses to decide whether they have been paid. These tests pin the
/// conversion so a future refactor that "tidies" the ×100 away fails here
/// instead of in someone's bank account.
void main() {
  ({ApiClient api, ScriptedHttpAdapter adapter}) build(
    Map<String, dynamic> walletBody,
  ) {
    final adapter = ScriptedHttpAdapter({
      '/drivers/me/wallet': [ScriptedReply(200, walletBody)],
    });
    final dio = Dio()..httpClientAdapter = adapter;
    return (api: ApiClient(auth: FakeAuthService(), dio: dio), adapter: adapter);
  }

  /// The shape the Go handler serves (`DriverWalletView`), with realistic
  /// values: pounds as floats, an ISO timestamp, ten recent payouts trimmed
  /// to two here.
  const liveBody = <String, dynamic>{
    'available_balance': 245.80,
    'pending_balance': 90.29,
    'currency': 'GBP',
    'last_payout_at': '2026-07-13T09:00:00.000Z',
    'recent_payouts': [
      {
        'id': 'payout-1',
        'amount': 205.10,
        'status': 'paid',
        'transferred_at': '2026-07-13T09:00:00.000Z',
      },
      {
        'id': 'payout-2',
        'amount': 302.30,
        'status': 'failed',
        'transferred_at': null,
      },
    ],
  };

  test('pounds are converted to pence at the repository boundary', () async {
    final repo = DriverRepository(build(liveBody).api);
    final wallet = (await repo.wallet())!;

    // 245.80 POUNDS from the wire → 24580 PENCE to the client. Not 245.
    expect(wallet.availableBalancePence, 24580);
    expect(wallet.pendingBalancePence, 9029);
    expect(wallet.currency, 'GBP');
  });

  test('🔴 the conversion ROUNDS — .toInt() shaves a penny on some values',
      () async {
    // Binary floating point cannot represent most two-decimal pounds exactly.
    // Which ones break is NOT obvious by eye: 245.80 * 100 is exactly 24580.0,
    // but 0.29 * 100 is 28.999999999999996 and 1.15 * 100 is 114.99999999999999.
    // `.toInt()` truncates toward zero, so those two become 28 and 114 — a
    // penny lost, always in the platform's favour, on a self-employed person's
    // pay. `.round()` is therefore load-bearing, not stylistic.
    //
    // These two literals are the demonstration. Because the failure is
    // value-dependent, a spot-check of a "typical" balance would pass while the
    // bug sat there waiting for a specific number.
    expect((0.29 * 100).toInt(), 28, reason: 'the trap this guards');
    expect((1.15 * 100).toInt(), 114, reason: 'the trap this guards');

    final repo = DriverRepository(
      build(const {
        'available_balance': 0.29,
        'pending_balance': 1.15,
        'currency': 'GBP',
        'last_payout_at': null,
        'recent_payouts': <dynamic>[],
      }).api,
    );
    final wallet = (await repo.wallet())!;
    expect(wallet.availableBalancePence, 29, reason: 'rounded, not truncated');
    expect(wallet.pendingBalancePence, 115, reason: 'rounded, not truncated');
  });

  test('payout rows convert and preserve the server status verbatim', () async {
    final repo = DriverRepository(build(liveBody).api);
    final wallet = (await repo.wallet())!;

    expect(wallet.recentPayouts, hasLength(2));

    final paid = wallet.recentPayouts.first;
    expect(paid.id, 'payout-1');
    expect(paid.amountPence, 20510);
    expect(paid.transferredAt, DateTime.parse('2026-07-13T09:00:00.000Z'));

    // 🔴 The status token is rendered as the server spelled it. The payout
    // vocabulary is unpublished, so a token we do not recognise must never be
    // silently relabelled into one we do.
    expect(paid.status, 'paid');
    expect(wallet.recentPayouts[1].status, 'failed');

    // A failed payout has no transfer timestamp, and that must stay null
    // rather than defaulting to "now" — a failed payout dated today reads as
    // a successful one.
    expect(wallet.recentPayouts[1].transferredAt, isNull);
  });

  test('a wallet with no payouts yet is empty, not null', () async {
    final repo = DriverRepository(
      build(const {
        'available_balance': 0,
        'pending_balance': 0,
        'currency': 'GBP',
        'last_payout_at': null,
        'recent_payouts': <dynamic>[],
      }).api,
    );
    final wallet = (await repo.wallet())!;

    expect(wallet.availableBalancePence, 0);
    expect(wallet.pendingBalancePence, 0);
    expect(wallet.lastPayoutAt, isNull);
    expect(wallet.recentPayouts, isEmpty);
  });

  test('integer-valued pounds convert exactly', () async {
    // The wire may serve `100` rather than `100.00` for a round figure — JSON
    // has one number type and Go will elide the decimals. Both are `num`.
    final repo = DriverRepository(
      build(const {
        'available_balance': 100,
        'pending_balance': 0,
        'currency': 'GBP',
        'last_payout_at': null,
        'recent_payouts': <dynamic>[],
      }).api,
    );
    final wallet = (await repo.wallet())!;
    expect(wallet.availableBalancePence, 10000);
  });

  test('absent money fields read as zero, never as null-shaped garbage',
      () async {
    final repo = DriverRepository(
      build(const {
        'currency': 'GBP',
        'recent_payouts': <dynamic>[],
      }).api,
    );
    final wallet = (await repo.wallet())!;
    expect(wallet.availableBalancePence, 0);
    expect(wallet.pendingBalancePence, 0);
  });
}
