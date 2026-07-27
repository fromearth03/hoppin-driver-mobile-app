import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import '../motion/motion_builder.dart';
import '../motion/widgets/typing_locked_in_motion.dart';
import 'rider_rating_builder.dart';

/// 🔴 THE DRIVER RATES THE RIDER — MOTION-GATED, SKIPPABLE, NEVER A TOLL GATE.
///
/// The submit logic lives in [RiderRatingInteractor]; this file is the sheet
/// (a dumb view over it), the presentation function, and the motion gate that
/// decides WHEN it may appear. `POST /rides/:id/rating` is `[either]`, has been
/// BOUND since the API client was written, and had ZERO driver UI — the rider
/// has been rating the driver all along.

/// 🔴 THE GATE. Presents the rating sheet EXACTLY ONCE, and ONLY when the
/// vehicle is stopped.
///
/// If the driver swiped complete while rolling away, the sheet is HELD — never
/// destroyed — and presents at the next idle moment (`!inMotion`). If they
/// never stop, it is never shown, and the trip still completes and still exits.
/// 🔴 SF-04: nothing auto-presents over a moving windscreen; a five-star picker
/// plus an optional comment is sustained attention, which is exactly the
/// due-care hazard the interaction budget exists to remove.
///
/// It is mounted on the completed-trip flow by [attachRiderRating] — which the
/// trip runner's router calls after the earned-moment sheet collapses (see
/// `features/trip/trip_runner_router.dart`). A direct call site (a manual "rate
/// this rider" button on a stationary summary) is also legitimate.
class RiderRatingGate extends ConsumerStatefulWidget {
  const RiderRatingGate({
    required this.rideId,
    required this.active,
    this.onDone,
    super.key,
  });

  /// The completed ride to rate — the interactor's family key.
  final String rideId;

  /// True once the trip is completed. The gate does nothing until this is true.
  final bool active;

  /// Fired once the sheet has been presented AND closed (submit or skip), so a
  /// host overlay entry can tear itself down. Null when the gate lives in a
  /// normal subtree that disposes with its parent.
  final VoidCallback? onDone;

  @override
  ConsumerState<RiderRatingGate> createState() => _RiderRatingGateState();
}

class _RiderRatingGateState extends ConsumerState<RiderRatingGate> {
  /// 🔴 Once per ride. A driver who has already seen (or skipped) the sheet is
  /// never re-prompted — the rating is offered, never nagged.
  bool _shown = false;

  @override
  Widget build(BuildContext context) {
    // The gate READS the motion instrument; it never computes it. One truth.
    ref.listen(motionInteractorProvider, (_, next) {
      _maybePresent(inMotion: next.inMotion);
    });
    // Also evaluate on the first frame — the driver may already be stopped at
    // the dropoff when the completed surface mounts.
    final inMotion = ref.watch(motionInteractorProvider).inMotion;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybePresent(inMotion: inMotion);
    });
    // The gate is invisible — it only decides when to present the sheet.
    return const SizedBox.shrink();
  }

  Future<void> _maybePresent({required bool inMotion}) async {
    if (!mounted) return;
    if (!widget.active || _shown || inMotion) return;
    _shown = true;
    // The sheet is skippable and never gates anything. Await its close only so
    // a host overlay can be torn down after.
    await showRiderRatingSheet(context, rideId: widget.rideId);
    widget.onDone?.call();
  }
}

/// 🔴 Mounts the [RiderRatingGate] on the completed-trip flow, over the ROOT
/// overlay, so it survives the earned-moment sheet's collapse-and-go-home.
///
/// The trip runner's router calls this AFTER the earned-moment sheet closes:
/// the runner subtree is already tearing down as the route changes to '/', so
/// the gate cannot live inside it. It rides an [OverlayEntry] on the root
/// overlay instead — invisible, motion-gated, self-removing once the sheet has
/// been presented and closed (or immediately, if the overlay goes away first).
///
/// It NEVER blocks the exit: by the time this runs the driver is already on the
/// dashboard. The sheet is offered on top; skipping it changes nothing.
void attachRiderRating(OverlayState overlay, {required String rideId}) {
  late final OverlayEntry entry;
  var removed = false;
  void remove() {
    if (removed || !entry.mounted) return;
    removed = true;
    entry.remove();
  }

  entry = OverlayEntry(
    builder: (_) => RiderRatingGate(
      rideId: rideId,
      active: true,
      onDone: remove,
    ),
  );
  overlay.insert(entry);
}

/// Presents the rider-rating sheet. 🔴 Callable only when the vehicle is
/// stopped — the [RiderRatingGate] is the guard; a direct call site (a manual
/// "rate this rider" button on a stationary summary) is also legitimate.
Future<void> showRiderRatingSheet(
  BuildContext context, {
  required String rideId,
}) {
  final colors = context.hoppin.colors;
  return showModalBottomSheet<void>(
    context: context,
    // Keyboard-safe for the comment field; HopSheet draws its own surface.
    isScrollControlled: true,
    useSafeArea: true,
    elevation: 0,
    backgroundColor: Colors.transparent,
    barrierColor: colors.scrim,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
      ),
      child: HopSheet(child: RiderRatingSheetView(rideId: rideId)),
    ),
  );
}

/// The sheet view: a large, glanceable star picker and an OPTIONAL comment box
/// that is text entry — and therefore wrapped in [TypingLockedInMotion].
class RiderRatingSheetView extends ConsumerStatefulWidget {
  const RiderRatingSheetView({required this.rideId, super.key});

  /// The completed ride being rated.
  final String rideId;

  @override
  ConsumerState<RiderRatingSheetView> createState() =>
      _RiderRatingSheetViewState();
}

class _RiderRatingSheetViewState extends ConsumerState<RiderRatingSheetView> {
  final _commentCtrl = TextEditingController();

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref
        .read(riderRatingInteractorProvider(widget.rideId).notifier)
        .submit(comments: _commentCtrl.text);
    if (!mounted || !ok) return;
    navigator.pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('Thanks — rating sent.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rating = ref.watch(riderRatingInteractorProvider(widget.rideId));
    final notifier =
        ref.read(riderRatingInteractorProvider(widget.rideId).notifier);
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    final type = hoppin.type;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'How was your rider?',
          textAlign: TextAlign.center,
          style: type.title.copyWith(color: colors.textHi),
        ),
        SizedBox(height: hoppin.spacing.md),
        // Large, one-tap, glance-legible star targets.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 1; i <= 5; i++)
              IconButton(
                key: Key('rider-rating-star-$i'),
                onPressed: rating.busy ? null : () => notifier.setScore(i),
                iconSize: 40,
                constraints:
                    const BoxConstraints(minWidth: 52, minHeight: 52),
                tooltip: '$i star${i > 1 ? 's' : ''}',
                icon: Icon(
                  i <= rating.score ? Icons.star : Icons.star_border,
                  color: colors.accent,
                ),
              ),
          ],
        ),
        SizedBox(height: hoppin.spacing.sm),
        // 🔴 THE OPTIONAL COMMENT IS TEXT ENTRY → WRAP IT. Belt-and-braces: the
        // gate already means the sheet is never up while moving, but a future
        // refactor that surfaces the sheet elsewhere must not smuggle a
        // keyboard onto a moving screen.
        TypingLockedInMotion(
          child: TextField(
            controller: _commentCtrl,
            enabled: !rating.busy,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Add a note (optional)',
              alignLabelWithHint: true,
            ),
          ),
        ),
        if (rating.error != null) ...[
          SizedBox(height: hoppin.spacing.sm),
          Text(
            rating.error!,
            style: type.bodySmall.copyWith(color: colors.error),
          ),
        ],
        SizedBox(height: hoppin.spacing.md),
        HopButton.primary(
          label: 'Submit rating',
          onPressed: rating.busy ? null : _submit,
          busy: rating.busy,
        ),
        SizedBox(height: hoppin.spacing.xs),
        // 🔴 SKIPPABLE = DISMISS WITHOUT PENALTY. This is the exit, and it is
        // ALWAYS live — even after a failed submit. The rating never gates it.
        HopButton.ghost(
          label: 'Skip',
          onPressed: rating.busy ? null : () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
