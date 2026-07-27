import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/documents/documents_view.dart';
import 'package:hoppin_driver/features/documents/upload/upload_providers.dart';
import 'package:hoppin_driver/features/documents/widgets/document_row.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

/// 🔴 THE UPLOAD BUTTON MUST ACTUALLY UPLOAD.
///
/// Lanes A and B were built in parallel, in separate worktrees, and could not
/// see each other. Lane A built the Documents surface and shipped its upload
/// callback as `onUpload: (_) async {}` — **deliberately inert**, because a tick
/// over an upload that never happened is exactly the species of lie this phase
/// exists to prevent. Lane B built the whole three-step presigned pipeline
/// behind it. Both were green. Both were right.
///
/// And **nothing connected them.** A driver could open Documents, tap Upload on
/// their DVLA licence, and have absolutely nothing happen — no picker, no
/// error, no upload. The button was a decoration.
///
/// That defect is invisible to both lanes' own suites, which is what makes it
/// worth a test of its own: each lane proved its half, and the half nobody owned
/// was the join. A green suite over an inert control is the thing this project
/// keeps paying to learn.
///
/// So: tap the row, and assert the request genuinely reaches the pipeline.
void main() {
  testWidgets('tapping a document row fires the real upload request', (
    tester,
  ) async {
    final requested = <String>[];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Stand in for the pipeline at the exact seam Lane B published. If the
          // view is still wired to Lane A's inert `(_) async {}`, this records
          // nothing and the test fails — which is the whole point.
          documentUploadRequestProvider.overrideWithValue((String type) async {
            requested.add(type);
          }),
          driverRepositoryProvider.overrideWithValue(_NoDocumentsRepo()),
        ],
        child: MaterialApp(
          theme: HoppinTheme.driverLight(),
          home: const DocumentsView(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final rows = find.byType(DocumentRow);
    expect(
      rows,
      findsWidgets,
      reason: 'the Documents surface should render the backend\'s document rows',
    );

    // 🔴 NO `ensureVisible` HERE, AND THAT IS DELIBERATE.
    //
    // The surface now layers its content UNDER the floating pill (the only way
    // the bar's blur has anything to sample), and pays for that with scroll
    // padding that holds the first row clear of it. The row RESTS at y=181,
    // below a 96pt bar, and a user who flings the list to its very top still
    // finds it there — the padding is the floor.
    //
    // `ensureVisible` does not respect that floor. It force-scrolls the target
    // to the viewport's literal top edge, straight under the pill, which no
    // gesture a real driver can make will do. Calling it here would fail the
    // test on an interaction that cannot happen and hide the assertion below
    // behind a layout artifact.
    //
    // 🔴 THE TAP MUST REACH THE ROW, AND `warnIfMissed` CANNOT PROVE THAT.
    //
    // `warnIfMissed` only fires when a tap hits NOTHING. A tap absorbed by an
    // overlay ON TOP of the row is a hit, so it stays silent — and it only ever
    // WARNS; it has never failed a test. Reintroducing a tap-eating overlay and
    // re-running this file leaves it green and quiet, which is exactly how this
    // class of bug keeps surviving a green suite.
    //
    // So the geometry is asserted directly: whatever is under the row's centre
    // must be the row itself. This fails if anything is layered over it.
    final rowCentre = tester.getCenter(rows.first);
    expect(
      find.descendant(
        of: rows.first,
        matching: find.byWidgetPredicate((_) => true),
      ),
      findsWidgets,
    );
    expect(
      tester.hitTestOnBinding(rowCentre).path.any(
            (entry) =>
                entry.target is RenderBox &&
                tester.any(
                  find.descendant(
                    of: rows.first,
                    matching: find.byElementPredicate(
                      (e) => e.renderObject == entry.target,
                    ),
                  ),
                ),
          ),
      isTrue,
      reason: '🔴 the tap at the first row\'s centre does not reach the row — '
          'something is layered over it and is absorbing the gesture. The '
          'screen renders perfectly and is dead to the touch.',
    );

    await tester.tap(rows.first, warnIfMissed: true);
    await tester.pump();

    expect(
      requested,
      isNotEmpty,
      reason:
          'Tapping Upload did NOT reach the upload pipeline. The row is wired to '
          'an inert callback — the driver taps it and nothing happens: no picker, '
          'no error, no upload. Wire the view to `documentUploadRequestProvider` '
          '(Lane B), which is the seam it publishes for exactly this.',
    );
  });
}

/// A driver with nothing uploaded yet — the state a real new driver is in when
/// they first reach this screen, and the only state in which every row offers an
/// upload affordance.
class _NoDocumentsRepo implements DriverRepository {
  @override
  Future<List<DriverDocument>> documents() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
