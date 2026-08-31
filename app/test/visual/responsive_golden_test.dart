import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/theme/app_theme.dart';
import 'package:hoppin_driver/features/auth/ui/sign_in_screen.dart';
import 'package:hoppin_driver/shared/responsive_frame.dart';

/// The lesson behind this file: every other golden runs at exactly 430×932,
/// which proved a screen can look right on an iPhone and be a mess on a
/// Surface Pro without a single test noticing. These captures pin the app at
/// the widths where that happened, so "responsive" is asserted rather than
/// assumed.
void main() {
  Future<void> capture(
    WidgetTester tester,
    Size size,
    String name,
  ) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // The real composition: theme + frame wrapping the screen, exactly as
    // MaterialApp.builder assembles it in app.dart.
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        theme: appTheme().copyWith(
          textTheme: appTheme().textTheme.apply(fontFamily: 'Roboto'),
        ),
        builder: (context, child) =>
            ResponsiveFrame(child: child ?? const SizedBox.shrink()),
        home: const SignInScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  group('ResponsiveFrame behaviour', () {
    testWidgets('a phone passes through untouched', (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(
        home: ResponsiveFrame(child: Scaffold(body: Text('content'))),
      ));

      // No frame chrome on a phone: the child is the whole window.
      expect(find.byType(ClipRRect), findsNothing);
      expect(tester.getSize(find.byType(Scaffold)).width, 430);
    });

    testWidgets('a wide screen gets the centred phone column', (tester) async {
      tester.view.physicalSize = const Size(912, 1368);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(
        home: ResponsiveFrame(child: Scaffold(body: Text('content'))),
      ));

      // The app renders at the design width, centred.
      final scaffold = tester.getRect(find.byType(Scaffold));
      expect(scaffold.width, ResponsiveFrame.columnWidth);
      expect(scaffold.center.dx, closeTo(912 / 2, 0.5));
    });

    testWidgets('the column lies to MediaQuery on purpose', (tester) async {
      tester.view.physicalSize = const Size(1368, 912);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      Size? seen;
      await tester.pumpWidget(MaterialApp(
        home: ResponsiveFrame(
          child: Builder(builder: (context) {
            seen = MediaQuery.sizeOf(context);
            return const SizedBox();
          }),
        ),
      ));

      // Screens size against MediaQuery (BrandHeader takes a fraction of
      // it). Inside the frame the window IS the column, or every hero panel
      // would size itself against a desktop.
      expect(seen!.width, ResponsiveFrame.columnWidth);
    });
  });

  group('sign in across real devices', () {
    testWidgets(
      'iPhone 16 Pro Max width',
      (t) => capture(t, const Size(430, 932), 'responsive_signin_phone'),
    );

    testWidgets(
      'Surface Pro 7 portrait',
      (t) => capture(t, const Size(912, 1368), 'responsive_signin_surface'),
    );

    testWidgets(
      'landscape laptop',
      (t) => capture(t, const Size(1368, 912), 'responsive_signin_landscape'),
    );
  });
}
