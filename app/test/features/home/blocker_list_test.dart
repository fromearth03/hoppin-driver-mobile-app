import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/home/data/models/driver_status.dart';
import 'package:hoppin_driver/features/home/ui/widgets/blocker_list.dart';

DriverStatus blocked(String reason, [List<String> docs = const []]) =>
    DriverStatus(
      presence: Presence.offline,
      staleAfterSeconds: 90,
      dispatchable: false,
      blockedReason: reason,
      blockingDocumentTypes: docs,
    );

Widget wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  testWidgets('renders one row per blocking document', (tester) async {
    await tester.pumpWidget(wrap(BlockerList(
        status: blocked(
            'DOCS_EXPIRED', ['vehicle_insurance', 'private_hire_licence']))));

    expect(find.text('Vehicle Insurance'), findsOneWidget);
    expect(find.text('Private Hire Licence'), findsOneWidget);
  });

  testWidgets('counts the blockers in the heading', (tester) async {
    await tester.pumpWidget(wrap(BlockerList(
        status: blocked('DOCS_MISSING', ['dbs_check', 'mot_certificate']))));

    expect(find.textContaining('Two things to sort'), findsOneWidget);
  });

  testWidgets('uses the singular for one blocker', (tester) async {
    await tester.pumpWidget(
        wrap(BlockerList(status: blocked('DOCS_EXPIRED', ['dbs_check']))));

    expect(find.textContaining('One thing to sort'), findsOneWidget);
  });

  testWidgets('under review gets no chevron and no tap target', (tester) async {
    await tester.pumpWidget(wrap(
        BlockerList(status: blocked('DOCS_PENDING_REVIEW', ['dbs_check']))));

    expect(find.byIcon(Icons.chevron_right), findsNothing);
    expect(find.textContaining('no action'), findsOneWidget);
  });

  testWidgets('a support-only reason renders one row, not a document list',
      (tester) async {
    await tester.pumpWidget(wrap(BlockerList(status: blocked('SUSPENDED'))));

    expect(find.text('Account suspended'), findsOneWidget);
    expect(find.text('Contact support'), findsOneWidget);
  });

  testWidgets('tapping a document row reports which document', (tester) async {
    String? tapped;
    await tester.pumpWidget(wrap(BlockerList(
      status: blocked('DOCS_REJECTED', ['vehicle_insurance']),
      onOpenDocument: (d) => tapped = d,
    )));

    await tester.tap(find.text('Vehicle Insurance'));
    expect(tapped, 'vehicle_insurance');
  });

  testWidgets('NO_VEHICLE offers vehicle registration', (tester) async {
    var called = false;
    await tester.pumpWidget(wrap(BlockerList(
      status: blocked('NO_VEHICLE'),
      onRegisterVehicle: () => called = true,
    )));

    await tester.tap(find.text('No vehicle registered'));
    expect(called, isTrue);
  });

  testWidgets('renders nothing when the driver is not blocked', (tester) async {
    await tester.pumpWidget(wrap(const BlockerList(
        status: DriverStatus(
            presence: Presence.online,
            staleAfterSeconds: 90,
            dispatchable: true))));

    expect(find.byType(Card), findsNothing);
  });
}
