// Gallery smoke: HoppinGallery composes every wave-1 component, so pumping
// it under all four themes in a phone-sized viewport proves the whole
// component set lays out without exceptions or overflows in one pass.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

void main() {
  final themes = <String, ThemeData>{
    'riderLight': HoppinTheme.riderLight(),
    'riderDark': HoppinTheme.riderDark(),
    'driverLight': HoppinTheme.driverLight(),
    'driverDark': HoppinTheme.driverDark(),
  };

  for (final MapEntry(key: name, value: theme) in themes.entries) {
    testWidgets('HoppinGallery renders under $name without errors', (
      tester,
    ) async {
      // Phone-sized viewport: the demo windows are 390x844 logical pixels.
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(theme: theme, home: const HoppinGallery()),
      );
      // Bounded pumps — the busy-button spinner loops, so a settle-style
      // pump would never return.
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(find.byType(HoppinGallery), findsOneWidget);

      // Scroll to the bottom and back — exercises every section's layout.
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -3000),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('£43.75'), findsOneWidget);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, 3000),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
    });
  }
}
