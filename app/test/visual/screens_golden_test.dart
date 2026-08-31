import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/auth/ui/forgot_password_screen.dart';
import 'package:hoppin_driver/features/auth/ui/reset_password_screen.dart';
import 'package:hoppin_driver/features/auth/ui/sign_in_screen.dart';

/// Renders each redesigned screen at the Figma artboard size and writes it to
/// `test/visual/goldens/`, so the build can be held against the design by eye
/// rather than by assertion.
///
/// Run with `flutter test --update-goldens test/visual` to refresh.
void main() {
  Future<void> capture(WidgetTester tester, Widget child, String name) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
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

  testWidgets('sign in', (t) => capture(t, const SignInScreen(), 'sign_in'));
  testWidgets('forgot password',
      (t) => capture(t, const ForgotPasswordScreen(), 'forgot_password'));
  testWidgets('reset password',
      (t) => capture(t, const ResetPasswordScreen(), 'reset_password'));
}
