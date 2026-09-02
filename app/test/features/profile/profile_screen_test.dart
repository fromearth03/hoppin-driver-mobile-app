import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/result.dart';
import 'package:hoppin_driver/features/profile/data/models/driver_profile.dart';
import 'package:hoppin_driver/features/profile/data/profile_repository.dart';
import 'package:hoppin_driver/features/profile/ui/profile_screen.dart';
import 'package:hoppin_driver/shared/widgets/app_buttons.dart';
import 'package:mocktail/mocktail.dart';

class MockProfileRepo extends Mock implements ProfileRepository {}

const _profile = DriverProfile(
  id: 'd1',
  fullName: 'Alex Morgan',
  email: 'alex@example.com',
  phoneNumber: '07700900123',
);

Widget wrap(MockProfileRepo repo) => ProviderScope(
      overrides: [profileRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: ProfileScreen()),
    );

AppButton saveButton(WidgetTester tester) =>
    tester.widget<AppButton>(find.byType(AppButton).last);

void main() {
  late MockProfileRepo repo;

  setUp(() {
    repo = MockProfileRepo();
    when(() => repo.me()).thenAnswer((_) async => const Ok(_profile));
    when(() => repo.update(
          phoneNumber: any(named: 'phoneNumber'),
          dateOfBirth: any(named: 'dateOfBirth'),
        )).thenAnswer((_) async => const Ok(_profile));
  });

  testWidgets('an untouched form has nothing to save', (tester) async {
    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    // A live Save with nothing edited only invited a round trip that
    // achieved nothing and showed a spinner for it.
    expect(saveButton(tester).onPressed, isNull);
    expect(find.text('No changes to save'), findsOneWidget);
  });

  testWidgets('editing the number arms the button', (tester) async {
    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '07700900999');
    await tester.pump();

    expect(saveButton(tester).onPressed, isNotNull);
    expect(find.text('Save changes'), findsOneWidget);
  });

  testWidgets('the confirmation survives the reload that follows a save',
      (tester) async {
    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '07700900999');
    await tester.pump();
    await tester.tap(find.byType(AppButton).last);
    await tester.pumpAndSettle();

    // Invalidating the profile rebuilds this screen; the message used to be
    // wiped by the fresh read before the driver could see it.
    expect(find.text('Saved'), findsOneWidget);
    verify(() => repo.update(phoneNumber: '07700900999')).called(1);
  });

  testWidgets('a saved number cannot be posted twice', (tester) async {
    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '07700900999');
    await tester.pump();
    await tester.tap(find.byType(AppButton).last);
    await tester.pumpAndSettle();

    expect(saveButton(tester).onPressed, isNull);
  });
}
