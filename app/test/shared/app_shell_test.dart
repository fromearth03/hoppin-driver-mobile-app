import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/result.dart';
import 'package:hoppin_driver/features/profile/data/models/driver_profile.dart';
import 'package:hoppin_driver/features/profile/data/profile_repository.dart';
import 'package:hoppin_driver/shared/nav/app_shell.dart';
import 'package:mocktail/mocktail.dart';

class _MockProfileRepo extends Mock implements ProfileRepository {}

ProfileRepository _repo({DriverProfile? profile}) {
  final repo = _MockProfileRepo();
  when(repo.me).thenAnswer((_) async => Ok(profile ??
      const DriverProfile(
        id: 'd1',
        fullName: 'Taimoor',
        rating: 4.31,
        ratingCount: 150,
      )));
  return repo;
}

Widget wrap({ProfileRepository? repo}) => ProviderScope(
      overrides: [profileRepositoryProvider.overrideWithValue(repo ?? _repo())],
      child: const MaterialApp(
        home: AppShell(currentPath: '/', currentIndex: 0, child: Text('body')),
      ),
    );

Future<void> openDrawer(WidgetTester tester) async {
  AppShell.scaffoldKey.currentState!.openDrawer();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows exactly the four locked tabs in order', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // The pill is icon-only; the names live on as tooltips, which is also
    // what assistive tech reads.
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    final labels = tester
        .widgetList<Tooltip>(find.descendant(
          of: find.byWidget(scaffold.bottomNavigationBar!),
          matching: find.byType(Tooltip),
        ))
        .map((t) => t.message)
        .toList();

    expect(labels, ['Home', 'Earnings', 'Docs', 'Stats']);
  });

  testWidgets('Trips is not a bottom tab — it lives in the drawer',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // Before the drawer opens, nothing in the shell offers Trips.
    expect(find.text('Trips'), findsNothing);

    await openDrawer(tester);
    expect(find.text('Trips'), findsOneWidget);
  });

  testWidgets('the drawer does not duplicate what Settings already holds',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await openDrawer(tester);

    // Both are reached from the Settings screen and its gear on Home; a
    // second door here only made the drawer longer.
    expect(find.text('Settings', skipOffstage: false), findsNothing);
    expect(
        find.text('Personal Information', skipOffstage: false), findsNothing);
    // Deleting an account is not a destination; it belongs where the driver
    // manages their account rather than one mis-tap from Trips.
    expect(find.text('Delete account', skipOffstage: false), findsNothing);
  });

  testWidgets('drawer lists every account destination', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await openDrawer(tester);

    // The list scrolls at the default test viewport, so the destinations are
    // asserted on the widget tree rather than only on what is painted.
    for (final label in [
      'Trips',
      'Statement',
      'Payment Methods',
      'Notifications',
      'Help & Support',
      'Logout',
    ]) {
      expect(find.text(label, skipOffstage: false), findsOneWidget,
          reason: 'missing $label');
    }
  });

  testWidgets('drawer offers the driver their own payment methods',
      (tester) async {
    // This used to assert the opposite: payment methods were a rider-only
    // idea, and the driver's equivalent was called Payouts. Drivers now
    // manage where they are paid from the same place, under the name they
    // would look for.
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await openDrawer(tester);

    expect(find.text('Payment Methods', skipOffstage: false), findsOneWidget);
  });

  testWidgets('drawer header shows the profile name and rating from the API',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await openDrawer(tester);

    expect(find.text('Taimoor'), findsOneWidget);
    expect(find.text('4.31 (150)'), findsOneWidget);
  });

  testWidgets('an unrated driver gets no stars rather than a score they '
      'did not earn', (tester) async {
    await tester.pumpWidget(wrap(
      repo: _repo(
          profile: const DriverProfile(id: 'd2', fullName: 'Aisha Bennett')),
    ));
    await tester.pumpAndSettle();
    await openDrawer(tester);

    expect(find.text('Aisha Bennett'), findsOneWidget);
    expect(find.byIcon(Icons.star), findsNothing);
    expect(find.byIcon(Icons.star_border), findsNothing);
  });

  testWidgets('logout row asks before signing anyone out', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [profileRepositoryProvider.overrideWithValue(_repo())],
      child: MaterialApp(
        home: AppShell(currentPath: '/', 
          currentIndex: 0,
          onLogout: () {},
          child: const Text('body'),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await openDrawer(tester);

    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();

    // One mis-tap must not end a shift: the confirm dialog stands between
    // the row and the sign-out.
    expect(find.text('Are you logging out?'), findsOneWidget);
  });

  testWidgets('the drawer groups its destinations', (tester) async {
    // Nine flat rows made the driver read every one to find the money.
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await openDrawer(tester);

    expect(find.text('YOUR WORK', skipOffstage: false), findsOneWidget);
    expect(find.text('YOUR MONEY', skipOffstage: false), findsOneWidget);
  });
}
