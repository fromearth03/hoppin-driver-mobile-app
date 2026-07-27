// Shared pump harness for the rebuilt Figma component tests. Every component
// must resolve its colours/radii/type through context.hoppin, so the tests
// pump under BOTH riderLight and riderDark and read expected values straight
// off each theme's HoppinColors extension.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

/// The two rider themes every component test asserts against (light =
/// pixel-faithful to Figma, dark = derived first-class).
final Map<String, ThemeData> riderThemes = <String, ThemeData>{
  'riderLight': HoppinTheme.riderLight(),
  'riderDark': HoppinTheme.riderDark(),
};

/// Pumps [child] under [theme] inside a Scaffold, phone-width so full-width
/// controls lay out without overflow.
Future<void> pumpComponent(
  WidgetTester tester,
  ThemeData theme,
  Widget child,
) {
  return tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    ),
  );
}

/// Pumps a piece of CHROME (the floating top pill, the anchored bottom nav)
/// the way the shell actually mounts it: LAYERED over scrolling content, at
/// full screen width, with no padding of its own.
///
/// [pumpComponent] centres its child inside a 16pt inset, which is exactly
/// wrong for chrome: it would hand the top bar a margin the shell never gives
/// it (so a bar that forgot to detach itself would still LOOK detached), and it
/// would put nothing behind the blur (so a BackdropFilter with nothing to
/// sample would still LOOK like glass). Both failures are invisible in a
/// screenshot, which is precisely why they need a harness that cannot produce
/// them.
Future<void> pumpChrome(
  WidgetTester tester,
  ThemeData theme,
  Widget chrome, {
  Alignment alignment = Alignment.topCenter,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        extendBody: true,
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            // Something for the blur to actually sample.
            ListView.builder(
              itemCount: 30,
              itemBuilder: (_, i) => ListTile(title: Text('row $i')),
            ),
            Align(alignment: alignment, child: chrome),
          ],
        ),
      ),
    ),
  );
}

/// The HoppinColors extension for [theme].
HoppinColors colorsOf(ThemeData theme) => theme.extension<HoppinColors>()!;
