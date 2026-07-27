import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/auth/login_screen.dart';
import 'package:hoppin_driver/features/onboarding/onboarding_builder.dart';
import 'package:hoppin_driver/router.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:hoppin_ui/hoppin_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/code_lines.dart';

/// 🔴 THERE IS NO SUCH THING AS A DRIVER WHO SIGNED THEMSELVES UP.
///
/// `DOCS/04` (Driver operations, preamble) is unambiguous: *"Drivers are
/// provisioned by an admin… Drivers can't self-register."* An admin creates the
/// login and the platform emails a set-password invite. That is the ONLY way a
/// driver account comes into existence.
///
/// So the Figma's Registration1–4 frames — which are drawn as a self-signup
/// wizard, right down to the "Password" field on Registration1 — are re-purposed
/// (D3) as the POST-INVITE completion wizard: the driver is ALREADY provisioned
/// and ALREADY signed in when they reach step 1.
///
/// This file guards the two things that re-purposing must never quietly undo.
///
/// **Why a "Create account" button is not a cosmetic mistake.** A driver who taps
/// it has just been told by an operator to download this app. The button offers
/// them a door. Behind the door there is nothing: no admin has provisioned them,
/// so either the app refuses them (and they conclude the platform is broken), or
/// — far worse — a `supabase.auth.signUp()` call SUCCEEDS and CREATES A USER.
/// That user is an orphaned auth identity with no driver row behind it. It can
/// log in. It sees a dashboard. It is not a driver, it can never be dispatched,
/// and nothing in the app will ever tell it so.
///
/// Test 1 is expected to be GREEN on the day it lands — there is no signup
/// affordance in `apps/driver` today. That is not a weakness, it is the whole
/// point: this is a REGRESSION guard, and its value is that it goes red the day
/// somebody adds one.
void main() {
  group('no self-signup', () {
    /// Every `.dart` file under `apps/driver/lib`, with its path, so a failure
    /// names the offending file and line rather than merely asserting a count.
    late List<({String path, String text})> sources;

    setUpAll(() {
      sources = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .map((f) => (path: f.path, text: f.readAsStringSync()))
          .toList();
    });

    // 🔴 CODE ONLY — comments are blanked, and the DISTINCTION IS THE POINT.
    //
    // This codebase documents the no-self-signup rule at length, and it must:
    // `router.dart` says "never sign-up", `login_screen.dart` says
    // "deliberately has no sign-up", `personal_step.dart` says "there is no
    // 'create account'". A sweep that matched raw text would flag all three and
    // be RED ON A CORRECT CODEBASE — and a test that is red when nothing is
    // wrong gets deleted within the month, which would leave the app with no
    // guard at all.
    //
    // A comment saying "create account" ships no button. `Text('Create
    // account')` does. `supabase.auth.signUp()` does something far worse. Those
    // are what this looks for: the executable ones.
    //
    // codeLines() used to be defined inline right here. It now lives in
    // test/support/code_lines.dart — ONE copy, shared with the other source
    // guards, and SANITY-TESTED there (test/support/code_lines_test.dart). That
    // sanity suite is what keeps this file's sweep from going silently blind:
    // if the stripper ever regressed to returning '' for every line, every
    // assertion below would pass vacuously on an app full of signup buttons.

    test(
        '🔴 no self-signup affordance exists ANYWHERE in apps/driver/lib '
        '(regression guard)', () {
      // Each pattern is a promise the platform cannot keep, offered to somebody
      // who has just been told to download the app.
      //
      // `signUp(` is the load-bearing one: `AuthService.signUpRider` EXISTS in
      // hoppin_shared (the rider app is allowed to self-register), so the driver
      // app is one careless import away from calling it. The `\b` guard keeps
      // this honest — it matches `signUp(` and `signUpRider(` alike, and both
      // are forbidden HERE.
      final forbidden = <String, RegExp>{
        'signUp(': RegExp(r'\bsign_?up\w*\s*\(', caseSensitive: false),
        'Create account': RegExp('create account', caseSensitive: false),
        'Sign up': RegExp(r'\bsign[ -]up\b', caseSensitive: false),
        'Register now': RegExp('register now', caseSensitive: false),
        "Don't have an account":
            RegExp("do(n't|n’t| not) have an account", caseSensitive: false),
      };

      final hits = <String>[];
      for (final source in sources) {
        // CODE only. The prose that explains why signup is forbidden must not
        // be mistaken for signup — see codeLines().
        final lines = codeLines(source.text);
        for (var i = 0; i < lines.length; i++) {
          // This file's own guard list must not be searched for its own
          // patterns — but this file lives in test/, not lib/, so `sources`
          // cannot contain it. No self-exclusion hack is needed, and if one
          // ever seems needed, that means a lib/ file is describing signup.
          for (final entry in forbidden.entries) {
            if (entry.value.hasMatch(lines[i])) {
              hits.add(
                '  ${source.path}:${i + 1}  [${entry.key}]  '
                '${lines[i].trim()}',
              );
            }
          }
        }
      }

      expect(
        hits,
        isEmpty,
        reason:
            'A SELF-SIGNUP AFFORDANCE EXISTS IN THE DRIVER APP.\n\n'
            '${hits.join('\n')}\n\n'
            'DOCS/04 forbids driver self-registration: drivers are provisioned '
            'by an admin and set their password from an emailed invite. Any of '
            'these strings offers a door with nothing behind it.\n\n'
            'If it is a supabase signUp() CALL, it is worse than a dead button: '
            'it SUCCEEDS, and it creates an auth identity with no driver row '
            'behind it — an account that can log in, sees a dashboard, is not a '
            'driver, can never be dispatched, and is never told so.\n\n'
            'The wizard at /onboarding is the POST-INVITE completion flow. It '
            'does not create accounts. It never should.',
      );
    });

    testWidgets(
        '🔴 /onboarding is auth-gated — a signed-OUT visitor lands on the '
        'login screen', (tester) async {
      // Asked of the REAL driverRouterProvider, and PUMPED. This test builds NO
      // router of its own — see the doc comment in router_reachability_test.dart:
      // this project shipped seven dead routes behind a green suite precisely
      // because three test files hand-built the GoRoute they were asserting. A
      // test that builds its own router proves its own router works.
      //
      // And it pumps rather than inspecting `topRedirect` directly, because the
      // question that matters is not "does a function return a string" but
      // "does an unauthenticated visitor to /onboarding actually END UP on the
      // login screen". That is the runtime path, so that is what is driven.
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(_SignedOutAuthService()),
        ],
      );
      addTearDown(container.dispose);
      final router = container.read(driverRouterProvider);

      router.go('/onboarding');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: HoppinTheme.driverDark(),
            routerConfig: router,
          ),
        ),
      );
      // Bounded pumps — never pumpAndSettle (project convention).
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 350));
      }

      expect(
        find.byType(DriverLoginScreen),
        findsOneWidget,
        reason:
            'The wizard is reachable ONLY by a signed-in, admin-provisioned '
            'driver. The redirect in router.dart already enforces this for '
            'every route — adding ...onboardingRoutes inherits it for free. If '
            'this is red, either the route is missing from the real route '
            'table, or somebody has carved an exemption into the redirect.',
      );
      expect(
        find.byType(OnboardingRiblet),
        findsNothing,
        reason:
            'a signed-out visitor must never see one pixel of the completion '
            'wizard',
      );
    });

    test('🔴 /onboarding RESOLVES against the real route table', () {
      // The redirect assertion above passes vacuously if /onboarding does not
      // exist at all (an unknown path is still redirected when signed out). So
      // resolution is asserted separately, against go_router's own resolver.
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(_SignedInAuthService()),
        ],
      );
      addTearDown(container.dispose);
      final router = container.read(driverRouterProvider);

      expect(
        router.configuration
            .findMatch(Uri.parse('/onboarding'))
            .routes
            .isNotEmpty,
        isTrue,
        reason:
            '/onboarding must be in the REAL route table — add '
            '...onboardingRoutes to apps/driver/lib/router.dart. A screen with '
            'no route is not shipped; it is dead code.',
      );
    });

    test(
        '🔴 no screen in features/onboarding collects a code that posts to '
        'nothing (OD-02)', () {
      // OD-02: the "Verification Code" frame maps onto the EXISTING invite/OTP
      // step of the Supabase flow — NOT onto a new self-signup gate. So the
      // acceptable answer here is that features/onboarding/ contains no OTP
      // input at all.
      //
      // If a future change DOES add one, it must post somewhere real: this
      // asserts that any OTP-shaped input in the wizard is accompanied by a
      // genuine Supabase verify call in the same file. A code box that
      // validates six digits locally and then advances a step is a lie — it
      // tells the driver the platform checked their code. Nothing checked it.
      final onboarding = sources
          .where((s) => s.path.replaceAll(r'\', '/').contains(
                'lib/features/onboarding/',
              ))
          .toList();

      expect(
        onboarding,
        isNotEmpty,
        reason:
            'features/onboarding/ does not exist yet — this is the RED that '
            'Task 2 and Task 3 turn green.',
      );

      final otpInput = RegExp(
        r'\bOtpInput\b|\bHopOtpInput\b|otp|verification[_ ]?code',
        caseSensitive: false,
      );
      final verifyCall = RegExp(
        r'verifyOTP\s*\(|verifyOtp\s*\(|\.verify\s*\(',
      );

      for (final source in onboarding) {
        // Comments discussing OTP (as this very lane's doc comments must, to
        // explain WHY there is no OTP screen) are not an OTP input. Only code
        // counts.
        final code = codeLines(source.text).join('\n');

        if (otpInput.hasMatch(code)) {
          expect(
            verifyCall.hasMatch(code),
            isTrue,
            reason:
                '${source.path} collects an OTP-shaped input but calls no real '
                'Supabase verify. NO SCREEN COLLECTS A CODE THAT POSTS TO '
                'NOTHING. A code box that checks six digits locally and then '
                'advances tells the driver the platform verified them. Nothing '
                'did.\n\n'
                'OD-02: the Verification Code frame maps onto the EXISTING '
                'invite/OTP step of the Supabase flow — not onto a new gate in '
                'this wizard. The correct answer is almost certainly to delete '
                'the input.',
          );
        }
      }
    });
  });
}

/// Signed OUT. The router reads exactly `isSignedIn` and `onAuthStateChange`;
/// anything else throws, so a router change that quietly starts depending on
/// more of the auth surface fails loudly here instead of silently passing.
class _SignedOutAuthService implements AuthService {
  @override
  bool get isSignedIn => false;

  @override
  Stream<AuthState> get onAuthStateChange => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
        'no_self_signup_test drives ONLY the route table. The router reached '
        'for ${invocation.memberName}.',
      );
}

/// Signed IN — an admin-provisioned driver, the only kind there is.
class _SignedInAuthService implements AuthService {
  @override
  bool get isSignedIn => true;

  @override
  Stream<AuthState> get onAuthStateChange => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
        'no_self_signup_test drives ONLY the route table. The router reached '
        'for ${invocation.memberName}.',
      );
}
