import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/shared/widgets/scroll_edge_blur.dart';

/// Every authed screen is wrapped in [ScrollEdgeBlur] by the shell routes, so
/// the wrapper must not change the constraints its child is laid out under.
///
/// A bare `Stack` sizes to its largest non-positioned child and loose-fits it,
/// which drops the tight fill the shell handed down. A child that sizes itself
/// from its constraints — every scrollable on every tab — then gets zero
/// height and the screen renders as nothing but the bottom nav.
void main() {
  testWidgets('passes a full-size constraint down to its child',
      (tester) async {
    late BoxConstraints seen;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScrollEdgeBlur(
            child: LayoutBuilder(
              builder: (context, constraints) {
                seen = constraints;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );

    expect(seen.maxHeight, greaterThan(0),
        reason: 'child was laid out with no height to fill');
    expect(seen.maxWidth, greaterThan(0));
  });

  testWidgets('a scrollable child still fills the screen and shows its rows',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScrollEdgeBlur(
            child: ListView(
              children: const [
                SizedBox(height: 40, child: Text('FIRST ROW')),
                SizedBox(height: 40, child: Text('SECOND ROW')),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('FIRST ROW'), findsOneWidget);
    expect(tester.getSize(find.byType(ListView)).height, greaterThan(0));
  });
}
