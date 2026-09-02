import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/shared/widgets/scroll_edge_blur.dart';

Widget wrap({required int rows, ScrollController? controller}) => MaterialApp(
      home: Scaffold(
        body: ScrollEdgeBlur(
          child: ListView.builder(
            controller: controller,
            itemCount: rows,
            itemBuilder: (_, i) => SizedBox(height: 100, child: Text('row $i')),
          ),
        ),
      ),
    );

/// The strip's current strength, 0 when it is not drawn at all.
double strength(WidgetTester tester) {
  final finder = find.byKey(ScrollEdgeBlur.stripKey);
  if (finder.evaluate().isEmpty) return 0;
  return tester.widget<Opacity>(finder).opacity;
}

void main() {
  testWidgets('a screen that fits shows no strip at all', (tester) async {
    await tester.pumpWidget(wrap(rows: 2));
    await tester.pumpAndSettle();

    expect(strength(tester), 0);
  });

  testWidgets('a long screen softens its bottom edge', (tester) async {
    await tester.pumpWidget(wrap(rows: 40));
    await tester.pumpAndSettle();

    expect(strength(tester), greaterThan(0));
  });

  testWidgets('the strip thins out as the end comes into view rather than '
      'snapping off', (tester) async {
    final controller = ScrollController();
    await tester.pumpWidget(wrap(rows: 40, controller: controller));
    await tester.pumpAndSettle();

    final wideOpen = strength(tester);

    // Part-way into the last screenful: more is still below, but less of it,
    // so the cue should already be weaker. The old binary strip held full
    // strength here and then vanished in one frame.
    controller.jumpTo(controller.position.maxScrollExtent - 40);
    await tester.pumpAndSettle();
    final nearlyThere = strength(tester);

    expect(nearlyThere, lessThan(wideOpen));
    expect(nearlyThere, greaterThan(0));

    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();

    // The final row is always read in the clear.
    expect(strength(tester), 0);
  });
}
