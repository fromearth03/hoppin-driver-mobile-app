// HopListRow — Figma spec: leading navy icon + label + trailing chevron;
// optional hairline divider. Tap fires. Both rider themes.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import '_pump.dart';

void main() {
  for (final MapEntry(key: name, value: theme) in riderThemes.entries) {
    final colors = colorsOf(theme);

    testWidgets('leading icon (navy) + label + trailing chevron ($name)',
        (tester) async {
      await pumpComponent(
        tester,
        theme,
        HopListRow(
          icon: Icons.person_outline,
          label: 'Personal Information',
          onTap: () {},
        ),
      );
      expect(find.text('Personal Information'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      final leading = tester.widget<Icon>(
        find.byIcon(Icons.person_outline),
      );
      expect(leading.color, colors.accent);
    });

    testWidgets('divider variant draws a hairline ($name)', (tester) async {
      await pumpComponent(
        tester,
        theme,
        HopListRow(
          icon: Icons.settings_outlined,
          label: 'Settings',
          divider: true,
          onTap: () {},
        ),
      );
      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('onTap fires ($name)', (tester) async {
      var taps = 0;
      await pumpComponent(
        tester,
        theme,
        HopListRow(
          icon: Icons.logout,
          label: 'Logout',
          onTap: () => taps++,
        ),
      );
      await tester.tap(find.text('Logout'));
      expect(taps, 1);
    });
  }
}
