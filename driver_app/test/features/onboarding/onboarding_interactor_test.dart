import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/onboarding/onboarding_builder.dart';
import 'package:hoppin_driver/features/onboarding/onboarding_state.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

/// The wizard's brain — a cursor, and deliberately nothing more.
///
/// The interesting assertion in this file is the LAST one: the interactor makes
/// no repository calls at all. Four of the wizard's five steps have no endpoint
/// behind them (personal → no profile write, #39; licence → captured as a
/// document, not a number; vehicle → seam #82; complete → eligibility is the
/// server's call), and the fifth hands off to the documents surface, which owns
/// its own. An interactor that started calling repositories would be inventing
/// destinations for data that has none.
void main() {
  ProviderContainer harness() {
    final container = ProviderContainer(
      overrides: [
        // Every door to the network, slammed. If the interactor reaches for one
        // while merely advancing a step, the test fails naming the method.
        apiClientProvider.overrideWithValue(_ExplodingApiClient()),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('starts on the personal step, with nowhere back', () {
    final container = harness();
    final state = container.read(onboardingInteractorProvider);

    expect(state.step, OnboardingStep.personal);
    expect(state.stepNumber, 1);
    expect(state.canGoBack, isFalse);
  });

  test('next() walks personal → licence → vehicle → attachments → complete', () {
    final container = harness();
    final interactor =
        container.read(onboardingInteractorProvider.notifier);

    const expected = [
      OnboardingStep.licence,
      OnboardingStep.vehicle,
      OnboardingStep.attachments,
      OnboardingStep.complete,
    ];

    for (final step in expected) {
      interactor.next();
      expect(container.read(onboardingInteractorProvider).step, step);
    }
  });

  test('next() is terminal at complete — it never falls off the end', () {
    final container = harness();
    final interactor =
        container.read(onboardingInteractorProvider.notifier);

    interactor.goTo(OnboardingStep.complete);
    interactor.next();
    interactor.next();

    expect(
      container.read(onboardingInteractorProvider).step,
      OnboardingStep.complete,
    );
  });

  test('back() retreats, and is terminal at personal', () {
    final container = harness();
    final interactor =
        container.read(onboardingInteractorProvider.notifier);

    interactor.goTo(OnboardingStep.vehicle);
    interactor.back();
    expect(
      container.read(onboardingInteractorProvider).step,
      OnboardingStep.licence,
    );

    interactor
      ..back()
      ..back()
      ..back();
    expect(
      container.read(onboardingInteractorProvider).step,
      OnboardingStep.personal,
    );
  });

  test('the step rail numbers the four steps and excludes the success frame',
      () {
    final container = harness();
    final interactor =
        container.read(onboardingInteractorProvider.notifier);

    const numbers = {
      OnboardingStep.personal: 1,
      OnboardingStep.licence: 2,
      OnboardingStep.vehicle: 3,
      OnboardingStep.attachments: 4,
    };
    numbers.forEach((step, number) {
      interactor.goTo(step);
      expect(container.read(onboardingInteractorProvider).stepNumber, number);
    });

    interactor.goTo(OnboardingStep.complete);
    expect(
      container.read(onboardingInteractorProvider).stepNumber,
      isNull,
      reason: 'the Successful frame sits outside the numbered rail',
    );
  });

  test('🔴 walking the whole wizard makes ZERO repository calls', () {
    // Not a performance assertion — a truthfulness one. There is no endpoint
    // behind four of the five steps. An interactor that fetched or saved
    // anything here would be talking to something that does not exist, or
    // (worse) quietly discarding a driver's data into a call that drops it.
    final container = harness();
    final interactor =
        container.read(onboardingInteractorProvider.notifier);

    for (var i = 0; i < OnboardingStep.values.length; i++) {
      interactor.next();
    }
    for (var i = 0; i < OnboardingStep.values.length; i++) {
      interactor.back();
    }

    // _ExplodingApiClient fails the test on any call; reaching here is the pass.
    expect(
      container.read(onboardingInteractorProvider).step,
      OnboardingStep.personal,
    );
  });
}

/// Fails the test on any call. The interactor must never reach the network.
class _ExplodingApiClient implements ApiClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => fail(
        'the onboarding interactor called ApiClient.${invocation.memberName} — '
        'the wizard has no endpoint behind it. Personal has no profile write '
        '(#39), licence is a document not a number, vehicle is seam #82, and '
        'eligibility on the complete step is the SERVER\'s call.',
      );
}
