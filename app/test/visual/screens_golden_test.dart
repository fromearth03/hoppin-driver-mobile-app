import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/money.dart';
import 'package:hoppin_driver/core/result.dart';
import 'package:hoppin_driver/features/auth/ui/forgot_password_screen.dart';
import 'package:hoppin_driver/features/auth/ui/reset_password_screen.dart';
import 'package:hoppin_driver/features/auth/ui/sign_in_screen.dart';
import 'package:hoppin_driver/features/earnings/data/earnings_repository.dart';
import 'package:hoppin_driver/features/earnings/data/models/ride_earnings.dart';
import 'package:hoppin_driver/features/earnings/data/models/wallet.dart';
import 'package:hoppin_driver/features/earnings/ui/earnings_screen.dart';
import 'package:hoppin_driver/features/trips/data/models/driver_trip.dart';
import 'package:hoppin_driver/features/trips/data/trips_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockEarningsRepo extends Mock implements EarningsRepository {}

class _MockTripsRepo extends Mock implements TripsRepository {}

/// Renders each redesigned screen at the Figma artboard size and writes it to
/// `test/visual/goldens/`, so the build can be held against the design by eye
/// rather than by assertion.
///
/// Run with `flutter test --update-goldens test/visual` to refresh.
void main() {
  setUpAll(() => registerFallbackValue(TripFilter.all));

  Future<void> capture(
    WidgetTester tester,
    Widget child,
    String name, {
    List<Override> overrides = const [],
    Size size = const Size(430, 932),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true, fontFamily: 'Roboto'),
        home: child,
      ),
    ));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  testWidgets('sign in', (t) => capture(t, const SignInScreen(), 'sign_in'));
  testWidgets('forgot password',
      (t) => capture(t, const ForgotPasswordScreen(), 'forgot_password'));
  testWidgets('reset password',
      (t) => capture(t, const ResetPasswordScreen(), 'reset_password'));

  testWidgets('earnings', (t) async {
    final earnings = _MockEarningsRepo();
    final trips = _MockTripsRepo();

    EarningsSummary summary(int net, DateTime from, DateTime to, int count) =>
        EarningsSummary(
          net: Pence(net),
          gross: Pence((net * 1.42).round()),
          commission: Pence((net * 0.21).round()),
          penalties: const Pence(200),
          tripCount: count,
          avgNetPerTrip: Pence(count == 0 ? 0 : net ~/ count),
          from: from,
          to: to,
        );

    when(() => earnings.summary('today')).thenAnswer((_) async => Ok(summary(
        18060, DateTime(2026, 8, 19), DateTime(2026, 8, 20), 9)));
    when(() => earnings.summary('week')).thenAnswer((_) async => Ok(summary(
        44260, DateTime(2026, 8, 17), DateTime(2026, 8, 24), 23)));
    when(() => earnings.summary('month')).thenAnswer((_) async => Ok(summary(
        128040, DateTime(2026, 8, 1), DateTime(2026, 9, 1), 64)));
    when(() => earnings.summary('all')).thenAnswer((_) async => Ok(summary(
        981250, DateTime(2025, 3, 4), DateTime(2026, 8, 20), 512)));
    when(() => earnings.wallet()).thenAnswer((_) async => Ok(Wallet(
          availableBalance: const Pence(24560),
          pendingBalance: const Pence(18060),
          recentPayouts: [
            Payout(
                id: '48270aa1-0000-0000-0000-000000000001',
                amount: const Pence(21050),
                status: 'paid',
                transferredAt: DateTime.utc(2026, 8, 1)),
            Payout(
                id: '48287bb2-0000-0000-0000-000000000002',
                amount: const Pence(21050),
                status: 'failed',
                transferredAt: DateTime.utc(2026, 8, 18),
                failureReason: 'Bank verification failed'),
          ],
        )));
    when(() => earnings.promotions()).thenAnswer((_) async => const Ok([]));

    DriverTrip trip(int hour) => DriverTrip(
          id: 't$hour',
          status: 'completed',
          pickupLabel: 'City centre',
          dropoffLabel: 'Railway Station',
          earnings: const Pence(1000),
          penalty: const Pence(0),
          // A fixed clock time on today's date: the row prints h:mm, so a
          // literal now() bakes the capture minute into the golden and the
          // test can never pass again.
          completedAt: DateTime(DateTime.now().year, DateTime.now().month,
              DateTime.now().day, 7 + hour, 21),
        );

    when(() => trips.page(
          filter: any(named: 'filter'),
          from: any(named: 'from'),
          to: any(named: 'to'),
          limit: any(named: 'limit'),
        )).thenAnswer((_) async =>
        Ok(TripsPage(trips: [trip(1), trip(2), trip(3), trip(4)])));

    await capture(
      t,
      const EarningsScreen(),
      'earnings',
      // Tall artboard: the design is one long scroll, and a 932pt viewport
      // would golden only its first third.
      size: const Size(430, 2100),
      overrides: [
        earningsRepositoryProvider.overrideWithValue(earnings),
        tripsRepositoryProvider.overrideWithValue(trips),
      ],
    );
  });
}
