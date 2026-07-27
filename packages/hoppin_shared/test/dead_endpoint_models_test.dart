import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

/// Contract acceptance for the three reads the apps had left unwired while the
/// server was already serving them: `/api/v1/contacts`, `/vehicle-types` and
/// `/me/payout-account`.
void main() {
  group('PlatformContacts', () {
    test('round-trips the live row shape', () {
      // Verbatim from the deployed endpoint.
      final c = PlatformContacts.fromJson(const {
        'support_email': 'help@hoppin.app',
        'support_phone': '+44 20 7946 0000',
        'emergency_phone': '+44 20 7946 0999',
        'whatsapp_number': '+44 7700 900000',
      });
      expect(c.supportEmail, 'help@hoppin.app');
      expect(c.supportPhone, '+44 20 7946 0000');
      expect(c.emergencyPhone, '+44 20 7946 0999');
      expect(c.whatsappNumber, '+44 7700 900000');
      expect(c.hasAny, isTrue);
    });

    test('BLANK strings collapse to null — the server sends "" for absent', () {
      // The handler returns blanks rather than erroring on a missing row. A
      // blank must read as "we have no number", never as a printable one.
      final c = PlatformContacts.fromJson(const {
        'support_email': '',
        'support_phone': '   ',
        'emergency_phone': '',
        'whatsapp_number': '',
      });
      expect(c.supportEmail, isNull);
      expect(c.supportPhone, isNull);
      expect(c.isEmpty, isTrue,
          reason: 'an all-blank row must let the UI keep its honest '
              '"tickets only" copy rather than print empty contact rows');
    });

    test('a partially-filled row exposes only what exists', () {
      final c = PlatformContacts.fromJson(const {
        'support_email': 'help@hoppin.app',
        'support_phone': '',
      });
      expect(c.supportEmail, isNotNull);
      expect(c.supportPhone, isNull);
      expect(c.hasAny, isTrue);
    });
  });

  group('VehicleType', () {
    test('round-trips the /vehicle-types row', () {
      final v = VehicleType.fromJson(const {
        'id': 'b1000000-0000-4000-8000-000000000001',
        'name': 'Standard',
        'seats': 4,
        'bags': 2,
        'price_multiplier': 1.0,
      });
      expect(v.id, 'b1000000-0000-4000-8000-000000000001');
      expect(v.name, 'Standard');
      expect(v.seats, 4);
      expect(v.bags, 2);
      expect(v.priceMultiplier, 1.0);
    });

    test('unset seats/bags default to 0 so the UI can omit the line', () {
      final v = VehicleType.fromJson(const {'id': 'x', 'name': 'XL'});
      expect(v.seats, 0);
      expect(v.bags, 0);
      expect(v.priceMultiplier, 1.0);
    });
  });

  group('PayoutStatus', () {
    test('connected but NOT enabled is its own state, not "ready"', () {
      // The trap: a driver with a Stripe account may still be unverified.
      // Telling them they are set up would promise money that cannot move.
      final s = PayoutStatus.fromJson(const {
        'connected': true,
        'payouts_enabled': false,
        'account_id': 'acct_123',
      });
      expect(s.connected, isTrue);
      expect(s.pendingVerification, isTrue);
      expect(s.ready, isFalse);
      expect(s.notStarted, isFalse);
    });

    test('fully verified reads as ready', () {
      final s = PayoutStatus.fromJson(const {
        'connected': true,
        'payouts_enabled': true,
        'account_id': 'acct_123',
      });
      expect(s.ready, isTrue);
      expect(s.pendingVerification, isFalse);
    });

    test('never onboarded reads as notStarted with a null account', () {
      final s = PayoutStatus.fromJson(const {
        'connected': false,
        'payouts_enabled': false,
        'account_id': '',
      });
      expect(s.notStarted, isTrue);
      expect(s.accountID, isNull,
          reason: 'an empty account id is absence, not an id of ""');
    });

    test('a missing body degrades to not-started rather than throwing', () {
      expect(PayoutStatus.fromJson(const {}).notStarted, isTrue);
    });
  });

  group('PayoutOnboarding', () {
    test('carries the hosted link for a driver who must still onboard', () {
      final o = PayoutOnboarding.fromJson(const {
        'onboarding_url': 'https://connect.stripe.com/setup/x',
        'account_id': 'acct_123',
        'already_enabled': false,
      });
      expect(o.onboardingURL, 'https://connect.stripe.com/setup/x');
      expect(o.alreadyEnabled, isFalse);
    });

    test('already-enabled comes back with NO link — nothing left to do', () {
      final o = PayoutOnboarding.fromJson(const {
        'onboarding_url': '',
        'account_id': 'acct_123',
        'already_enabled': true,
      });
      expect(o.alreadyEnabled, isTrue);
      expect(o.onboardingURL, isNull,
          reason: 'an empty url must not be opened as a blank browser tab');
    });
  });
}
