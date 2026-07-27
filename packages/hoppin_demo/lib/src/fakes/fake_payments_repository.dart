import 'package:hoppin_shared/hoppin_shared.dart';

import '../world/demo_world.dart';

/// The payments surface over [DemoWorld] — transactions delegate to the
/// world (seeded history rows plus session completions); the saved card is
/// one seeded Visa and card mutations are off-script.
class FakePaymentsRepository implements PaymentsRepository {
  FakePaymentsRepository(this._world);

  final DemoWorld _world;

  /// The rider's one saved card — Stripe's canonical Visa test number tail.
  static const PaymentMethod _seededCard = PaymentMethod(
    paymentMethodId: 'pm_demo_visa_4242',
    brand: 'visa',
    last4: '4242',
    expMonth: 8,
    expYear: 2029,
    isDefault: true,
  );

  /// Attaching a real card needs the Stripe SDK — never a demo beat.
  @override
  Future<SetupIntentInfo> createSetupIntent() =>
      throw UnsupportedError('Not part of the demo');

  @override
  Future<List<PaymentMethod>> paymentMethods() async => const [_seededCard];

  @override
  Future<void> setDefault(String paymentMethodId) async {}

  @override
  Future<void> removeCard(String paymentMethodId) async {}

  @override
  Future<List<Transaction>> transactions({int limit = 50}) async =>
      _world.transactions(limit: limit);
}
