import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/result.dart';
import 'package:hoppin_driver/features/onboarding/data/models/onboarding_status.dart';
import 'package:hoppin_driver/features/onboarding/data/onboarding_repository.dart';
import 'package:hoppin_driver/features/onboarding/logic/onboarding_controller.dart';
import 'package:hoppin_driver/features/onboarding/ui/onboarding_screen.dart';
import 'package:mocktail/mocktail.dart';

class MockRepo extends Mock implements OnboardingRepository {}

DriverOnboarding pending({
  List<OnboardingDocument> documents = const [],
  OnboardingSteps steps = const OnboardingSteps(),
}) =>
    DriverOnboarding(
      status: OnboardingStatus.pendingApproval,
      steps: steps,
      documents: documents,
      message: 'Your application is under review.',
    );

void main() {
  late MockRepo repo;

  setUp(() => repo = MockRepo());

  Widget wrap() => ProviderScope(
        overrides: [
          onboardingRepositoryProvider.overrideWithValue(repo),
          // Never let the poll fire during a widget test.
          onboardingPollIntervalProvider
              .overrideWithValue(const Duration(days: 1)),
        ],
        child: const MaterialApp(home: OnboardingScreen()),
      );

  testWidgets('shows the server message rather than our own wording',
      (tester) async {
    when(() => repo.status()).thenAnswer((_) async => Ok(pending()));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Under review'), findsOneWidget);
    // Paraphrasing would have the app and support telling different stories.
    expect(find.text('Your application is under review.'), findsOneWidget);
  });

  testWidgets('a rejected document is quoted verbatim', (tester) async {
    when(() => repo.status()).thenAnswer((_) async => Ok(pending(documents: const [
          OnboardingDocument(
            type: 'mot_certificate',
            status: 'rejected',
            rejectionReason: 'The expiry date is not legible.',
          ),
        ])));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // The driver cannot fix what they are not told.
    expect(find.textContaining('The expiry date is not legible.'),
        findsOneWidget);
    expect(find.text('Needs your attention'), findsOneWidget);
  });

  testWidgets('a rejection with no reason still names the document',
      (tester) async {
    when(() => repo.status()).thenAnswer((_) async => Ok(pending(documents: const [
          OnboardingDocument(type: 'insurance_policy', status: 'rejected'),
        ])));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.textContaining('Insurance policy'), findsOneWidget);
  });

  testWidgets('counts the steps the driver has finished', (tester) async {
    when(() => repo.status()).thenAnswer((_) async => Ok(pending(
        steps: const OnboardingSteps(
            profile: true, license: true, credentialsCount: 1))));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('3 of 7 steps done'), findsOneWidget);
  });

  testWidgets('an approved driver is told so', (tester) async {
    when(() => repo.status()).thenAnswer((_) async => Ok(const DriverOnboarding(
          status: OnboardingStatus.active,
          canOperate: true,
          message: "You're approved. You can go online and accept rides.",
        )));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text("You're approved"), findsOneWidget);
  });

  testWidgets('a healthy application shows no attention banner',
      (tester) async {
    when(() => repo.status()).thenAnswer((_) async => Ok(pending()));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Needs your attention'), findsNothing);
  });
}
