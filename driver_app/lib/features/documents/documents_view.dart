import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import 'documents_builder.dart';
import 'documents_state.dart';
import 'upload/upload_providers.dart';
import 'widgets/document_row.dart';
import 'widgets/document_storage_unavailable.dart';
import 'widgets/document_vocabulary_unavailable.dart';

/// The compliance wallet — the driver's front door.
///
/// 🔴 THE THREE THINGS THIS SURFACE EXISTS TO GET RIGHT:
///
/// 1. **Eight rows, and they ARE the contract.** The list is ITERATED off
///    `DriverRepository.documentTypes`. It is never re-typed here, because a
///    local list is exactly how the Figma's invented `Medical Certificate`
///    (which the backend would `400 VALIDATION_FAILED`) gets in front of a
///    driver, and exactly how `mot_certificate`, `v5c_logbook` and
///    `caz_compliance_proof` — three documents a Wolverhampton private-hire
///    driver is LEGALLY REQUIRED to hold — get quietly dropped.
/// 2. **The server's own status word, verbatim** (`DocumentStatusChip`). Never
///    the Figma's green "Valid": that word is not in the backend's vocabulary,
///    and over a `pending_review` licence it tells a driver they may legally
///    work when we do not know that.
/// 3. **`503 STORAGE_DISABLED` is a designed state**, not a blank and not a
///    crash — on the one screen that stands between a new driver and their
///    first shift.
class DocumentsView extends ConsumerWidget {
  /// Creates the documents surface.
  const DocumentsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(documentsInteractorProvider);
    final interactor = ref.read(documentsInteractorProvider.notifier);
    final colors = context.hoppin.colors;

    // 🔴 THE BAR IS LAYERED, NOT SLOTTED — see HopGlass's own note.
    //
    // This screen handed HopTopBar to `Scaffold.appBar`, which reserves a slot
    // ABOVE the body. A BackdropFilter filters what has already been painted
    // beneath it, and in an appBar slot the answer is: nothing. The blur was a
    // no-op and the "frosted" pill was a translucent tinted box — the exact
    // failure the primitive's docstring warns about, and one that photographs
    // perfectly, which is why it shipped.
    //
    // So the body now takes the full viewport and the pill floats over it. The
    // bill for that is scroll clearance, paid by `_ChromeInsets` below.
    return Scaffold(
      backgroundColor: colors.canvas,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: _ChromeInsets(
              child: switch (state.phase) {
                // OD-11. The rung, and NOTHING ELSE: rendering eight cheerful
                // empty rows underneath a "storage is down" banner would invite
                // the driver to tap Upload on every one and watch each fail.
                DocumentsPhase.storageDisabled => DocumentStorageUnavailable(
                    onRetry: interactor.refresh,
                    onContactSupport: () => interactor.contactSupport(
                      'Document storage unavailable',
                    ),
                  ),
                DocumentsPhase.loading => const Center(
                    child: CircularProgressIndicator(),
                  ),
                // 🔴 A failed read is IGNORANCE, not an empty wallet. The eight
                // rows do NOT render here: eight "Not uploaded" rows over a dead
                // network tell a driver their documents are gone.
                DocumentsPhase.error => Center(
                    child: HopEmptyState(
                      headline: 'We could not load your documents',
                      supporting: state.error ??
                          'Something went wrong reaching the platform. Your '
                              'documents are safe — we just cannot show them '
                              'right now.',
                      actionLabel: 'Try again',
                      onAction: interactor.refresh,
                    ),
                  ),
                DocumentsPhase.ready => _Wallet(state: state),
              },
            ),
          ),
          // POSITIONED, NOT Align — the overlay is bound to its own footprint.
          //
          // A non-positioned `Align` in a `Stack` IS laid out to the full Stack
          // (800x600 here) and paints its child at the top. It does NOT,
          // however, swallow the page: `RenderPositionedBox` paints nothing of
          // its own and only hit-tests where its CHILD actually is, so taps
          // below the pill fall straight through to the rows. (Measured, both
          // ways round, before this comment was rewritten — the earlier version
          // of this note claimed the `Align` "hit-tests across the entire page"
          // and left the screen "completely dead to the touch". That is not what
          // happens, and a false mechanism in a comment is worse than none: the
          // next reader debugs the wrong widget.)
          //
          // The tap-eating bug this screen really did have was the ring of AIR
          // around the floating pill: `HopGlass.margin` is a `Padding`, and a
          // `Padding` hit-tests its whole box, inset included — so the band
          // above the content ate every tap that landed in it while looking
          // perfectly alive. That is fixed inside the primitive (see the note on
          // `HopGlass.build`), which is the only place it can be fixed once.
          //
          // `Positioned` stays regardless, because it states the intent the
          // layout depends on rather than leaning on a shrink-wrap subtlety: it
          // binds the overlay to the bar's own intrinsic height — the full
          // floating footprint (pill + margins) the bar reports via
          // `preferredSize` — instead of to the whole Stack.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            // 🔴 NEVER null — a null onBack hides the chevron and strands the
            // driver on the documents wallet with no way back to the profile
            // hub they came from. Pop if there's a stack; otherwise fall back
            // to the profile hub.
            child: HopTopBar(
              title: 'Documents',
              onBack: () =>
                  context.canPop() ? context.pop() : context.go('/profile'),
            ),
          ),
        ],
      ),
    );
  }

}

/// Grants the scroll clearance the floating pill now owes this screen.
///
/// The other half of the layering bargain (the rider shell makes the same one).
/// Content that can pass UNDER the chrome can also be PARKED under it: a
/// ListView starting at y=0 starts beneath the pill, and its first row is not
/// merely dimmed — it is unreachable, because you cannot scroll up past the top
/// of a scroll view.
///
/// The room must be ADDITIVE. A Padding around the body would shrink the
/// viewport and rebuild the very Column we just left, leaving the blur nothing
/// to sample again. So it is granted as MediaQuery padding, which every scroll
/// view already knows how to consume, and the numbers are chrome tokens — if the
/// pill's height changes, this moves with it.
class _ChromeInsets extends StatelessWidget {
  const _ChromeInsets({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final chrome = context.hoppin.chrome;
    return MediaQuery(
      data: media.copyWith(
        padding: media.padding.copyWith(
          top: media.padding.top + chrome.scrollPaddingTop,
        ),
      ),
      child: child,
    );
  }
}

class _Wallet extends ConsumerWidget {
  const _Wallet({required this.state});

  final DocumentsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    final interactor = ref.read(documentsInteractorProvider.notifier);

    return RefreshIndicator(
      onRefresh: interactor.refresh,
      child: ListView(
        // Reads back the room the pill published above. A bare
        // `EdgeInsets.all(gutter)` here would park the first document row
        // permanently under the floating bar — unreachable, not just dimmed.
        padding: context.chromeScrollPadding(
          horizontal: hoppin.spacing.gutter,
          bottom: hoppin.spacing.gutter,
        ),
        children: [
          Text(
            'Your compliance documents',
            style: hoppin.type.section.copyWith(color: colors.textHi),
          ),
          SizedBox(height: hoppin.spacing.xs),
          Text(
            'You need every one of these on file before you can go online.',
            style: hoppin.type.meta.copyWith(color: colors.textMid),
          ),
          SizedBox(height: hoppin.spacing.md),

          // 🔴 ITERATE THE CONTRACT. Not a local list. Never a local list.
          for (final type in DriverRepository.documentTypes) ...[
            DocumentRow(
              documentType: type,
              // null → NOT UPLOADED. Not pending. Not valid.
              document: state.documentFor(type),
              // WIRED (wave 2) to Lane B's presigned pipeline — the seam it
              // publishes for exactly this, and the only thing this view needs
              // to know about it. Behind this one call sit three steps, a bare
              // Dio that must never carry a bearer, a downscaler, and a
              // five-minute TTL; none of that is this view's business.
              //
              // It shipped as `(_) async {}` while the two lanes were built in
              // parallel — deliberately inert rather than a fake success, since
              // a tick over an upload that never happened is the exact lie this
              // plan exists to prevent. But inert is only honest until the
              // pipeline lands: after that it is just a dead button, and a dead
              // button is its own lie. `upload_wiring_test.dart` fails if this
              // ever goes back to a no-op.
              onUpload: ref.watch(documentUploadRequestProvider),
              onAppeal: () {
                final document = state.documentFor(type);
                if (document != null) {
                  interactor.appealDocument(document);
                }
              },
            ),
            SizedBox(height: hoppin.spacing.sm),
          ],

          SizedBox(height: hoppin.spacing.md),

          // The #83 rung. UNCONDITIONAL — the enum is not sometimes-unpublished,
          // it is unpublished on every request, forever, until the backend
          // publishes it. A rung hung off a null branch that never fires is a
          // disclosure that discloses nothing.
          DocumentVocabularyUnavailable(
            onContactSupport: () => interactor.contactSupport(
              'Question about my document statuses',
            ),
          ),

          if (state.supportPhase == SupportPhase.sent) ...[
            SizedBox(height: hoppin.spacing.sm),
            const HopBanner.success(
              message: 'We have opened a support ticket. Someone will reply to '
                  'you about this.',
            ),
          ],
          if (state.supportPhase == SupportPhase.failed) ...[
            SizedBox(height: hoppin.spacing.sm),
            // 🔴 A support request we silently dropped is a forward exit that
            // goes nowhere. Say so.
            HopBanner.error(
              message: state.error ??
                  'We could not open a support ticket. Please try again.',
            ),
          ],
        ],
      ),
    );
  }
}
