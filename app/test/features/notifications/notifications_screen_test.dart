import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/result.dart';
import 'package:hoppin_driver/features/notifications/data/models/app_notification.dart';
import 'package:hoppin_driver/features/notifications/data/notifications_repository.dart';
import 'package:hoppin_driver/features/notifications/logic/notifications_controller.dart';
import 'package:hoppin_driver/features/notifications/ui/notifications_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockNotificationsRepo extends Mock implements NotificationsRepository {}

Widget wrap(_MockNotificationsRepo repo) => ProviderScope(
      overrides: [notificationsRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: NotificationsScreen()),
    );

void main() {
  late _MockNotificationsRepo repo;

  setUp(() {
    repo = _MockNotificationsRepo();
    when(() => repo.page(cursor: any(named: 'cursor')))
        .thenAnswer((_) async => Ok(NotificationsPage(
              notifications: [
                AppNotification(
                  id: 'n1',
                  type: 'trip',
                  title: 'New Trip Request',
                  ntfBody: '2.5 mi',
                  createdAt: DateTime.utc(2026, 8, 31, 9),
                ),
                AppNotification(
                  id: 'n2',
                  type: 'system',
                  title: 'Document Expiring Soon',
                  ntfBody: 'DBS check expiring.',
                  read: true,
                  createdAt: DateTime.utc(2026, 8, 31, 8),
                ),
              ],
              unreadCount: 1,
            )));
  });

  testWidgets('All, Read and Unread filter the same loaded page',
      (tester) async {
    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    // All: both.
    expect(find.text('New Trip Request'), findsOneWidget);
    expect(find.text('Document Expiring Soon'), findsOneWidget);

    await tester.tap(find.text('Unread'));
    await tester.pumpAndSettle();
    expect(find.text('New Trip Request'), findsOneWidget);
    expect(find.text('Document Expiring Soon'), findsNothing);

    await tester.tap(find.text('Read'));
    await tester.pumpAndSettle();
    expect(find.text('New Trip Request'), findsNothing);
    expect(find.text('Document Expiring Soon'), findsOneWidget);
  });

  testWidgets('the unread count is the server\'s, not the loaded page\'s',
      (tester) async {
    // Whole feed unread = 40, while only 2 rows are loaded. Counting the
    // loaded rows would under-report the moment there is a second page.
    when(() => repo.page(cursor: any(named: 'cursor')))
        .thenAnswer((_) async => Ok(NotificationsPage(
              notifications: [
                AppNotification(
                  id: 'n1',
                  title: 'One',
                  createdAt: DateTime.utc(2026, 8, 31),
                ),
              ],
              nextCursor: 'next',
              unreadCount: 40,
            )));

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
        tester.element(find.byType(NotificationsScreen)));
    expect(
      container.read(notificationsControllerProvider).value!.unreadCount,
      40,
    );
  });
}
