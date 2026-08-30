import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/result.dart';
import 'package:hoppin_driver/features/profile/data/models/driver_preferences.dart';
import 'package:hoppin_driver/features/profile/data/preferences_repository.dart';
import 'package:hoppin_driver/features/profile/ui/settings_screen.dart';
import 'package:mocktail/mocktail.dart';

class MockPrefsRepo extends Mock implements PreferencesRepository {}

Widget wrap(MockPrefsRepo repo) => ProviderScope(
      overrides: [preferencesRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: SettingsScreen()),
    );

void main() {
  setUpAll(() => registerFallbackValue(const DriverPreferences()));

  late MockPrefsRepo repo;

  setUp(() {
    repo = MockPrefsRepo();
    when(() => repo.load())
        .thenAnswer((_) async => const Ok(DriverPreferences()));
    when(() => repo.save(any())).thenAnswer((_) async => const Ok(null));
  });

  testWidgets('shows the settings a driver can change', (tester) async {
    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Ride request sound'), findsOneWidget);
    expect(find.text('Keep screen awake'), findsOneWidget);
    expect(find.text('Distance units'), findsOneWidget);
  });

  testWidgets('has no Language row', (tester) async {
    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    // Single locale — a row that does nothing is worse than no row.
    expect(find.text('Language'), findsNothing);
  });

  testWidgets('persists a toggle immediately', (tester) async {
    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    verify(() => repo.save(any())).called(1);
  });
}
