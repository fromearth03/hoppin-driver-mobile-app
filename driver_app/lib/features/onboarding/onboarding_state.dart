import 'package:flutter/foundation.dart';

/// The step the driver is on in the post-invite completion wizard.
///
/// 🔴 THIS IS NOT A SIGNUP FLOW. The driver is ALREADY provisioned and ALREADY
/// signed in when they reach step 1 — `DOCS/04` is explicit that drivers are
/// created by an admin and cannot self-register. The Figma's Registration1–4
/// frames are drawn as self-signup (Registration1 even asks for a password),
/// and they are RE-PURPOSED here (D3) as the first-login completion wizard.
enum OnboardingStep {
  /// Registration1 — who the driver is. Read-only over the session's own
  /// metadata: there is no driver profile endpoint to write to (#39).
  personal,

  /// Registration2 — licences. NOT a number field: the licence is captured as a
  /// DOCUMENT (`dvla_license`) through the presigned upload flow, which is the
  /// real mechanism and works today.
  licence,

  /// Registration3 — the vehicle. Seam #82: nothing accepts these fields.
  vehicle,

  /// Registration4 — the eight compliance documents. Fully bound.
  attachments,

  /// The Successful frame — with an honest claim, not a green tick over an
  /// eligibility decision only the server gets to make.
  complete,
}

/// The wizard's position, and nothing else.
///
/// 🔴 **THERE ARE NO DRAFT FIELDS IN THIS STATE, AND THAT IS THE DESIGN.** A
/// state class is a promise about what the app is holding on the driver's
/// behalf. Every field in it implies somewhere for that value to go.
///
/// - The **personal** step writes nothing: there is no `PATCH /me/profile`
///   (#39), so it RENDERS what the Supabase session already holds and does not
///   draw an editable box over a value it cannot save.
/// - The **licence** step collects nothing: the licence is a document, not a
///   number, and the document flow already exists.
/// - The **vehicle** step collects nothing: seam #82, nothing accepts it.
/// - The **attachments** step is the documents surface, which owns its own
///   state.
///
/// So the wizard holds a cursor. If a future change adds a draft field here, it
/// must be able to name the endpoint that draft is going to — and if it cannot,
/// the field is a lie in a data class.
@immutable
class OnboardingState {
  /// Creates the wizard state at [step].
  const OnboardingState({this.step = OnboardingStep.personal});

  /// Where the driver is.
  final OnboardingStep step;

  /// The four numbered steps of the Figma's indicator. `complete` is the
  /// success frame and sits outside the rail.
  static const List<OnboardingStep> numberedSteps = [
    OnboardingStep.personal,
    OnboardingStep.licence,
    OnboardingStep.vehicle,
    OnboardingStep.attachments,
  ];

  /// 1-based position on the step rail, or null on the success frame.
  int? get stepNumber {
    final index = numberedSteps.indexOf(step);
    return index == -1 ? null : index + 1;
  }

  /// Whether [back] has anywhere to go.
  bool get canGoBack => step != OnboardingStep.personal;

  /// copyWith — no nullable fields yet, so no `_unset` sentinel is needed. If
  /// one is ever added, follow the [DashboardState] shape.
  OnboardingState copyWith({OnboardingStep? step}) =>
      OnboardingState(step: step ?? this.step);
}
