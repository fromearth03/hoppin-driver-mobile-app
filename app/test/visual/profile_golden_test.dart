import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/result.dart';
import 'package:hoppin_driver/features/notifications/data/models/app_notification.dart';
import 'package:hoppin_driver/features/notifications/data/notifications_repository.dart';
import 'package:hoppin_driver/features/notifications/ui/notifications_screen.dart';
import 'package:hoppin_driver/features/profile/data/models/driver_preferences.dart';
import 'package:hoppin_driver/features/profile/data/models/driver_profile.dart';
import 'package:hoppin_driver/features/profile/data/preferences_repository.dart';
import 'package:hoppin_driver/features/profile/data/profile_repository.dart';
import 'package:hoppin_driver/features/profile/ui/delete_account_screen.dart';
import 'package:hoppin_driver/features/profile/ui/profile_screen.dart';
import 'package:hoppin_driver/features/profile/ui/settings_screen.dart';
import 'package:hoppin_driver/features/support/data/models/support_ticket.dart';
import 'package:hoppin_driver/features/support/data/support_repository.dart';
import 'package:hoppin_driver/features/support/ui/support_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockProfileRepo extends Mock implements ProfileRepository {}

class _MockPrefsRepo extends Mock implements PreferencesRepository {}

class _MockSupportRepo extends Mock implements SupportRepository {}

class _MockNotificationsRepo extends Mock implements NotificationsRepository {}

/// Renders the profile, settings, support and notification screens at the
/// Figma artboard size and writes each to `test/visual/goldens/`, so the
/// build can be held against the design by eye rather than by assertion.
///
/// Run with `flutter test --update-goldens test/visual/profile_golden_test.dart`.
void main() {
  Future<void> capture(
    WidgetTester tester,
    Widget child,
    String name, {
    List<Override> overrides = const [],
    double height = 932,
  }) async {
    tester.view.physicalSize = Size(430, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true, fontFamily: 'Roboto'),
        home: child,
      ),
    ));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  final profile = _MockProfileRepo();
  final prefs = _MockPrefsRepo();
  final support = _MockSupportRepo();
  final notifications = _MockNotificationsRepo();

  setUpAll(() {
    when(() => profile.me()).thenAnswer((_) async => const Ok(DriverProfile(
          id: 'u1',
          fullName: 'Taimoor Ali Asghar',
          email: 'ali.asghar1@gmail.com',
          phoneNumber: '+44 123 567 8910',
        )));
    when(() => prefs.load())
        .thenAnswer((_) async => const Ok(DriverPreferences()));
    when(() => support.complaintTypes()).thenAnswer((_) async => const Ok([
          ComplaintType('fare_dispute', 'Fare or earnings'),
          ComplaintType('rating', 'A passenger rating'),
          ComplaintType('other', 'Something else'),
        ]));
    when(() => support.tickets()).thenAnswer((_) async => Ok([
          SupportTicket(
            id: 't1',
            subject: 'Low Rating Appeal',
            status: TicketStatus.resolved,
            ticketBody: 'Trip took longer than estimated due to traffic',
            createdAt: DateTime.utc(2026, 8, 28),
          ),
          SupportTicket(
            id: 't2',
            subject: 'Low Rating Appeal',
            status: TicketStatus.pending,
            ticketBody: 'Trip took longer than estimated due to traffic',
            createdAt: DateTime.utc(2026, 8, 29),
          ),
        ]));
    // Anchored to today, not to a fixed calendar date. The screen groups by
    // "Today"/"Yesterday", so a hardcoded date makes the golden fail the
    // moment the clock rolls past midnight — the capture would only ever be
    // valid on the day it was taken.
    // Local components, not UTC: the screen labels days in LOCAL time, so a
    // UTC-built date flips to "Yesterday" near midnight on any machine ahead
    // of UTC.
    final today = DateTime.now();
    DateTime hourToday(int hour) =>
        DateTime(today.year, today.month, today.day, hour);

    when(() => notifications.page(cursor: any(named: 'cursor')))
        .thenAnswer((_) async => Ok(NotificationsPage(notifications: [
              AppNotification(
                id: 'n1',
                type: 'trip',
                title: 'New Trip Request',
                ntfBody: '2.5 mi - £14.61 - 4 min away',
                createdAt: hourToday(9),
              ),
              AppNotification(
                id: 'n2',
                type: 'document',
                title: 'Document Expiring Soon',
                ntfBody:
                    'DBS check expiring, renew by Mar 1 to avoid any disruptions.',
                createdAt: hourToday(8),
              ),
              AppNotification(
                id: 'n3',
                type: 'rating',
                title: 'Passenger Rating',
                ntfBody: '4 Stars. "Great driver, Recommended"',
                read: true,
                createdAt: hourToday(7),
              ),
            ])));
  });

  testWidgets(
    'personal information',
    (t) => capture(t, const ProfileScreen(), 'personal_information',
        overrides: [profileRepositoryProvider.overrideWithValue(profile)]),
  );

  testWidgets(
    'settings',
    (t) => capture(t, const SettingsScreen(), 'settings',
        overrides: [preferencesRepositoryProvider.overrideWithValue(prefs)]),
  );

  testWidgets(
    'delete account',
    (t) => capture(t, const DeleteAccountScreen(), 'delete_account'),
  );

  // Taller than one artboard: the design runs FAQ, form, contact, legal and
  // recent issues down a single scroll, so a phone-height capture would cut
  // the lower cards off entirely.
  testWidgets(
    'help and support',
    (t) => capture(t, const SupportScreen(), 'help_and_support',
        overrides: [supportRepositoryProvider.overrideWithValue(support)],
        height: 2100),
  );

  testWidgets(
    'notifications',
    (t) => capture(t, const NotificationsScreen(), 'notifications',
        overrides: [
          notificationsRepositoryProvider.overrideWithValue(notifications)
        ]),
  );
}
