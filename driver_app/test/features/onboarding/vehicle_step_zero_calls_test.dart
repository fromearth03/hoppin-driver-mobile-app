import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/onboarding/steps/vehicle_step.dart';
import 'package:hoppin_driver/features/onboarding/widgets/vehicle_registration_unavailable.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

/// 🔴 SEAM #82 — THE VEHICLE STEP IS A FORM THAT POSTS NOWHERE, AND WE ARE NOT
/// SHIPPING IT AS ONE.
///
/// The Figma's Registration3 ("Vehicle Registration") collects four things: the
/// registration plate, the make and model, the insurance provider, and the
/// insurance expiry date. **Nothing on the backend accepts a single one of
/// them.** There is no `POST /drivers/me/vehicle`. `Ride` carries a `vehicle_id`
/// the app never sets, and vehicle assignment happens ADMIN-SIDE. There is no
/// endpoint that would take these fields under any other name either.
///
/// A driver who fills that form in, taps Continue, and sees the step tick over
/// to Attachments now BELIEVES their vehicle is registered against their
/// account. It is not. Their work went into a `TextEditingController` and then
/// into the bin. They will discover this when dispatch never matches them — or,
/// far worse, when somebody asks about insurance and the platform has no record
/// they ever told us. **A form that silently discards a driver's work while
/// showing them a success state is not a shortcut; it is a lie with a
/// plausible-looking UI.**
///
/// So the step ships the STRUCTURE (so the wizard's shape survives the day the
/// endpoint lands and the fields drop straight in) and the RUNG (so the driver
/// is told the truth today). These tests are what hold that line:
///
/// - Test 4 proves the step cannot talk to the network even if somebody wires a
///   repository into it by accident — every repository is replaced by a fake
///   that FAILS THE TEST on any method call whatsoever.
/// - Test 5 proves the disclosure is CONSTRUCTED, unconditionally, with no state
///   setup at all. The seam is not sometimes-null. It is always-null.
/// - Test 6 proves the disclosure names the gap in the driver's terms and gives
///   them a way FORWARD. A disclosure that strands the driver is half-honest.
void main() {
  /// Pumps the vehicle step with EVERY repository replaced by a fake that fails
  /// the test the instant it is touched.
  Future<_CallRecorder> pumpVehicleStep(
    WidgetTester tester, {
    ThemeData? theme,
  }) async {
    final recorder = _CallRecorder();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // The three doors to the network. `apiClientProvider` is the one that
          // matters most: it is what EVERY repository is built from, so a fake
          // here catches a call made through a repository this test never
          // thought to override.
          apiClientProvider.overrideWithValue(_ExplodingApiClient(recorder)),
          driverRepositoryProvider
              .overrideWithValue(_ExplodingDriverRepository(recorder)),
          ridesRepositoryProvider
              .overrideWithValue(_ExplodingRidesRepository(recorder)),
        ],
        child: MaterialApp(
          theme: theme ?? HoppinTheme.driverDark(),
          home: Scaffold(
            body: VehicleStep(
              onBack: () {},
              onContinue: () {},
            ),
          ),
        ),
      ),
    );
    // Bounded pumps — never pumpAndSettle (project convention).
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    return recorder;
  }

  testWidgets('🔴 the vehicle step fires ZERO network calls (#82)',
      (tester) async {
    final recorder = await pumpVehicleStep(tester);

    // Mount alone must not call anything — no "prefill the vehicle we have on
    // file" read, because there is no endpoint that answers one.
    expect(
      recorder.calls,
      isEmpty,
      reason: 'the vehicle step made ${recorder.calls.length} network call(s) '
          'ON MOUNT: ${recorder.calls.join(', ')}',
    );

    // Now interact with EVERYTHING on the step. If a control exists that could
    // ever be wired to a repository, this is where it fires.
    for (final field in find.byType(TextField).evaluate().toList()) {
      await tester.enterText(find.byWidget(field.widget), 'WH12 ABC');
      await tester.pump(const Duration(milliseconds: 50));
    }
    for (final button in find.byType(HopButton).evaluate().toList()) {
      await tester.tap(find.byWidget(button.widget), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 50));
    }
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(
      recorder.calls,
      isEmpty,
      reason:
          'THE VEHICLE STEP MADE A NETWORK CALL: ${recorder.calls.join(', ')}\n\n'
          'There is nowhere for it to go. There is no POST /drivers/me/vehicle. '
          'Registration3 collects reg / model / insurance / expiry and NOTHING '
          'ON THE BACKEND ACCEPTS THEM (#82) — vehicle assignment is admin-side '
          'and `Ride.vehicle_id` is set by the operator, never by this app.\n\n'
          'If a call went out, one of two things is true, and both are worse '
          'than doing nothing: either it 404s and the driver is shown an error '
          'for a thing that was never their fault, or it silently succeeds '
          'against some endpoint that drops the fields — and the driver walks '
          'away believing their vehicle and their insurance are on file.',
    );
  });

  testWidgets(
      '🔴 the #82 rung is CONSTRUCTED unconditionally — no state setup at all',
      (tester) async {
    await pumpVehicleStep(tester);

    expect(
      find.byType(VehicleRegistrationUnavailable),
      findsOneWidget,
      reason:
          'The seam is not sometimes-null. It is ALWAYS-null: there is no '
          'endpoint, so there is no state of the world in which the vehicle '
          'step has real data to show. The rung must therefore be mounted '
          'unconditionally — not behind an `if (data == null)` that a future '
          'refactor can quietly make unreachable.\n\n'
          'A widget that is declared but never constructed is not a disclosure. '
          'It is dead code wearing a compliance badge.',
    );
  });

  testWidgets('🔴 the rung names the gap in the driver\'s terms', (tester) async {
    await pumpVehicleStep(tester);

    final rung = find.byType(VehicleRegistrationUnavailable);
    final text = tester
        .widgetList<Text>(find.descendant(of: rung, matching: find.byType(Text)))
        .map((t) => (t.data ?? '').toLowerCase())
        .join(' ');

    expect(
      text,
      isNotEmpty,
      reason: 'the rung must render designed copy, not a blank box',
    );

    // It must say WHO holds the vehicle — the operator, not the app. The driver
    // does not care that there is no endpoint; they care whether anybody knows
    // what car they drive.
    expect(
      RegExp('operator|our team|the hoppin team|we hold|on file|contact')
          .hasMatch(text),
      isTrue,
      reason:
          'The rung must tell the driver WHO holds their vehicle details — the '
          'operator does, and if theirs are wrong they should talk to us. It '
          'must NOT speak in our terms ("gap #82", "no endpoint"): the driver '
          'does not have a backlog, they have a car.\n\nGot: "$text"',
    );

    // And it must never imply the app is about to take the details.
    expect(
      RegExp(r'\bsaved\b|\bregistered successfully\b|\bwe.ve got (it|them)\b')
          .hasMatch(text),
      isFalse,
      reason:
          'the rung must not imply anything was saved — nothing was, and '
          'nothing can be.\n\nGot: "$text"',
    );
  });

  testWidgets('🔴 the rung offers a way FORWARD, not a dead end',
      (tester) async {
    var advanced = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(_ExplodingApiClient(_CallRecorder())),
        ],
        child: MaterialApp(
          theme: HoppinTheme.driverDark(),
          home: Scaffold(
            body: VehicleStep(
              onBack: () {},
              onContinue: () => advanced = true,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // The step's forward exit — Continue, to the attachments step, which is the
    // part of onboarding that DOES work. A disclosure that tells the driver
    // something is unavailable and then strands them on it is only half-honest.
    final continueButton = find.widgetWithText(HopButton, 'Continue');
    expect(
      continueButton,
      findsOneWidget,
      reason:
          'the vehicle step must let the driver move ON to the documents, which '
          'are fully bound and are the thing that actually gets them driving',
    );

    await tester.tap(continueButton);
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      advanced,
      isTrue,
      reason:
          'Continue must advance the wizard. It is a PURE LOCAL STATE '
          'TRANSITION — it saves nothing, because there is nothing to save it '
          'to, and it must never pretend otherwise.',
    );
  });

  testWidgets('the step renders in driverDark (primary)', (tester) async {
    await pumpVehicleStep(tester, theme: HoppinTheme.driverDark());
    expect(find.byType(VehicleRegistrationUnavailable), findsOneWidget);
  });

  testWidgets('the step renders in driverLight', (tester) async {
    // A separate test rather than a second pump into the same tester: pumping
    // twice reuses the element tree, so the second theme never actually takes.
    await pumpVehicleStep(tester, theme: HoppinTheme.driverLight());
    expect(find.byType(VehicleRegistrationUnavailable), findsOneWidget);
  });
}

/// Records every method anybody tried to call on a repository or the API client.
class _CallRecorder {
  final List<String> calls = <String>[];

  void record(Invocation invocation) {
    final name = invocation.memberName
        .toString()
        .replaceFirst('Symbol("', '')
        .replaceFirst('")', '');
    calls.add(name);
  }
}

/// 🔴 The API client every repository is built from. Any call through ANY
/// repository — including one this test never thought to override — lands here.
class _ExplodingApiClient implements ApiClient {
  _ExplodingApiClient(this._recorder);

  final _CallRecorder _recorder;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    _recorder.record(invocation);
    fail(
      'THE VEHICLE STEP MADE A NETWORK CALL: ${invocation.memberName}\n\n'
      'It has nowhere to go. Seam #82: the backend accepts no vehicle '
      'registration, model, insurance provider or insurance expiry from this '
      'app, under any name. Vehicle assignment is admin-side.',
    );
  }
}

class _ExplodingDriverRepository implements DriverRepository {
  _ExplodingDriverRepository(this._recorder);

  final _CallRecorder _recorder;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    _recorder.record(invocation);
    fail(
      'the vehicle step called DriverRepository.${invocation.memberName} — '
      'there is no vehicle endpoint on it, and there is no other endpoint that '
      'takes these fields (#82)',
    );
  }
}

class _ExplodingRidesRepository implements RidesRepository {
  _ExplodingRidesRepository(this._recorder);

  final _CallRecorder _recorder;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    _recorder.record(invocation);
    fail(
      'the vehicle step called RidesRepository.${invocation.memberName} — the '
      '`vehicle_id` on `Ride` is set by the OPERATOR, never by this app (#82)',
    );
  }
}
