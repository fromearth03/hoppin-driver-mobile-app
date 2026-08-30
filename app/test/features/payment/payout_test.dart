import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_client.dart';
import 'package:hoppin_driver/core/auth/token_store.dart';
import 'package:hoppin_driver/features/payment/data/models/payout_status.dart';
import 'package:hoppin_driver/features/payment/data/payout_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockAdapter extends Mock implements HttpClientAdapter {}

void main() {
  setUpAll(() => registerFallbackValue(RequestOptions(path: '/')));

  ResponseBody body(String json, int status) =>
      ResponseBody.fromString(json, status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  late _MockAdapter adapter;
  late PayoutRepository repo;

  setUp(() {
    adapter = _MockAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    repo = PayoutRepository(ApiClient(dio, InMemoryTokenStore()));
  });

  test('a fully onboarded driver is ready', () {
    final s = PayoutStatus.fromJson({
      'connected': true,
      'payouts_enabled': true,
      'account_id': 'acct_123',
    });

    expect(s.isReady, isTrue);
  });

  test('connected but not enabled is not ready', () {
    final s = PayoutStatus.fromJson({
      'connected': true,
      'payouts_enabled': false,
      'account_id': 'acct_123',
    });

    // Stripe has the account but has not cleared it for payouts — the driver
    // still cannot be paid, so the screen must not say they are set up.
    expect(s.isReady, isFalse);
    expect(s.connected, isTrue);
  });

  test('a driver who has never started is neither', () {
    final s = PayoutStatus.fromJson(const {});

    expect(s.connected, isFalse);
    expect(s.isReady, isFalse);
  });

  test('onboarding returns a hosted link, not a form', () async {
    when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async => body(
        '{"onboarding_url":"https://connect.stripe.com/setup/abc",'
        '"account_id":"acct_123","already_enabled":false}',
        200));

    final r = await repo.startOnboarding();

    // The app never collects bank details itself; Stripe's hosted flow does,
    // which is what keeps PCI scope at SAQ-A.
    expect(r.valueOrNull!.onboardingUrl,
        'https://connect.stripe.com/setup/abc');
    expect(r.valueOrNull!.alreadyEnabled, isFalse);
  });

  test('an already-enabled account says so rather than re-onboarding',
      () async {
    when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async => body(
        '{"onboarding_url":"","account_id":"acct_123",'
        '"already_enabled":true}',
        200));

    final r = await repo.startOnboarding();

    expect(r.valueOrNull!.alreadyEnabled, isTrue);
  });
}
