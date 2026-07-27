import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'onboarding_state.dart';

/// THE BRAIN of the onboarding riblet (DOCS/05) — and it is a small brain, on
/// purpose.
///
/// 🔴 **THIS INTERACTOR MAKES NO REPOSITORY CALLS AT ALL.** Not one. That is not
/// an omission to be filled in later; it is the honest consequence of what the
/// backend actually offers:
///
/// - **personal** — there is no driver profile read or write (#39). The
///   Supabase session's own metadata is the only identity store, and the view
///   reads it directly off `AuthService`. Nothing to fetch, nothing to save.
/// - **licence** — a licence is a DOCUMENT (`dvla_license`), not a number. The
///   presigned upload flow already handles it, and it lives at `/documents`.
/// - **vehicle** — seam #82. Nothing accepts a plate, a model, an insurer or an
///   expiry. `vehicle_step.dart` fires zero calls and a recording fake proves
///   it.
/// - **attachments** — the documents surface owns its own state and its own
///   endpoint. The wizard links to it; it does not re-implement it.
/// - **complete** — eligibility is the SERVER'S call (`POST /drivers/me/online`
///   is compliance-gated). The wizard has no business deciding it, so it does
///   not compute it.
///
/// What is left is a cursor: `next` / `back` / `goTo`. If somebody later adds a
/// repository call here, the first question to ask is which endpoint it hits —
/// because on the day this was written, four of the five steps had none.
///
/// No Flutter widget imports, no BuildContext, no navigation (riblet rule).
class OnboardingInteractor extends Notifier<OnboardingState> {
  @override
  OnboardingState build() => const OnboardingState();

  /// Advance one step. Terminal at [OnboardingStep.complete].
  void next() {
    const order = OnboardingStep.values;
    final index = order.indexOf(state.step);
    if (index >= order.length - 1) return;
    state = state.copyWith(step: order[index + 1]);
  }

  /// Retreat one step. Terminal at [OnboardingStep.personal].
  void back() {
    const order = OnboardingStep.values;
    final index = order.indexOf(state.step);
    if (index <= 0) return;
    state = state.copyWith(step: order[index - 1]);
  }

  /// Jump directly to [step] — used by the step rail.
  void goTo(OnboardingStep step) => state = state.copyWith(step: step);
}
