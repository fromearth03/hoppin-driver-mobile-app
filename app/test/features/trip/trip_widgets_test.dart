import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/money.dart';
import 'package:hoppin_driver/features/trip/data/models/ride.dart';
import 'package:hoppin_driver/features/trip/data/models/waiting_policy.dart';
import 'package:hoppin_driver/features/trip/ui/widgets/rider_card.dart';
import 'package:hoppin_driver/features/trip/ui/widgets/waiting_timer.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('RiderCard', () {
    const rider =
        Rider(id: 'u1', fullName: 'Alex Morgan', rating: 4.8, ratingCount: 12);

    testWidgets('names the person being collected', (tester) async {
      await tester.pumpWidget(wrap(const RiderCard(rider: rider)));

      // Identity is shown in full after acceptance — the withholding rule
      // applies to the offer card only.
      expect(find.text('Alex Morgan'), findsOneWidget);
      expect(find.textContaining('4.8'), findsOneWidget);
    });

    testWidgets('badges the chat button with the unread count', (tester) async {
      await tester
          .pumpWidget(wrap(const RiderCard(rider: rider, chatUnread: 3)));

      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('shows no badge when there is nothing unread', (tester) async {
      await tester
          .pumpWidget(wrap(const RiderCard(rider: rider, chatUnread: 0)));

      expect(find.text('0'), findsNothing);
    });

    testWidgets('call and chat fire their callbacks', (tester) async {
      var called = false, chatted = false;
      await tester.pumpWidget(wrap(RiderCard(
        rider: rider,
        onCall: () => called = true,
        onChat: () => chatted = true,
      )));

      await tester.tap(find.byIcon(Icons.phone));
      await tester.tap(find.byIcon(Icons.chat_bubble_outline));

      expect(called, isTrue);
      expect(chatted, isTrue);
    });

    testWidgets('renders a rider with no rating yet', (tester) async {
      await tester.pumpWidget(
          wrap(const RiderCard(rider: Rider(id: 'u2', fullName: 'Sam Patel'))));

      expect(find.text('Sam Patel'), findsOneWidget);
      // A missing rating renders an em dash, never "0.0", which would read
      // as a terrible passenger rather than a new one.
      expect(find.textContaining('0.0'), findsNothing);
    });
  });

  group('WaitingTimer', () {
    testWidgets('states when charging starts, not just elapsed time',
        (tester) async {
      final policy = WaitingPolicy(
        freeWaitSeconds: 180,
        perMinutePence: const Pence(30),
        noShowFeePence: const Pence(5900),
        billableFrom: DateTime.now().toUtc().add(const Duration(seconds: 90)),
      );

      await tester.pumpWidget(wrap(WaitingTimer(policy: policy)));

      expect(find.textContaining('free'), findsOneWidget);
      expect(find.textContaining('£0.30'), findsOneWidget);
    });

    testWidgets('says plainly once waiting is being charged', (tester) async {
      final policy = WaitingPolicy(
        freeWaitSeconds: 180,
        perMinutePence: const Pence(30),
        noShowFeePence: const Pence(5900),
        billableFrom:
            DateTime.now().toUtc().subtract(const Duration(seconds: 30)),
      );

      await tester.pumpWidget(wrap(WaitingTimer(policy: policy)));

      expect(
          find.textContaining('Waiting time is being charged'), findsOneWidget);
    });
  });
}
