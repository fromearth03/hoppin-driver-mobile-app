import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_demo/hoppin_demo.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

/// DEMO-03 acceptance: the seed world must read Wolverhampton-real and be
/// fully deterministic — one fixed virtual morning, zero wall-clock reads.
void main() {
  group('anchor', () {
    test('is a fixed virtual Tuesday at 09:30', () {
      expect(DemoSeed.anchor.weekday, DateTime.tuesday);
      expect(DemoSeed.anchor.hour, 9);
      expect(DemoSeed.anchor.minute, 30);
    });

    test('is in the past relative to a hard-coded sanity date', () {
      // Deliberately a fixed date, NOT the wall clock — determinism guard.
      final later = DateTime(2026, 7, 6);
      expect(DemoSeed.anchor.isBefore(later), isTrue);
    });
  });

  group('plates', () {
    // Current GB format, Birmingham DVLA memory tag (B covers Wolverhampton),
    // no I or Q in the random triple.
    final plateFormat = RegExp(r'^B[A-Z]\d{2} [A-HJ-PR-Z]{3}$');

    test('every seeded plate is a valid B-prefix West Midlands plate', () {
      final plates = <String>[
        DemoPersonas.driverVehicle.plate,
        for (final member in DemoPersonas.historyCast) member.vehicle.plate,
      ];
      expect(plates, isNotEmpty);
      for (final plate in plates) {
        expect(
          plateFormat.hasMatch(plate),
          isTrue,
          reason: 'not a valid West Midlands plate: $plate',
        );
      }
    });
  });

  group('places', () {
    test('landmark coords match the rider app wolverhamptonPresets exactly', () {
      final coords = [
        for (final place in DemoPlaces.presets)
          (place.label, place.lat, place.lng),
      ];
      expect(coords, [
        ('City Centre', 52.5870, -2.1288),
        ('Wolverhampton Rail Station', 52.5877, -2.1200),
        ('University of Wolverhampton', 52.5896, -2.1276),
        ('New Cross Hospital', 52.6046, -2.0930),
        ('Molineux Stadium', 52.5903, -2.1306),
        ('Bentley Bridge Retail Park', 52.6006, -2.0868),
      ]);
    });

    test('two saved locations are seeded: Home and Work', () {
      expect(DemoPlaces.savedLocations, hasLength(2));
      expect(
        DemoPlaces.savedLocations.map((l) => l.label),
        containsAll(['Home', 'Work']),
      );
    });
  });

  group('fares', () {
    Quote scriptedQuote() => quoteBetween(
      pickupLat: DemoPlaces.scriptedPickup.lat,
      pickupLng: DemoPlaces.scriptedPickup.lng,
      dropoffLat: DemoPlaces.scriptedDropoff.lat,
      dropoffLng: DemoPlaces.scriptedDropoff.lng,
    );

    test('scripted route (Rail Station to New Cross Hospital) is in GBP 5-10', () {
      final quote = scriptedQuote();
      expect(quote.total, greaterThanOrEqualTo(5.00));
      expect(quote.total, lessThanOrEqualTo(10.00));
    });

    test('quote is internally consistent', () {
      final quote = scriptedQuote();
      expect(
        quote.subtotal,
        closeTo(quote.base + quote.distance + quote.time + quote.serviceFee, 0.01),
      );
      expect(quote.total, closeTo(math.max(quote.gross, quote.minimum), 0.001));
    });

    test('quoteBetween is pure: identical inputs give identical values', () {
      expect(scriptedQuote(), equals(scriptedQuote()));
    });
  });

  group('promo', () {
    test('the seeded code is HOPPIN20', () {
      expect(DemoSeed.promoCode, 'HOPPIN20');
    });

    test('takes 20 percent off a 7.50 fare', () {
      final result = promoResultFor(code: 'HOPPIN20', originalFare: 7.50);
      expect(result, isNotNull);
      expect(result!.discountType, 'percentage');
      expect(result.originalFare, closeTo(7.50, 0.001));
      expect(result.discountAmount, closeTo(1.50, 0.001));
      expect(result.newFare, closeTo(6.00, 0.001));
    });

    test('unknown codes yield no result', () {
      expect(promoResultFor(code: 'NOPE50', originalFare: 7.50), isNull);
    });
  });

  group('driver morning earnings', () {
    test('seeded morning totals 4375 pence over 5 trips, 3h10m online', () {
      final earnings = DemoHistory.morningEarnings;
      expect(earnings.totalPence, 4375);
      expect(earnings.tripCount, 5);
      expect(earnings.onlineDuration, const Duration(hours: 3, minutes: 10));
    });

    test('per-trip payouts sum to the seeded total', () {
      final earnings = DemoHistory.morningEarnings;
      expect(earnings.payouts, hasLength(earnings.tripCount));
      final sum = earnings.payouts.fold<int>(0, (acc, p) => acc + p.amountPence);
      expect(sum, earnings.totalPence);
    });
  });

  group('trip history', () {
    final uuidFormat = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    );

    test('6-8 rides, all completed, newest first by createdAt', () {
      final rides = DemoHistory.rides;
      expect(rides.length, inInclusiveRange(6, 8));
      for (final ride in rides) {
        expect(ride.status, RideStatus.completed);
      }
      for (var i = 0; i < rides.length - 1; i++) {
        expect(
          rides[i].createdAt!.isAfter(rides[i + 1].createdAt!),
          isTrue,
          reason: 'history must be strictly newest-first',
        );
      }
    });

    test('every timestamp is strictly before the anchor and within 21 days', () {
      for (final trip in DemoHistory.trips) {
        final stamps = <DateTime>[
          trip.ride.createdAt!,
          trip.ride.updatedAt!,
          trip.receipt.pickupTime!,
          trip.receipt.dropoffTime!,
        ];
        for (final stamp in stamps) {
          expect(
            stamp.isBefore(DemoSeed.anchor),
            isTrue,
            reason: '$stamp is not before the anchor',
          );
          expect(
            DemoSeed.anchor.difference(stamp),
            lessThanOrEqualTo(const Duration(days: 21)),
            reason: '$stamp is older than 21 days before the anchor',
          );
        }
      }
    });

    test('ride ids are fixed valid-hex uuids', () {
      for (final ride in DemoHistory.rides) {
        expect(
          uuidFormat.hasMatch(ride.id),
          isTrue,
          reason: 'not a valid hex uuid: ${ride.id}',
        );
      }
    });

    test('every ride has a matching pence-consistent receipt', () {
      for (final trip in DemoHistory.trips) {
        expect(trip.receipt.rideId, trip.ride.id);
        expect(
          trip.receipt.farePence + trip.receipt.waitingPence,
          trip.receipt.totalPence,
          reason: 'receipt for ${trip.ride.id} is not pence-consistent',
        );
      }
    });
  });

  group('wall-clock guard', () {
    test('no file under lib/ reads the wall clock', () {
      final dartFiles = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();
      expect(dartFiles, isNotEmpty);
      // Split so this literal can never match itself in a broader sweep.
      const forbidden = 'DateTime.now' '()';
      for (final file in dartFiles) {
        expect(
          file.readAsStringSync().contains(forbidden),
          isFalse,
          reason: '${file.path} reads the wall clock',
        );
      }
    });
  });
}
