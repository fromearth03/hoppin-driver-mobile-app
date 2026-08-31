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
        home: AppShell(currentIndex: 0, child: Text('body')),
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

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    final labels = tester
        .widgetList<Text>(find.descendant(
          of: find.byWidget(scaffold.bottomNavigationBar!),
          matching: find.byType(Text),
        ))
        .map((t) => t.data)
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

  testWidgets('drawer lists every account destination', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await openDrawer(tester);

    // The list scrolls at the default test viewport, so the destinations are
    // asserted on the widget tree rather than only on what is painted.
    for (final label in [
      'Personal Information',
      'Trips',
      'Statement',
      'Payouts',
      'Notifications',
      'Help & Support',
      'Settings',
      'Delete account',
      'Logout',
    ]) {
      expect(find.text(label, skipOffstage: false), findsOneWidget,
          reason: 'missing $label');
    }
  });

  testWidgets('drawer omits Payment Methods — those routes are rider-only',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await openDrawer(tester);

    expect(find.text('Payment Methods'), findsNothing);
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

  testWidgets('logout row calls the shell callback', (tester) async {
    var loggedOut = false;
    await tester.pumpWidget(ProviderScope(
      overrides: [profileRepositoryProvider.overrideWithValue(_repo())],
      child: MaterialApp(
        home: AppShell(
          currentIndex: 0,
          onLogout: () => loggedOut = true,
          child: const Text('body'),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await openDrawer(tester);

    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();

    expect(loggedOut, isTrue);
  });
}
