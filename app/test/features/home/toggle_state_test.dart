import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/home/logic/home_controller.dart';
import 'package:hoppin_driver/features/home/ui/widgets/online_toggle.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('a switching toggle says so, and cannot be tapped again',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(wrap(OnlineToggle(
      isOnline: false,
      isBusy: true,
      onChanged: (_) => taps++,
    )));

    await tester.tap(find.byType(OnlineToggle));
    await tester.pump();

    expect(taps, 0);
    // The driver is waiting on a round trip, so the pill names the state it
    // is moving to rather than the one it has left.
    expect(find.text('Going online…'), findsOneWidget);
  });

  testWidgets('going offline names that direction', (tester) async {
    await tester.pumpWidget(wrap(const OnlineToggle(
      isOnline: true,
      isBusy: true,
    )));

    expect(find.text('Going offline…'), findsOneWidget);
  });

  testWidgets('a busy toggle is dimmed further than a merely blocked one',
      (tester) async {
    await tester.pumpWidget(wrap(const OnlineToggle(isOnline: false)));
    final blocked = tester
        .widgetList<Opacity>(find.byType(Opacity))
        .first
        .opacity;

    await tester.pumpWidget(wrap(const OnlineToggle(
      isOnline: false,
      isBusy: true,
    )));
    final busy =
        tester.widgetList<Opacity>(find.byType(Opacity)).first.opacity;

    expect(busy, lessThan(blocked));
  });

  testWidgets('an idle toggle flips on tap', (tester) async {
    bool? asked;
    await tester.pumpWidget(wrap(OnlineToggle(
      isOnline: false,
      onChanged: (v) => asked = v,
    )));

    await tester.tap(find.byType(OnlineToggle));
    await tester.pump();

    expect(asked, isTrue);
  });

  group('the GPS grace after going online', () {
    test('a driver who just went online is given time to get a fix', () {
      // The server marks a driver stale the instant they go online, because
      // no beat has arrived yet. Showing "we can't see your location" then
      // is an accusation about a fix that has had no chance to land.
      expect(
        shouldWarnNoLocation(
          onlineSince: DateTime.now(),
          now: DateTime.now(),
        ),
        isFalse,
      );
    });

    test('the warning stands once the grace has run out', () {
      final since = DateTime.now().subtract(const Duration(seconds: 11));

      expect(
        shouldWarnNoLocation(onlineSince: since, now: DateTime.now()),
        isTrue,
      );
    });

    test('a driver online since before this session is warned immediately',
        () {
      // Nothing was started here, so there is no fix on its way: an app
      // resumed mid-shift onto a stale driver reports it at once.
      expect(
        shouldWarnNoLocation(onlineSince: null, now: DateTime.now()),
        isTrue,
      );
    });
  });
}
