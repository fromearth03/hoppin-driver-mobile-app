import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/money.dart';
import 'package:hoppin_driver/features/home/data/models/pending_offer.dart';
import 'package:hoppin_driver/features/home/ui/widgets/decline_dialog.dart';

PendingOffer offer({int expiresInSec = 60, Duration age = Duration.zero}) =>
    PendingOffer(
      id: 'o1',
      rideId: 'r1',
      fare: const Pence(2015),
      pickupLabel: 'City Centre',
      dropoffLabel: 'Railway Station',
      expiresInSec: expiresInSec,
      receivedAt: DateTime.now().subtract(age),
    );

/// Opens the dialog and hands back what it resolved to.
Future<bool?> open(WidgetTester tester, PendingOffer o) async {
  bool? answer;
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () async => answer = await confirmDecline(context, o),
          child: const Text('go'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('go'));
  await tester.pump();
  return answer;
}

void main() {
  testWidgets('asks before throwing the job away', (tester) async {
    await open(tester, offer());

    expect(find.text('Decline this ride?'), findsOneWidget);
    // The fare is the thing being given up, so it is named.
    expect(find.textContaining('£20.15'), findsOneWidget);
  });

  testWidgets('keeping the offer answers no', (tester) async {
    await open(tester, offer());
    await tester.tap(find.text('Keep it'));
    await tester.pumpAndSettle();

    expect(find.text('Decline this ride?'), findsNothing);
  });

  testWidgets('confirming answers yes', (tester) async {
    await open(tester, offer());
    await tester.tap(find.widgetWithText(FilledButton, 'Decline'));
    await tester.pumpAndSettle();

    expect(find.text('Decline this ride?'), findsNothing);
  });

  testWidgets('an offer with seconds left is declined without asking',
      (tester) async {
    // Below the threshold the question costs more than it saves: spending a
    // scarce second on a dialog is how a driver loses a ride they wanted.
    final answer = await open(tester, offer(expiresInSec: 60, age: const Duration(seconds: 56)));
    await tester.pumpAndSettle();

    expect(find.text('Decline this ride?'), findsNothing);
    expect(answer, isTrue);
  });
}
