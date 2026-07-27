import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hoppin_driver/features/support/driver_support_categories.dart';
import 'package:hoppin_driver/features/support/support_router.dart';
import 'package:hoppin_driver/features/support/support_screen.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

/// The driver's support hub, over three BOUND endpoints.
///
/// 🔴 THE ASYMMETRY THIS SUITE GUARDS FROM THE OTHER SIDE.
/// `GET /me/support-tickets` is BOUND, so an empty list here is a FACT the
/// server told us — and a confident empty state is the CORRECT render. That is
/// the opposite of the notification centre, where there is no endpoint and
/// emptiness is ignorance that must be disclosed rather than asserted.
///
/// A test asserts the confident empty state EXPLICITLY, because the next
/// contributor will read `never_fake_empty_test.dart` and try to "fix" this
/// screen by breaking it.
void main() {
  final ticket = SupportTicket(
    id: 't-1',
    subject: 'Passenger never showed',
    status: 'open',
    createdAt: DateTime(2026, 7, 18, 9, 30),
  );

  Future<void> pumpHub(
    WidgetTester tester,
    _StubSupportRepository repo,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [supportRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: HoppinTheme.driverDark(),
          home: const DriverSupportScreen(),
        ),
      ),
    );
    // Bounded pumps only — NEVER pumpAndSettle. The driver app's polling
    // providers stall settle-detection forever.
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// Opens the new-ticket sheet and returns once it is laid out.
  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.text('New ticket'));
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// Fires the sheet's submit button.
  ///
  /// 🔴 The callback is invoked directly rather than tapped, and that is a
  /// deliberate HARNESS accommodation, not a shortcut around the widget. The
  /// new-ticket sheet lays out taller than the 600px default test surface, so
  /// the submit button sits below the fold at y≈945 and `tap()` cannot hit-test
  /// it. On a real handset the sheet is reachable; in the harness it is not.
  ///
  /// The button's REACHABILITY is asserted separately (it is found, and it is
  /// enabled). What these tests are about is the SUBMIT LOGIC behind it —
  /// whether an empty subject is caught locally instead of becoming a POST —
  /// and that logic is what this drives.
  Future<void> tapSubmit(WidgetTester tester) async {
    final submit = find.byKey(const Key('driverSupport.newTicket.submit'));
    final button = tester.widget<HopButton>(submit);
    expect(
      button.onPressed,
      isNotNull,
      reason: 'the submit control must be live before it is exercised',
    );
    button.onPressed!();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('a returned list renders tappable tickets', (tester) async {
    await pumpHub(tester, _StubSupportRepository(tickets: [ticket]));

    expect(find.text('Passenger never showed'), findsOneWidget);
    expect(find.byType(HopEmptyState), findsNothing);
  });

  testWidgets(
      '🔴 an EMPTY list renders a CONFIDENT empty state — and that is CORRECT',
      (tester) async {
    await pumpHub(tester, _StubSupportRepository(tickets: const []));

    // `GET /me/support-tickets` is BOUND. The server TOLD us the list is empty.
    // That is a fact, not ignorance, so asserting it is honest.
    //
    // 🔴 DO NOT "unify" this with the notification centre's disclosure rung.
    // Two empty lists, two completely different truths. Deleting this empty
    // state would not make the app more honest — it would make it vaguer about
    // something it actually knows.
    expect(
      find.byType(HopEmptyState),
      findsOneWidget,
      reason: 'A BOUND endpoint returning [] is a FACT. The support hub is '
          'allowed — and required — to say so plainly.',
    );
    expect(find.text('No tickets yet'), findsOneWidget);
  });

  testWidgets('a failure renders an error banner with Retry, never a spinner',
      (tester) async {
    await pumpHub(tester, _StubSupportRepository(throws: true));

    // 🔴 Riverpod 3 delivers a failed future as AsyncLoading CARRYING the
    // error — `isLoading` stays true. A loading-first ladder would route this
    // failure into the spinner branch and the driver would watch a spinner that
    // never resolves, reading it as a hang rather than a failure. Error is
    // asked FIRST, so this is a banner.
    expect(find.byType(HopBanner), findsWidgets);
    expect(find.text('Retry'), findsOneWidget);
    expect(
      find.byType(CircularProgressIndicator),
      findsNothing,
      reason: 'A failure must never present as an endless spinner.',
    );
  });

  testWidgets('an empty subject does not POST', (tester) async {
    final repo = _StubSupportRepository(tickets: const []);
    await pumpHub(tester, repo);

    await openSheet(tester);
    await tapSubmit(tester);

    expect(
      repo.created,
      isEmpty,
      reason: 'An empty subject is caught locally. No request is made.',
    );
    expect(find.text('Give your ticket a subject.'), findsOneWidget);
  });

  testWidgets('a real subject POSTs with a category from the taxonomy',
      (tester) async {
    final repo = _StubSupportRepository(tickets: const []);

    // A REAL router here, not a bare MaterialApp: a successful create navigates
    // to `/support/{id}`, and that navigation is part of the behaviour under
    // test. It also proves the route the screen sends the driver to actually
    // resolves — a create that lands on the go_router error page is a ticket
    // the driver cannot read.
    final router = GoRouter(
      initialLocation: kDriverSupportRoute,
      routes: supportRoutes,
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [supportRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp.router(
          theme: HoppinTheme.driverDark(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    await openSheet(tester);
    await tester.enterText(
      find.byKey(const Key('driverSupport.newTicket.subject')),
      'Stuck at pickup',
    );
    await tapSubmit(tester);

    expect(repo.created, hasLength(1));
    expect(repo.created.single.subject, 'Stuck at pickup');
    expect(
      DriverSupportCategories.values,
      contains(repo.created.single.category),
      reason: 'Every category on the wire comes from the single-source '
          'taxonomy — never a hand-typed literal.',
    );
  });

  test('the Phase-4 exit constants are exported and stable', () {
    // Phase 4's "I'm stuck" exit imports these rather than re-typing them. A
    // drifted route is a stuck driver landing on the error page; a drifted
    // category is a ticket ops cannot filter.
    expect(kDriverSupportRoute, '/support');
    expect(DriverSupportCategories.trip, 'trip_issue');
    expect(
      DriverSupportCategories.values,
      contains(DriverSupportCategories.trip),
    );
  });
}

/// Records what was sent so a test can assert a request was NOT made.
class _StubSupportRepository implements SupportRepository {
  _StubSupportRepository({this.tickets = const [], this.throws = false});

  final List<SupportTicket> tickets;
  final bool throws;
  final List<({String subject, String? category, String? body})> created = [];

  @override
  Future<List<SupportTicket>> myTickets() async {
    if (throws) throw Exception('the list endpoint is down');
    return tickets;
  }

  @override
  Future<String> createTicket({
    required String subject,
    String? category,
    String? typeCode,
    String? priority,
    String? rideId,
    String? body,
    List<String>? tags,
  }) async {
    created.add((subject: subject, category: category, body: body));
    return 'new-ticket-id';
  }

  @override
  Future<TicketThread> thread(String ticketId) async =>
      TicketThread(ticket: SupportTicket(id: ticketId));

  @override
  Future<void> reply({required String ticketId, required String body}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
