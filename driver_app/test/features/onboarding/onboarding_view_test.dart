import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/onboarding/onboarding_builder.dart';
import 'package:hoppin_driver/features/onboarding/onboarding_interactor.dart';
import 'package:hoppin_driver/features/onboarding/onboarding_state.dart';
import 'package:hoppin_driver/features/onboarding/steps/attachments_step.dart';
import 'package:hoppin_driver/features/onboarding/steps/licence_step.dart';
import 'package:hoppin_driver/features/onboarding/steps/onboarding_complete.dart';
import 'package:hoppin_driver/features/onboarding/steps/personal_step.dart';
import 'package:hoppin_driver/features/onboarding/steps/vehicle_step.dart';
import 'package:hoppin_driver/features/onboarding/widgets/vehicle_registration_unavailable.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:hoppin_ui/hoppin_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// View smoke layer (riblet testing contract, DOCS/05): state in → widgets out.
///
/// The assertions that carry weight here are the ones about what the wizard must
/// NOT say. The Figma's frames were drawn for a self-signup flow that the
/// contract forbids, and the two most expensive lies in the whole phase are both
/// a single string:
///
/// - a **password field** on step 1 (the driver already has an account — an
///   admin made it, and they set the password from the invite), and
/// - **"you can now go online"** on the success frame (only the server decides
///   that, and it decides it at the moment the driver taps GO).
void main() {
  Widget host(
    OnboardingState fixture, {
    ThemeData? theme,
    AuthService? auth,
  }) =>
      ProviderScope(
        overrides: [
          onboardingInteractorProvider
              .overrideWith(() => _StubInteractor(fixture)),
          authServiceProvider.overrideWithValue(auth ?? _FakeAuthService()),
          apiClientProvider.overrideWithValue(_ExplodingApiClient()),
        ],
        child: MaterialApp(
          theme: theme ?? HoppinTheme.driverDark(),
          home: const OnboardingRiblet(),
        ),
      );

  Future<void> pumpStep(
    WidgetTester tester,
    OnboardingStep step, {
    ThemeData? theme,
    AuthService? auth,
  }) async {
    await tester.pumpWidget(
      host(OnboardingState(step: step), theme: theme, auth: auth),
    );
    // Bounded pumps — never pumpAndSettle (project convention).
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('personal: renders the session\'s real details, read-only',
      (tester) async {
    await pumpStep(tester, OnboardingStep.personal);

    expect(find.byType(PersonalStep), findsOneWidget);
    expect(find.text('Personal Information'), findsOneWidget);
    expect(find.text('Ada Driver'), findsOneWidget);
    expect(find.text('ada@example.com'), findsOneWidget);
  });

  testWidgets(
      "🔴 personal: NO password field — the driver already HAS an account",
      (tester) async {
    await pumpStep(tester, OnboardingStep.personal);

    // The Figma's Registration1 draws First Name / Last Name / Email / Phone /
    // Password and a "Next" button. That is a SIGNUP FORM, and DOCS/04 forbids
    // driver self-registration outright. A driver reaching this screen was
    // provisioned by an admin, followed an emailed invite, SET THEIR PASSWORD
    // ALREADY, and is signed in right now.
    //
    // A password field here would either do nothing, or silently reset the
    // password of an account they just finished setting up.
    expect(
      find.byType(TextField),
      findsNothing,
      reason:
          'the personal step must collect NOTHING: there is no driver profile '
          'endpoint (#39), so an editable field here is a box that accepts a '
          "correction and bins it. Render what the session holds; don't ask.",
    );
    expect(find.byType(TextFormField), findsNothing);
    expect(find.textContaining('Password'), findsNothing);
    expect(find.textContaining('password'), findsNothing);
  });

  testWidgets('licence: routes to the document upload, collects no numbers',
      (tester) async {
    await pumpStep(tester, OnboardingStep.licence);

    expect(find.byType(LicenceStep), findsOneWidget);

    // Registration2 draws EIGHT licence numbers and EIGHT expiry dates. There is
    // no endpoint that takes a licence number — the licence is captured as a
    // DOCUMENT (dvla_license) through the presigned flow. Sixteen fields of
    // careful data entry, every character of which would be discarded.
    expect(
      find.byType(TextField),
      findsNothing,
      reason: 'no licence-number field: a licence is a document, not a number, '
          'and nothing on the backend accepts the number',
    );
    expect(find.byType(TextFormField), findsNothing);
    expect(find.widgetWithText(HopButton, 'Upload your licence'), findsOneWidget);
  });

  testWidgets('vehicle: the #82 rung, no inputs, and the structure survives',
      (tester) async {
    await pumpStep(tester, OnboardingStep.vehicle);

    expect(find.byType(VehicleStep), findsOneWidget);
    expect(find.byType(VehicleRegistrationUnavailable), findsOneWidget);

    // The STRUCTURE is preserved (the day #82 lands, the fields drop in) …
    expect(find.text('Vehicle reg'), findsOneWidget);
    expect(find.text('Vehicle model'), findsOneWidget);
    expect(find.text('Vehicle insurance'), findsOneWidget);
    expect(find.text('Insurance expiry'), findsOneWidget);

    // … as NON-INTERACTIVE placeholders. Not disabled fields: a greyed-out box
    // still says "type here, and one day this will be saved". It will not.
    expect(
      find.byType(TextField),
      findsNothing,
      reason: 'seam #82 — a form that posts nowhere never ships',
    );
    expect(find.byType(TextFormField), findsNothing);
  });

  testWidgets('attachments: hands off to /documents, does not re-implement it',
      (tester) async {
    await pumpStep(tester, OnboardingStep.attachments);

    expect(find.byType(AttachmentsStep), findsOneWidget);
    expect(find.widgetWithText(HopButton, 'Go to documents'), findsOneWidget);
  });

  testWidgets(
      '🔴 complete: claims NOTHING about eligibility or going online',
      (tester) async {
    await pumpStep(tester, OnboardingStep.complete);

    expect(find.byType(OnboardingComplete), findsOneWidget);

    // 🔴 THE MOST EXPENSIVE SENTENCE IN THE PHASE. Eligibility is the SERVER's
    // call: POST /drivers/me/online is compliance-gated and answers
    // 403 NOT_ELIGIBLE. The app does not see that verdict until the driver taps
    // GO. A driver who reads "you can now go online" here drives to a busy area,
    // taps GO, and is refused — having spent fuel and an hour of a shift on a
    // promise this screen had no standing to make.
    final body = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => (t.data ?? '').toLowerCase())
        .join(' ');

    for (final forbidden in const [
      "you're all set",
      'you are all set',
      'you can now go online',
      'go online',
      'ready to drive',
      'approved',
      'verified',
      'you can start driving',
    ]) {
      expect(
        body.contains(forbidden),
        isFalse,
        reason:
            'THE SUCCESS FRAME CLAIMED "$forbidden". It cannot know that. '
            'Eligibility is decided by the server at the moment the driver taps '
            'GO (403 NOT_ELIGIBLE), and an admin has not even reviewed the '
            'documents yet.\n\nSay what is TRUE: the documents are with the '
            "team, and we'll let them know.\n\nGot: \"$body\"",
      );
    }

    // What it MAY say — and does.
    expect(find.textContaining('with our team'), findsOneWidget);
    expect(find.widgetWithText(HopButton, 'Go to dashboard'), findsOneWidget);
  });

  testWidgets('the step rail numbers the four steps', (tester) async {
    await pumpStep(tester, OnboardingStep.vehicle);

    // The four numbers of the Figma's rail.
    for (final number in const ['1', '2', '3', '4']) {
      expect(find.text(number), findsOneWidget);
    }
    // And their labels. "Vehicle" appears TWICE on this step — once as the page
    // title and once as the rail label — which is correct and is why this asks
    // findsWidgets rather than findsOneWidget for it.
    expect(find.text('Personal'), findsOneWidget);
    expect(find.text('Licence'), findsOneWidget);
    expect(find.text('Vehicle'), findsWidgets);
    expect(find.text('Attachments'), findsOneWidget);
  });

  testWidgets('the success frame sits OUTSIDE the numbered rail',
      (tester) async {
    // Its own test, with its own fresh tree. Pumping a second widget into an
    // already-pumped tester reuses the element tree AND its provider state, so
    // the stubbed step override never takes — which made this assertion pass a
    // stale `vehicle` render and report a rail that was not there.
    await pumpStep(tester, OnboardingStep.complete);

    expect(find.text('Attachments'), findsNothing);
    expect(find.text('1'), findsNothing);
    expect(find.text('4'), findsNothing);
  });

  testWidgets('driverDark renders the wizard (PRIMARY — SF-02)',
      (tester) async {
    await pumpStep(tester, OnboardingStep.vehicle,
        theme: HoppinTheme.driverDark());
    expect(find.byType(VehicleRegistrationUnavailable), findsOneWidget);
    expect(find.byType(VehicleStep), findsOneWidget);
  });

  testWidgets('driverLight renders the wizard too — both themes ship',
      (tester) async {
    // A separate test, not a second pump: see the note on the success-frame
    // test above.
    await pumpStep(tester, OnboardingStep.vehicle,
        theme: HoppinTheme.driverLight());
    expect(find.byType(VehicleRegistrationUnavailable), findsOneWidget);
    expect(find.byType(VehicleStep), findsOneWidget);
  });
}

/// Serves the fixture state, so the view is tested as state-in → widgets-out.
class _StubInteractor extends OnboardingInteractor {
  _StubInteractor(this._fixture);

  final OnboardingState _fixture;

  @override
  OnboardingState build() => _fixture;
}

/// A provisioned, signed-in driver — the only kind there is.
class _FakeAuthService implements AuthService {
  @override
  String? get fullName => 'Ada Driver';

  @override
  String? get email => 'ada@example.com';

  @override
  String? get phone => null;

  @override
  bool get isSignedIn => true;

  @override
  Stream<AuthState> get onAuthStateChange => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
        'the onboarding view reached for AuthService.${invocation.memberName} — '
        'it may read only the session identity the app actually holds (#39)',
      );
}

/// The wizard has no endpoint behind it. Any call fails the test.
class _ExplodingApiClient implements ApiClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => fail(
        'the onboarding view called ApiClient.${invocation.memberName} — the '
        'wizard talks to nothing',
      );
}
