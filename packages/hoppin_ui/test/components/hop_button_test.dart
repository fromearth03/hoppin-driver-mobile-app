// HopButton — Figma spec: five variants, full-width, radius control(12),
// no elevation. primary = navy fill + white label; secondary = white fill +
// navy border; green/red = solid semantic fill + white label; dangerOutline
// = white fill + red border + red label. Both rider themes.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import '_pump.dart';

void main() {
  Material buttonMaterial(WidgetTester tester) => tester.widget<Material>(
        find
            .descendant(
              of: find.byType(HopButton),
              matching: find.byType(Material),
            )
            .first,
      );

  for (final MapEntry(key: name, value: theme) in riderThemes.entries) {
    final colors = colorsOf(theme);

    testWidgets('primary: navy fill + onAccent label, radius 12, flat ($name)',
        (tester) async {
      await pumpComponent(
        tester,
        theme,
        HopButton.primary(label: 'Confirm Booking', onPressed: () {}),
      );
      final material = buttonMaterial(tester);
      expect(material.color, colors.accent);
      expect(material.elevation, 0);
      final shape = material.shape! as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(12));
      final label = tester.widget<Text>(find.text('Confirm Booking'));
      expect(label.style!.color, colors.onAccent);
    });

    testWidgets('secondary: white fill + navy border + navy label ($name)',
        (tester) async {
      await pumpComponent(
        tester,
        theme,
        HopButton.secondary(label: 'Schedule Ride', onPressed: () {}),
      );
      final material = buttonMaterial(tester);
      expect(material.color, colors.card);
      final shape = material.shape! as RoundedRectangleBorder;
      expect(shape.side.color, colors.accent);
      final label = tester.widget<Text>(find.text('Schedule Ride'));
      expect(label.style!.color, colors.accent);
    });

    testWidgets('green: solid success fill + white label + icon ($name)',
        (tester) async {
      await pumpComponent(
        tester,
        theme,
        HopButton.green(
          label: 'Call',
          icon: Icons.call,
          onPressed: () {},
        ),
      );
      final material = buttonMaterial(tester);
      expect(material.color, colors.success);
      expect(find.byIcon(Icons.call), findsOneWidget);
      final label = tester.widget<Text>(find.text('Call'));
      expect(label.style!.color, colors.onAccent);
    });

    testWidgets('red: solid error fill + white label ($name)', (tester) async {
      await pumpComponent(
        tester,
        theme,
        HopButton.red(label: 'Cancel', onPressed: () {}),
      );
      final material = buttonMaterial(tester);
      expect(material.color, colors.error);
      final label = tester.widget<Text>(find.text('Cancel'));
      expect(label.style!.color, colors.onAccent);
    });

    testWidgets('dangerOutline: white fill + red border + red label ($name)',
        (tester) async {
      await pumpComponent(
        tester,
        theme,
        HopButton.dangerOutline(label: 'Emergency SOS', onPressed: () {}),
      );
      final material = buttonMaterial(tester);
      expect(material.color, colors.card);
      final shape = material.shape! as RoundedRectangleBorder;
      expect(shape.side.color, colors.error);
      final label = tester.widget<Text>(find.text('Emergency SOS'));
      expect(label.style!.color, colors.error);
    });

    testWidgets('onPressed fires once on tap ($name)', (tester) async {
      var taps = 0;
      await pumpComponent(
        tester,
        theme,
        HopButton.primary(label: 'Go', onPressed: () => taps++),
      );
      await tester.tap(find.byType(HopButton));
      expect(taps, 1);
    });

    testWidgets('busy shows spinner and swallows taps ($name)', (tester) async {
      var taps = 0;
      await pumpComponent(
        tester,
        theme,
        HopButton.primary(label: 'Go', busy: true, onPressed: () => taps++),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(HopButton), warnIfMissed: false);
      expect(taps, 0);
    });
  }
}
