import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/result.dart';
import 'package:hoppin_driver/features/onboarding/data/models/onboarding_status.dart';
import 'package:hoppin_driver/features/onboarding/data/onboarding_repository.dart';
import 'package:hoppin_driver/features/onboarding/logic/onboarding_controller.dart';
import 'package:hoppin_driver/features/onboarding/ui/credentials_screen.dart';
import 'package:hoppin_driver/features/onboarding/ui/license_screen.dart';
import 'package:hoppin_driver/features/onboarding/ui/onboarding_screen.dart';
import 'package:hoppin_driver/features/onboarding/ui/sign_up_screen.dart';
import 'package:hoppin_driver/features/onboarding/ui/vehicle_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockOnboardingRepo extends Mock implements OnboardingRepository {}

/// Renders each self-registration wizard step at the Figma artboard size and
/// writes it to `test/visual/goldens/`, so the build can be held against the
/// design by eye rather than by assertion.
///
/// Run with
/// `flutter test --update-goldens test/visual/onboarding_golden_test.dart`.
void main() {
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

  _MockOnboardingRepo emptyRepo() {
    final repo = _MockOnboardingRepo();
    when(() => repo.credentials()).thenAnswer((_) async => const Ok([]));
    return repo;
  }

  testWidgets('step 1 — personal information', (t) async {
    await capture(t, const SignUpScreen(), 'onboarding_step1_personal');
  });

  testWidgets('step 2 — licences, empty', (t) async {
    final repo = emptyRepo();
    await capture(
      t,
      const CredentialsScreen(),
      'onboarding_step2_credentials',
      overrides: [onboardingRepositoryProvider.overrideWithValue(repo)],
    );
  });

  testWidgets('step 2 — licences, with saved credentials', (t) async {
    final repo = _MockOnboardingRepo();
    when(() => repo.credentials()).thenAnswer((_) async => Ok([
          {
            'type': 'wolverhampton_taxi_badge',
            'number': 'ABC1234657CC',
            'share_code': '',
            'is_temporary': false,
            'expires_at': '2026-05-12',
          },
          {
            'type': 'dbs_check',
            'number': 'DBS9981245XX',
            'share_code': '',
            'is_temporary': false,
            'expires_at': '2027-01-30',
          },
        ]));
    await capture(
      t,
      const CredentialsScreen(),
      'onboarding_step2_credentials_filled',
      // The design's filled state is one long scroll: two saved cards above
      // the form. A 932pt viewport would golden only its first third.
      size: const Size(430, 1900),
      overrides: [onboardingRepositoryProvider.overrideWithValue(repo)],
    );
  });

  testWidgets('step 2 — driving licence', (t) async {
    await capture(t, const LicenseScreen(), 'onboarding_step2_licence');
  });

  testWidgets('step 3 — vehicle registration', (t) async {
    await capture(
      t,
      const VehicleScreen(),
      'onboarding_step3_vehicle',
      // Taller than the mock: the mock shows three boxes, the service needs
      // seven fields plus the two compliance dates.
      size: const Size(430, 1700),
    );
  });

  testWidgets('step 4 — approval gate', (t) async {
    final repo = _MockOnboardingRepo();
    when(() => repo.status()).thenAnswer((_) async => Ok(const DriverOnboarding(
          status: OnboardingStatus.pendingApproval,
          steps: OnboardingSteps(
              profile: true, license: true, vehicle: true, credentialsCount: 2),
          message: 'Your application is with our team. '
              'We will let you know as soon as it is reviewed.',
        )));
    await capture(
      t,
      const OnboardingScreen(),
      'onboarding_step4_review',
      size: const Size(430, 1100),
      overrides: [
        onboardingRepositoryProvider.overrideWithValue(repo),
        onboardingPollIntervalProvider.overrideWithValue(const Duration(days: 1)),
      ],
    );
  });
}
