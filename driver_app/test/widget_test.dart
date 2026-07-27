import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/theme.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

void main() {
  test('themes build with both brightnesses', () {
    expect(hoppinDriverLightTheme.colorScheme.brightness, Brightness.light);
    expect(hoppinDriverDarkTheme.colorScheme.brightness, Brightness.dark);
  });

  testWidgets('StatusBanner notice variant renders', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatusBanner.notice(message: 'All good'),
        ),
      ),
    );
    expect(find.text('All good'), findsOneWidget);
  });
}
