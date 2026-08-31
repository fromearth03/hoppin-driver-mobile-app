import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/result.dart';
import 'package:hoppin_driver/features/profile/data/models/driver_profile.dart';
import 'package:hoppin_driver/features/profile/data/profile_repository.dart';
import 'package:hoppin_driver/shared/nav/app_shell.dart';
import 'package:mocktail/mocktail.dart';

class _MockProfileRepo extends Mock implements ProfileRepository {}

/// Goldens for the app shell: the floating tab pill and the side drawer,
/// held against `Side Nav Bar@2x.png` and the tab bar in
/// `Ride Request Off@2x.png`.
///
/// Run with `flutter test --update-goldens test/visual/nav_golden_test.dart`.
void main() {
  ProfileRepository stubProfile() {
    final repo = _MockProfileRepo();
    when(repo.me).thenAnswer((_) async => const Ok(DriverProfile(
          id: 'd1',
          fullName: 'Taimoor',
          rating: 4.31,
          ratingCount: 150,
        )));
    return repo;
  }

  Future<void> pump(
    WidgetTester tester, {
    int currentIndex = 0,
    ProfileRepository? repo,
  }) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        profileRepositoryProvider.overrideWithValue(repo ?? stubProfile()),
      ],
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true, fontFamily: 'Roboto'),
        home: AppShell(
          currentIndex: currentIndex,
          child: const ColoredBox(color: Color(0xFFF5F5F7), child: SizedBox.expand()),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('bottom tab pill', (tester) async {
    await pump(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/nav_tab_bar.png'),
    );
  });

  testWidgets('bottom tab pill — stats selected', (tester) async {
    await pump(tester, currentIndex: 3);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/nav_tab_bar_stats.png'),
    );
  });

  testWidgets('side drawer', (tester) async {
    await pump(tester);
    AppShell.scaffoldKey.currentState!.openDrawer();
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/nav_side_drawer.png'),
    );
  });

  testWidgets('side drawer — driver with no rating yet', (tester) async {
    final repo = _MockProfileRepo();
    when(repo.me).thenAnswer((_) async => const Ok(DriverProfile(
          id: 'd2',
          fullName: 'Aisha Bennett',
        )));
    await pump(tester, repo: repo);
    AppShell.scaffoldKey.currentState!.openDrawer();
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/nav_side_drawer_unrated.png'),
    );
  });
}
