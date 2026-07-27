import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/auth/login_screen.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

/// DEMO-05 seam proof for the driver login.
///
/// The screen reads [loginPrefillProvider] once in initState. With the
/// default (null) the fields start empty — production behavior untouched.
/// With an override the fields boot pre-filled, so the demo's login beat is
/// a single tap on the normal Sign in button.
void main() {
  List<TextFormField> formFields(WidgetTester tester) =>
      tester.widgetList<TextFormField>(find.byType(TextFormField)).toList();

  Widget host({({String email, String password})? prefill, ThemeData? theme}) =>
      ProviderScope(
        overrides: [
          if (prefill != null) loginPrefillProvider.overrideWithValue(prefill),
        ],
        child: MaterialApp(
          theme: theme ?? HoppinTheme.driverDark(),
          home: const DriverLoginScreen(),
        ),
      );

  testWidgets('fields start empty with no prefill override', (tester) async {
    await tester.pumpWidget(host());

    final fields = formFields(tester);
    // Driver login has exactly email + password (no self-sign-up).
    expect(fields, hasLength(2));
    expect(fields[0].controller!.text, isEmpty);
    expect(fields[1].controller!.text, isEmpty);
    expect(find.text('Sign in'), findsOneWidget);
    // Production chrome carries no demo hint.
    expect(
      find.text('Demo credentials pre-filled — just tap Sign in.'),
      findsNothing,
    );
  });

  testWidgets('override seeds email and password before first frame',
      (tester) async {
    await tester.pumpWidget(host(
      prefill: (email: 'demo.driver@hoppin.uk', password: 'hoppin-demo'),
    ));

    final fields = formFields(tester);
    expect(fields[0].controller!.text, 'demo.driver@hoppin.uk');
    expect(fields[1].controller!.text, 'hoppin-demo');
    // Production-identical chrome: wordmark lockup and Sign in remain; the
    // demo hint is the only prefill tell, and it reads quiet.
    expect(find.text('Hoppin'), findsOneWidget);
    expect(find.text('DRIVER'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(
      find.text('Demo credentials pre-filled — just tap Sign in.'),
      findsOneWidget,
    );
  });

  testWidgets(
      'branded chrome: HopButton CTAs and HopBanner invite note in both '
      'themes', (tester) async {
    await tester.pumpWidget(host());
    expect(find.widgetWithText(HopButton, 'Sign in'), findsOneWidget);
    expect(find.widgetWithText(HopButton, 'Forgot password?'), findsOneWidget);
    expect(find.byType(HopBanner), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(tester.takeException(), isNull);

    // Light theme is first-class too.
    await tester.pumpWidget(host(theme: HoppinTheme.driverLight()));
    expect(find.widgetWithText(HopButton, 'Sign in'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
