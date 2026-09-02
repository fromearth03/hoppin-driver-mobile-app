import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/shared/widgets/app_toast.dart';

Widget host(void Function(BuildContext) onReady) => MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => onReady(context),
            child: const Text('fire'),
          ),
        ),
      ),
    );

void main() {
  testWidgets('a toast says its title and body', (tester) async {
    await tester.pumpWidget(host((c) => AppToast.show(
          c,
          title: 'Late arrival penalty',
          body: 'A penalty for arriving late to a pickup.',
          severity: ToastSeverity.critical,
        )));
    await tester.tap(find.text('fire'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Late arrival penalty'), findsOneWidget);
    expect(find.textContaining('arriving late'), findsOneWidget);
  });

  testWidgets('an ordinary toast clears itself', (tester) async {
    await tester.pumpWidget(host((c) => AppToast.show(
          c,
          title: 'Trip completed',
          body: 'Your fare has been added.',
        )));
    await tester.tap(find.text('fire'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Trip completed'), findsOneWidget);

    // Four seconds is long enough to read a line and short enough not to sit
    // over the map.
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Trip completed'), findsNothing);
  });

  testWidgets('a penalty stays until it is dismissed', (tester) async {
    await tester.pumpWidget(host((c) => AppToast.show(
          c,
          title: 'Penalty applied',
          body: 'GBP 5.90 has been charged.',
          severity: ToastSeverity.critical,
        )));
    await tester.tap(find.text('fire'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.pump(const Duration(seconds: 8));
    await tester.pump(const Duration(milliseconds: 400));

    // Money the driver has lost is not something to blink past.
    expect(find.text('Penalty applied'), findsOneWidget);
  });

  testWidgets('tapping a toast runs its action and closes it', (tester) async {
    var opened = false;
    await tester.pumpWidget(host((c) => AppToast.show(
          c,
          title: 'Penalty applied',
          body: 'Tap to review.',
          severity: ToastSeverity.critical,
          onTap: () => opened = true,
        )));
    await tester.tap(find.text('fire'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Penalty applied'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(opened, isTrue);
    expect(find.text('Penalty applied'), findsNothing);
  });
}
