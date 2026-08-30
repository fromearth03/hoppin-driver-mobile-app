import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_exception.dart';
import 'package:hoppin_driver/core/result.dart';
import 'package:hoppin_driver/features/onboarding/data/models/onboarding_status.dart';
import 'package:hoppin_driver/features/onboarding/data/onboarding_repository.dart';
import 'package:hoppin_driver/features/onboarding/logic/onboarding_controller.dart';
import 'package:mocktail/mocktail.dart';

class MockRepo extends Mock implements OnboardingRepository {}

DriverOnboarding pending() =>
    const DriverOnboarding(status: OnboardingStatus.pendingApproval);

DriverOnboarding approved() => const DriverOnboarding(
    status: OnboardingStatus.active, canOperate: true);

void main() {
  late MockRepo repo;

  setUp(() => repo = MockRepo());

  ProviderContainer container() {
    final c = ProviderContainer(overrides: [
      onboardingRepositoryProvider.overrideWithValue(repo),
      onboardingPollIntervalProvider
          .overrideWithValue(const Duration(milliseconds: 10)),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  test('polls while the application is still pending', () async {
    when(() => repo.status()).thenAnswer((_) async => Ok(pending()));

    final c = container();
    await c.read(onboardingControllerProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 60));

    // Approval happens in the admin panel with nothing pushed to the app, so
    // asking again is the only way the driver ever learns.
    verify(() => repo.status()).called(greaterThan(1));
  });

  test('stops polling once approved', () async {
    when(() => repo.status()).thenAnswer((_) async => Ok(approved()));

    final c = container();
    await c.read(onboardingControllerProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 60));

    verify(() => repo.status()).called(1);
  });

  test('stops polling when approval arrives mid-wait', () async {
    var calls = 0;
    when(() => repo.status()).thenAnswer((_) async {
      calls++;
      return Ok(calls >= 2 ? approved() : pending());
    });

    final c = container();
    await c.read(onboardingControllerProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    final settled = calls;
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(calls, settled);
    expect(c.read(onboardingControllerProvider).value!.onboarding!.isActive,
        isTrue);
  });

  test('a failed poll keeps the checklist already on screen', () async {
    var calls = 0;
    when(() => repo.status()).thenAnswer((_) async {
      calls++;
      if (calls == 1) return Ok(pending());
      return Err(ApiException('INTERNAL', 'network', 0));
    });

    final c = container();
    await c.read(onboardingControllerProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 40));

    final state = c.read(onboardingControllerProvider).value!;
    // Losing one poll is not news worth replacing the driver's progress with
    // an error screen.
    expect(state.onboarding, isNotNull);
    expect(state.error, isNotNull);
  });
}
