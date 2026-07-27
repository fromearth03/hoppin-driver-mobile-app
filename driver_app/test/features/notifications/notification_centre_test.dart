import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/notifications/notification_centre_screen.dart';
import 'package:hoppin_driver/features/notifications/notification_feed.dart';
import 'package:hoppin_driver/features/notifications/widgets/notification_history_unavailable.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

/// The centre's own behaviour — the filter bar, the read controls, and the two
/// disclosed inert affordances.
///
/// The HONESTY assertions live next door in `never_fake_empty_test.dart` and
/// `no_badge_over_dead_handler_test.dart`; this file covers the mechanics.
void main() {
  DriverAppNotification note(String id, String title, {bool read = false}) =>
      DriverAppNotification(
        id: id,
        title: title,
        read: read,
        receivedAt: DateTime.now(),
      );

  Future<void> pumpCentre(
    WidgetTester tester, {
    List<DriverAppNotification> seed = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          driverNotificationFeedProvider
              .overrideWith(() => DriverNotificationFeed.seeded(seed)),
        ],
        child: MaterialApp(
          theme: HoppinTheme.driverDark(),
          home: const DriverNotificationCentreScreen(),
        ),
      ),
    );
    // Bounded pumps only — NEVER pumpAndSettle.
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('the All/Read/Unread filter slices the session feed',
      (tester) async {
    await pumpCentre(tester, seed: [
      note('a', 'Offer nearby'),
      note('b', 'Document approved', read: true),
    ]);

    // All.
    expect(find.text('Offer nearby'), findsOneWidget);
    expect(find.text('Document approved'), findsOneWidget);

    await tester.tap(find.text('Unread'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Offer nearby'), findsOneWidget);
    expect(find.text('Document approved'), findsNothing);

    await tester.tap(find.text('Read'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Offer nearby'), findsNothing);
    expect(find.text('Document approved'), findsOneWidget);
  });

  testWidgets('🔴 "Delete all notifications" ships DISABLED and disclosed',
      (tester) async {
    await pumpCentre(tester, seed: [note('a', 'Offer nearby')]);

    final deleteAll = tester.widget<HopButton>(
      find.widgetWithText(HopButton, 'Delete all notifications'),
    );
    expect(
      deleteAll.onPressed,
      isNull,
      reason: 'Deleting a SERVER record we cannot reach is a lie. The control '
          'ships visible and inert, inside the disclosure rung — it body-swaps '
          'when the endpoint lands.',
    );
  });

  testWidgets('"Mark all as read" is ENABLED and genuinely works',
      (tester) async {
    await pumpCentre(tester, seed: [
      note('a', 'Offer nearby'),
      note('b', 'Second offer'),
    ]);

    final markAll = find.widgetWithText(HopButton, 'Mark all as read');
    expect(
      tester.widget<HopButton>(markAll).onPressed,
      isNotNull,
      reason: 'Read-state is purely LOCAL. It claims nothing about a server, '
          'so unlike "delete all" it stays enabled and really acts.',
    );

    // Everything unread to start.
    await tester.tap(find.text('Unread'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Offer nearby'), findsOneWidget);

    tester.widget<HopButton>(markAll).onPressed!();
    await tester.pump(const Duration(milliseconds: 50));

    // Nothing is unread any more — the local act really happened.
    expect(find.text('Offer nearby'), findsNothing);
    expect(find.text('Second offer'), findsNothing);
  });

  testWidgets('the #68 rung is mounted on BOTH branches', (tester) async {
    await pumpCentre(tester);
    expect(find.byType(NotificationHistoryUnavailable), findsOneWidget);

    await pumpCentre(tester, seed: [note('a', 'Offer nearby')]);
    expect(find.byType(NotificationHistoryUnavailable), findsOneWidget);
  });

  test('the unread count tracks the feed and is never a constant', () {
    final container = ProviderContainer(
      overrides: [
        driverNotificationFeedProvider.overrideWith(
          () => DriverNotificationFeed.seeded([
            note('a', 'Offer nearby'),
            note('b', 'Read one', read: true),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(unreadDriverNotificationCountProvider), 1);
  });
}
