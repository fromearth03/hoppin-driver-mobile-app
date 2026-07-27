// Acceptance tests for MoneyTicker — the pence-based animated money value
// (driver-ux-motion §5 'Number ticker'). First build is static; changes
// roll old → new over ~900ms ease-out as a per-digit odometer (static
// glyph strips in ClipRects, £ and '.' never move); at rest the value is
// one static Text; tabular figures always. Bounded pumps only.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

final Map<String, ThemeData> themes = <String, ThemeData>{
  'riderLight': HoppinTheme.riderLight(),
  'riderDark': HoppinTheme.riderDark(),
  'driverLight': HoppinTheme.driverLight(),
  'driverDark': HoppinTheme.driverDark(),
};

Widget harness(ThemeData theme, Widget child) {
  return MaterialApp(
    theme: theme,
    home: Scaffold(body: Center(child: child)),
  );
}

/// Asserts the mid-roll odometer state: no whole-string Text (the value is
/// riding per-digit strips), while the `£` sign and decimal point stand
/// still as their own static glyphs.
void expectRolling(WidgetTester tester, {required List<String> notWhole}) {
  for (final whole in notWhole) {
    expect(find.text(whole), findsNothing,
        reason: '$whole must not render whole mid-roll');
  }
  expect(find.text('£'), findsOneWidget,
      reason: 'the £ sign is static through the roll');
  expect(find.text('.'), findsOneWidget,
      reason: 'the decimal point is static through the roll');
  expect(
    find.descendant(
      of: find.byType(MoneyTicker),
      matching: find.byType(ClipRect),
    ),
    findsWidgets,
    reason: 'digits roll as strips inside ClipRects',
  );
}

void main() {
  group('MoneyTicker', () {
    testWidgets('first build renders statically — no count-up on mount', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(HoppinTheme.driverDark(), const MoneyTicker(pence: 4375)),
      );
      expect(find.text('£43.75'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('£43.75'), findsOneWidget);
    });

    testWidgets('animates old → new when pence changes on the same element', (
      tester,
    ) async {
      Widget build(int pence) => harness(
        HoppinTheme.driverDark(),
        MoneyTicker(pence: pence, key: const ValueKey('ticker')),
      );

      await tester.pumpWidget(build(4375));
      expect(find.text('£43.75'), findsOneWidget);

      await tester.pumpWidget(build(5014));
      await tester.pump(const Duration(milliseconds: 450));
      expectRolling(tester, notWhole: ['£43.75', '£50.14']);

      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('£50.14'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(MoneyTicker),
          matching: find.byType(ClipRect),
        ),
        findsNothing,
        reason: 'at rest the odometer collapses to one static Text',
      );
    });

    testWidgets('fromPence seeds an arbitrary start and animates on mount', (
      tester,
    ) async {
      // The 03-03 dashboard remounts mid-absorb and must seed the ticker
      // from the pre-absorb value so the tick-up beat renders visibly.
      await tester.pumpWidget(
        harness(
          HoppinTheme.driverDark(),
          const MoneyTicker(pence: 5014, fromPence: 4375),
        ),
      );
      expect(find.text('£43.75'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 450));
      expectRolling(tester, notWhole: ['£43.75', '£50.14']);

      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('£50.14'), findsOneWidget);
    });

    testWidgets('delay holds the start value before the roll (§5 absorb)', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(
          HoppinTheme.driverDark(),
          const MoneyTicker(
            pence: 5014,
            fromPence: 4375,
            delay: Duration(milliseconds: 300),
          ),
        ),
      );
      // Through the hold the pre-absorb value stays whole and static.
      expect(find.text('£43.75'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('£43.75'), findsOneWidget);

      // 500ms in = 200ms past the hold: rolling.
      await tester.pump(const Duration(milliseconds: 300));
      expectRolling(tester, notWhole: ['£43.75', '£50.14']);

      // 300ms delay + 900ms roll, with margin: settled.
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.text('£50.14'), findsOneWidget);
    });

    for (final MapEntry(key: name, value: theme) in themes.entries) {
      testWidgets('default style is tabular Poppins in textHi ($name)', (
        tester,
      ) async {
        await tester.pumpWidget(
          harness(theme, const MoneyTicker(pence: 740)),
        );
        // R1 swapped GeistMono → Poppins; the ticker keeps tabular figures on
        // the Figma family so digit cells never jitter.
        final style = tester.widget<Text>(find.text('£7.40')).style!;
        expect(
          style.fontFeatures,
          contains(const FontFeature.tabularFigures()),
        );
        expect(style.fontFamily, contains('Poppins'));
        expect(style.color, theme.extension<HoppinColors>()!.textHi);
      });
    }

    testWidgets('caller style merges over the tabular default', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(
          HoppinTheme.driverDark(),
          const MoneyTicker(pence: 740, style: TextStyle(fontSize: 48)),
        ),
      );
      final style = tester.widget<Text>(find.text('£7.40')).style!;
      expect(style.fontSize, 48);
      expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
    });
  });
}
