import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/money.dart';
import 'package:hoppin_driver/features/trip/data/models/ride.dart';
import 'package:hoppin_driver/features/trip/data/models/waiting_policy.dart';
import 'package:hoppin_driver/features/trip/ui/widgets/map_pills.dart';
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
      await tester.tap(find.byIcon(Icons.chat_bubble));

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
        // A whole second of slack: the widget truncates with inSeconds, so
        // an exact 90 renders as 01:29 once a few milliseconds have passed
        // between building the policy and pumping the frame.
        billableFrom:
            DateTime.now().toUtc().add(const Duration(seconds: 91)),
      );

      await tester.pumpWidget(wrap(WaitingTimer(policy: policy)));

      // The rate is named alongside the clock, so the driver can tell a
      // waiting passenger what the meter is about to do.
      expect(find.textContaining('Free waiting'), findsOneWidget);
      expect(find.textContaining('£0.30'), findsOneWidget);
      // Counting the free window down is the point — a bare elapsed count
      // would not say when charging starts.
      expect(find.textContaining('01:30'), findsOneWidget);
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

      // Once the free window has gone the label and the rate both say so,
      // and the clock switches to counting the charged time up.
      expect(find.text('Charged waiting'), findsOneWidget);
      expect(find.textContaining('Charged at £0.30 per minute'), findsOneWidget);
      expect(find.textContaining('00:30'), findsOneWidget);
    });
  });

  group('WaitingCancelCard', () {
    testWidgets('counts the wait up and the free-cancel window down',
        (tester) async {
      await tester.pumpWidget(wrap(WaitingCancelCard(
        arrivedAt: DateTime.now().toUtc().subtract(const Duration(minutes: 7)),
        freeCancelRemaining: 157,
      )));

      expect(find.textContaining("You've been waiting for 07:0"), findsOneWidget);
      // The countdown is the difference between a free cancellation and a
      // penalty, so it is stated as a number, not as reassurance.
      expect(find.text('Time left to cancel fee-free'), findsOneWidget);
      expect(find.text('02:37'), findsOneWidget);
    });

    testWidgets('shows no countdown when the free window is unknown',
        (tester) async {
      await tester.pumpWidget(wrap(WaitingCancelCard(
        arrivedAt: DateTime.now().toUtc().subtract(const Duration(minutes: 7)),
      )));

      // A countdown we cannot substantiate would promise a driver a free
      // cancellation the service may still charge for.
      expect(find.text('Time left to cancel fee-free'), findsNothing);
    });

    testWidgets('renders nothing before the driver has marked arrival',
        (tester) async {
      await tester.pumpWidget(wrap(const WaitingCancelCard()));

      expect(find.textContaining("You've been waiting"), findsNothing);
    });
  });

  group('TripNavBanner', () {
    testWidgets('prints the manoeuvre and its distance', (tester) async {
      await tester.pumpWidget(wrap(const TripNavBanner(steps: [
        NavStep(
            instruction: 'Take left',
            distanceMeters: 2414,
            maneuver: 'turn-left'),
      ])));

      // 2414 m is 1.5 mi — road signs here are imperial.
      expect(find.text('Take left · 1.5 mi'), findsOneWidget);
      expect(find.byIcon(Icons.turn_left), findsOneWidget);
    });

    testWidgets('drops the distance when the step starts here', (tester) async {
      await tester.pumpWidget(wrap(const TripNavBanner(steps: [
        NavStep(instruction: 'Head north', maneuver: 'depart'),
      ])));

      // "in 0 ft" is noise, not navigation.
      expect(find.text('Head north'), findsOneWidget);
    });

    testWidgets('renders nothing when the service sent no steps',
        (tester) async {
      await tester.pumpWidget(wrap(const TripNavBanner()));

      // `geo.steps` is null on a finished trip and whenever OSRM was
      // unavailable; the banner must cost no height then.
      expect(find.byIcon(Icons.straight), findsNothing);
    });

    testWidgets('falls back to continue rather than guessing a turn',
        (tester) async {
      await tester.pumpWidget(wrap(const TripNavBanner(steps: [
        NavStep(instruction: 'Keep going', maneuver: 'something-new'),
      ])));

      // An unrecognised manoeuvre must never render an arrow that sends the
      // driver the wrong way.
      expect(find.byIcon(Icons.straight), findsOneWidget);
    });
  });

  group('TripDestinationPlate', () {
    testWidgets('names where the rider is going', (tester) async {
      await tester.pumpWidget(wrap(
          const TripDestinationPlate(label: 'Penrith Call, United Kingdom')));

      expect(find.text('Destination'), findsOneWidget);
      expect(find.text('Penrith Call, United Kingdom'), findsOneWidget);
    });

    testWidgets('renders nothing when the payload carries no label',
        (tester) async {
      await tester.pumpWidget(wrap(const TripDestinationPlate()));

      // `geo.dropoff.label` is nullable. A plate reading "Destination" with
      // nothing under it is worse than no plate.
      expect(find.text('Destination'), findsNothing);
    });
  });
}
