import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/shared/nav/tab_transition.dart';

/// [TabSwitcher] wraps the child of every route inside the shell, so it must
/// hand that child the same constraints the shell handed it.
///
/// `AnimatedSwitcher`'s own layout builder expands its children to fill.
/// Replacing it with a plain `Stack` loose-fits them instead, and every screen
/// in this app sizes itself from its constraints — so the body collapses to
/// nothing and the driver is left looking at the bottom nav on an empty
/// screen.
void main() {
  testWidgets('gives its child the full height to fill', (tester) async {
    late BoxConstraints seen;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TabSwitcher(
            path: '/',
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
        reason: 'the screen was laid out with no height, so it renders blank');
  });

  testWidgets('a scrollable screen renders its rows', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TabSwitcher(
            path: '/',
            child: ListView(
              children: const [
                SizedBox(height: 40, child: Text('A ROW THE DRIVER SEES')),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('A ROW THE DRIVER SEES'), findsOneWidget);
    expect(tester.getSize(find.byType(ListView)).height, greaterThan(0));
  });

  testWidgets('still fills after switching tabs', (tester) async {
    Widget frame(String path) => MaterialApp(
          home: Scaffold(
            body: TabSwitcher(
              path: path,
              child: ListView(
                children: [SizedBox(height: 40, child: Text('ON $path'))],
              ),
            ),
          ),
        );

    await tester.pumpWidget(frame('/'));
    await tester.pumpWidget(frame('/earnings'));
    await tester.pumpAndSettle();

    expect(find.text('ON /earnings'), findsOneWidget);
  });
}
