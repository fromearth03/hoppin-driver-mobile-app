import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/documents/documents_builder.dart';
import 'package:hoppin_driver/features/documents/widgets/document_row.dart';
import 'package:hoppin_driver/features/documents/widgets/document_status_chip.dart';
import 'package:hoppin_driver/features/documents/widgets/document_storage_unavailable.dart';
import 'package:hoppin_driver/features/documents/widgets/document_vocabulary_unavailable.dart';
import 'package:hoppin_driver/router.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:hoppin_ui/hoppin_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The Documents SURFACE: the route resolves, each phase renders its designed
/// state, and the #83 rung is mounted where a driver will actually meet it.
void main() {
  DriverDocument doc(String type, String status) => DriverDocument(
        id: 'doc-$type',
        documentType: type,
        verificationStatus: status,
        uploadedAt: DateTime.utc(2026, 7),
      );

  Future<void> pump(
    WidgetTester tester, {
    List<DriverDocument> served = const [],
    Object? throws,
    bool hang = false,
  }) async {
    tester.view.physicalSize = const Size(1080, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          driverRepositoryProvider.overrideWithValue(
            _StubDriverRepository(served: served, throws: throws, hang: hang),
          ),
        ],
        child: MaterialApp(
          theme: HoppinTheme.driverDark(),
          home: const DocumentsRiblet(),
        ),
      ),
    );
    // Bounded pumps only — never pumpAndSettle.
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  test('🔴 /documents resolves against the REAL driver route table', () {
    // Asked of the ROUTER, never of the source. A screen with no route is not
    // shipped — it is dead code. (`router_reachability_test.dart` explains at
    // length why a test that builds its own GoRouter proves nothing.)
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(_RoutingOnlyAuthService()),
      ],
    );
    addTearDown(container.dispose);
    final router = container.read(driverRouterProvider);

    expect(
      router.configuration.findMatch(Uri.parse('/documents')).routes,
      isNotEmpty,
      reason: '/documents must be in `router.dart`. It is the FRONT DOOR: '
          'POST /drivers/me/online is compliance-gated, so a brand-new driver '
          'cannot reach any other screen until they have been here.',
    );
  });

  testWidgets('the ready wallet renders eight rows and the #83 rung',
      (tester) async {
    await pump(tester, served: [doc('dvla_license', 'pending_review')]);

    expect(find.byType(DocumentRow), findsNWidgets(8));
    expect(find.byType(DocumentStatusChip), findsOneWidget,
        reason: 'exactly one document is on file, so exactly one status exists '
            'to report');

    expect(
      find.byType(DocumentVocabularyUnavailable),
      findsOneWidget,
      reason: 'the #83 rung is UNCONDITIONAL — the `verification_status` enum '
          'is unpublished on every request, forever, until the backend '
          'publishes it. A rung hung off a null branch that never fires is a '
          'disclosure that discloses nothing.',
    );
  });

  testWidgets('the #83 rung is mounted over an EMPTY wallet too',
      (tester) async {
    // The seam does not disappear because the driver has uploaded nothing. The
    // eight "Not uploaded" rows are exactly when a driver is deciding what the
    // words on this screen will mean.
    await pump(tester);
    expect(find.byType(DocumentVocabularyUnavailable), findsOneWidget);
  });

  testWidgets('🔴 a failed read is IGNORANCE, not an empty wallet',
      (tester) async {
    await pump(tester, throws: Exception('socket closed'));

    expect(
      find.byType(DocumentRow),
      findsNothing,
      reason: 'eight cheerful "Not uploaded" rows over a DEAD NETWORK tell a '
          'driver their documents are gone. We do not know that. We know '
          'nothing — and the screen must say so.',
    );
    expect(find.byType(HopEmptyState), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget,
        reason: 'and it must offer a way forward');
  });

  testWidgets('🔴 503 STORAGE_DISABLED strands nobody — it carries an exit',
      (tester) async {
    await pump(
      tester,
      throws: const ApiException(
        statusCode: 503,
        code: 'STORAGE_DISABLED',
        message: 'document storage is not configured',
      ),
    );

    expect(find.byType(DocumentStorageUnavailable), findsOneWidget);
    // A disclosure that strands the driver is only half-honest (the rider's
    // CallUnavailableState set this precedent). Retry, and a real ticket.
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Contact support'), findsOneWidget);
    // And NOT the wallet — inviting eight uploads that would each fail.
    expect(find.byType(DocumentRow), findsNothing);
  });

  testWidgets('the loading phase never renders a wallet it has not read yet',
      (tester) async {
    await pump(tester, hang: true);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(DocumentRow), findsNothing,
        reason: 'a wallet drawn before the read lands is a guess');
  });
}

/// The network, under test control.
class _StubDriverRepository implements DriverRepository {
  _StubDriverRepository({
    this.served = const [],
    this.throws,
    this.hang = false,
  });

  final List<DriverDocument> served;
  final Object? throws;

  /// An in-flight read that never lands. A never-completing [Completer], NOT a
  /// long `Future.delayed` — a pending timer outlives the test binding and
  /// hangs the whole suite.
  final bool hang;

  @override
  Future<List<DriverDocument>> documents() {
    if (hang) return Completer<List<DriverDocument>>().future;
    if (throws != null) return Future<List<DriverDocument>>.error(throws!);
    return Future<List<DriverDocument>>.value(served);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
        'the documents surface reached for ${invocation.memberName}. This stub '
        'answers `documents()` and nothing else.',
      );
}

/// The router reads exactly `isSignedIn` and `onAuthStateChange`.
class _RoutingOnlyAuthService implements AuthService {
  @override
  bool get isSignedIn => true;

  @override
  Stream<AuthState> get onAuthStateChange => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
        'this test drives ONLY the route table; the router reached for '
        '${invocation.memberName}',
      );
}
