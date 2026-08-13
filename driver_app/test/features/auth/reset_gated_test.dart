import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/auth/reset_landing_screen.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

/// Password-reset landing: a real set-password form, no contact-support stub.
void main() {
  Future<void> pumpReset(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: HoppinTheme.driverDark(),
          home: const DriverResetLandingScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('renders the set-password form, not a support dead-end',
      (tester) async {
    await pumpReset(tester);

    expect(find.text('Set a new password'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.widgetWithText(HopButton, 'Set new password'), findsOneWidget);
    expect(find.byKey(DriverResetKeys.backToSignIn), findsOneWidget);
    expect(find.byType(IconButton), findsNWidgets(2));
    expect(find.text('Contact support'), findsNothing);
  });
}
