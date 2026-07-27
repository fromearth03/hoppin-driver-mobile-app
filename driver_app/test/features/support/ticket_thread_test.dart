import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/support/ticket_screen.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

/// The ticket thread — `GET /me/support-tickets/:id` and
/// `POST /me/support-tickets/:id/messages`. Both BOUND, both real, and a person
/// reads what the driver sends.
void main() {
  TicketThread threadWith(List<TicketMessage> messages) => TicketThread(
        ticket: const SupportTicket(id: 't-1', subject: 'Passenger no-show'),
        messages: messages,
      );

  Future<void> pumpThread(
    WidgetTester tester,
    _StubSupportRepository repo,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [supportRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: HoppinTheme.driverDark(),
          home: const DriverTicketScreen(ticketId: 't-1'),
        ),
      ),
    );
    // Bounded pumps only — NEVER pumpAndSettle.
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('the thread renders, staff replies visually distinct',
      (tester) async {
    await pumpThread(
      tester,
      _StubSupportRepository(
        seededThread: threadWith([
          const TicketMessage(id: 'm1', body: 'Nobody came out.'),
          const TicketMessage(
            id: 'm2',
            body: 'Thanks — we have credited the wait time.',
            isStaff: true,
          ),
        ]),
      ),
    );

    expect(find.text('Nobody came out.'), findsOneWidget);
    expect(find.text('Thanks — we have credited the wait time.'),
        findsOneWidget);
    // A staff reply is LABELLED. The driver should know when a human at Hoppin
    // has spoken, rather than inferring it from bubble alignment alone.
    expect(find.text('Hoppin support'), findsOneWidget);
  });

  testWidgets('an empty reply body does not POST', (tester) async {
    final repo = _StubSupportRepository(seededThread: threadWith(const []));
    await pumpThread(tester, repo);

    await tester.tap(find.byKey(const Key('driverSupport.ticket.send')));
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      repo.replies,
      isEmpty,
      reason: 'A no-op request that looks like a send is a reply the driver '
          'believes they made.',
    );
  });

  testWidgets('a real reply POSTs and the thread re-reads', (tester) async {
    final repo = _StubSupportRepository(seededThread: threadWith(const []));
    await pumpThread(tester, repo);

    await tester.enterText(
      find.byKey(const Key('driverSupport.ticket.reply')),
      'Still waiting, 12 minutes now.',
    );
    await tester.tap(find.byKey(const Key('driverSupport.ticket.send')));
    await tester.pump(const Duration(milliseconds: 50));

    expect(repo.replies, ['Still waiting, 12 minutes now.']);
    expect(
      repo.threadReads,
      greaterThan(1),
      reason: 'The thread re-reads after a reply, so the driver sees their own '
          'message land from the SERVER — not an optimistic local bubble that '
          'may not actually exist.',
    );
  });

  testWidgets('404 NOT_FOUND renders a designed state with a forward exit',
      (tester) async {
    await pumpThread(tester, _StubSupportRepository(notFound: true));

    expect(find.text("We can't find that ticket"), findsOneWidget);
    // A dead end on a support screen is where a stuck driver gives up.
    expect(find.text('Back to my tickets'), findsOneWidget);
  });

  testWidgets('a non-404 failure renders a retryable error banner',
      (tester) async {
    await pumpThread(tester, _StubSupportRepository(throws: true));

    // Error asked FIRST — Riverpod 3 keeps isLoading true on a failed future,
    // so a loading-first ladder would show an endless spinner here.
    expect(find.byType(HopBanner), findsWidgets);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}

class _StubSupportRepository implements SupportRepository {
  _StubSupportRepository({
    this.seededThread,
    this.throws = false,
    this.notFound = false,
  });

  final TicketThread? seededThread;
  final bool throws;
  final bool notFound;
  final List<String> replies = [];
  int threadReads = 0;

  @override
  Future<TicketThread> thread(String ticketId) async {
    threadReads++;
    if (notFound) throw Exception('404 NOT_FOUND');
    if (throws) throw Exception('the thread endpoint is down');
    return seededThread ?? TicketThread(ticket: SupportTicket(id: ticketId));
  }

  @override
  Future<void> reply({required String ticketId, required String body}) async {
    replies.add(body);
  }

  @override
  Future<List<SupportTicket>> myTickets() async => const [];

  @override
  Future<String> createTicket({
    required String subject,
    String? category,
    String? typeCode,
    String? priority,
    String? rideId,
    String? body,
    List<String>? tags,
  }) async =>
      'new-ticket-id';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
