// HopBottomNav — Figma spec: white bar, exactly 4 fixed tabs
// (Book/History/Payments/Support). Active tab = navy capsule (icon + label
// white); inactive = icon-only glyph. onTap(int) reports the index. Both
// rider themes.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import '_pump.dart';

void main() {
  for (final MapEntry(key: name, value: theme) in riderThemes.entries) {
    final colors = colorsOf(theme);

    testWidgets('exactly 4 tabs; active tab shows its label ($name)',
        (tester) async {
      await pumpChrome(
        tester,
        theme,
        HopBottomNav(currentIndex: 0, onTap: (_) {}),
      );
      // Active tab (Book) shows its label; inactive tabs are icon-only.
      expect(find.text('Book'), findsOneWidget);
      expect(find.text('History'), findsNothing);
      expect(find.text('Payments'), findsNothing);
      expect(find.text('Support'), findsNothing);
    });

    testWidgets('active tab paints a navy(accent) capsule ($name)',
        (tester) async {
      await pumpChrome(
        tester,
        theme,
        HopBottomNav(currentIndex: 2, onTap: (_) {}),
        alignment: Alignment.bottomCenter,
      );
      // The active capsule fill is the accent colour. (This reads DecoratedBox,
      // not Container: the nav's fills moved to DecoratedBox when the bar went
      // to glass. The ASSERTION is unchanged — the navy capsule is still the
      // active state, and it must still be painted with the accent token.)
      final capsuleColors = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(HopBottomNav),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .map((d) => d.color)
          .toList();
      expect(capsuleColors, contains(colors.accent));
      expect(find.text('Payments'), findsOneWidget);
    });

    testWidgets('the bar itself is GLASS — translucent over a live blur ($name)',
        (tester) async {
      await pumpChrome(
        tester,
        theme,
        HopBottomNav(currentIndex: 0, onTap: (_) {}),
      );

      // It used to be an opaque `colors.card` Material. It is a frosted pane
      // now: a real BackdropFilter (content scrolls under it and blurs THROUGH
      // it) behind a deliberately translucent fill.
      expect(
        find.descendant(
          of: find.byType(HopBottomNav),
          matching: find.byType(BackdropFilter),
        ),
        findsOneWidget,
        reason: 'no BackdropFilter — a translucent fill with nothing blurring '
            'behind it is a tinted box, not glass',
      );

      final fills = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(HopBottomNav),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .map((d) => d.color)
          .toList();

      expect(fills, contains(colors.glass));
      expect(
        colors.glass.a,
        lessThan(1.0),
        reason: 'the glass fill MUST be translucent — an opaque one makes the '
            'blur behind it a pure cost with no visible effect',
      );
    });

    testWidgets('tapping a tab reports its index ($name)', (tester) async {
      var tapped = -1;
      await pumpChrome(
        tester,
        theme,
        HopBottomNav(currentIndex: 0, onTap: (i) => tapped = i),
      );
      // The History tab is at index 1 — tap its icon glyph.
      await tester.tap(find.byIcon(Icons.history));
      expect(tapped, 1);
    });
  }
}
