import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

/// The driver's one-tap escape from a trip that has gone wrong — a rider who
/// is not coming, a wrong address, a car that will not start.
///
/// 🔴 THIS SHEET USED TO SAY THE DRIVER COULD NOT CANCEL. That was true when it
/// was written: `PATCH /rides/:id/cancel` needs a `reason_id` and no endpoint
/// listed the seeded uuids, so every driver cancel 400'd and the only bound
/// door was a support ticket — a human workflow where Scope Lock §3.2 mandates
/// automation.
///
/// `GET /cancellation-reasons` now ships and serves driver-actor rows
/// (`driver_declined`, `offer_timeout`), and a driver cancel of an accepted
/// ride returns 200. So the disclosure is retired and the real control takes
/// its place: Scope Lock §4.2 — "Drivers may cancel trips after acceptance or
/// arrival according to platform rules."
///
/// Cancelling is destructive and may carry a penalty, so it is the LAST action
/// in the list and behind a confirm — the softer doors (message the rider,
/// support) come first.
class StuckExitSheet extends ConsumerStatefulWidget {
  /// Creates the driver's stuck-exit sheet for [rideId].
  const StuckExitSheet({required this.rideId, super.key});

  /// The live ride the driver is stuck on.
  final String rideId;

  @override
  ConsumerState<StuckExitSheet> createState() => _StuckExitSheetState();
}

class _StuckExitSheetState extends ConsumerState<StuckExitSheet> {
  bool _busy = false;
  bool _cancelling = false;
  String? _error;
  String? _confirmation;

  Future<void> _contactSupport() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = await ref.read(supportRepositoryProvider).createTicket(
            subject: 'Stuck on trip ${widget.rideId}',
            category: 'app',
            body: 'Driver reported being stuck on ride ${widget.rideId}.',
          );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _confirmation = 'Support ticket opened (#$id). A person will pick it '
            "up — the ride itself hasn't changed.";
      });
    } on Exception catch (e) {
      // 🔴 A failed escape must not close the only door: the sheet STAYS open.
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = friendlyErrorMessage(e);
      });
    }
  }

  /// Cancel the ride for real. Picks a driver-actor reason from the live
  /// `GET /cancellation-reasons`, preferring a no-penalty one, and sends
  /// `actor_type: "driver"`.
  Future<void> _cancelRide() async {
    final driverId = ref.read(authServiceProvider).userId;
    if (driverId == null) {
      setState(() => _error = 'You need to be signed in to cancel.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this trip?'),
        content: const Text(
          'The rider is told immediately and the job is released back to '
          'dispatch. Frequent cancellations can affect the offers you get.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep the trip'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: context.hoppin.colors.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancel trip'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _cancelling = true;
      _error = null;
    });
    try {
      final repo = ref.read(driverRepositoryProvider);
      final reasons = await repo.driverCancellationReasons();
      final reason = reasons.isEmpty
          ? null
          : reasons.firstWhere(
              (r) => !r.appliesPenaltyFee,
              orElse: () => reasons.first,
            );
      await repo.cancelRide(
        rideId: widget.rideId,
        reasonId: reason?.id,
        driverId: driverId,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      GoRouter.maybeOf(context)?.go('/');
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _cancelling = false;
        _error = friendlyErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;

    return HopSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Stuck on this trip?',
            style: hoppin.type.title.copyWith(color: hoppin.colors.textHi),
          ),
          SizedBox(height: hoppin.spacing.xs),
          Text(
            'Try reaching the rider first — if they are not coming, you can '
            'cancel and get back on the road.',
            style:
                hoppin.type.bodySmall.copyWith(color: hoppin.colors.textMid),
          ),
          SizedBox(height: hoppin.spacing.md),

          if (_confirmation != null) ...[
            HopBanner.notice(message: _confirmation!),
            SizedBox(height: hoppin.spacing.md),
          ],
          if (_error != null) ...[
            HopBanner.error(message: _error!),
            SizedBox(height: hoppin.spacing.md),
          ],

          // 1. Message the rider — chat is BOUND.
          HopButton.secondary(
            label: 'Message the rider',
            icon: Icons.chat_bubble_outline,
            onPressed: () =>
                GoRouter.maybeOf(context)?.push('/trip/${widget.rideId}/chat'),
          ),
          SizedBox(height: hoppin.spacing.sm),

          // 2. Call the rider — inert on #45, and it says so on arrival.
          HopButton.secondary(
            label: 'Call the rider',
            icon: Icons.phone_outlined,
            onPressed: () =>
                GoRouter.maybeOf(context)?.push('/trip/${widget.rideId}/call'),
          ),
          SizedBox(height: hoppin.spacing.sm),

          // 3. Support — still bound, still honest about what it does.
          HopButton.secondary(
            label: 'Contact support',
            icon: Icons.support_agent_outlined,
            busy: _busy,
            onPressed: _busy ? null : _contactSupport,
          ),
          SizedBox(height: hoppin.spacing.md),

          // 4. The real cancel. Destructive, so it is last and confirm-guarded.
          HopButton.primary(
            label: _cancelling ? 'Cancelling…' : 'Cancel this trip',
            icon: Icons.close,
            busy: _cancelling,
            onPressed: _cancelling ? null : _cancelRide,
          ),
          SizedBox(height: hoppin.spacing.sm),

          HopButton.ghost(
            label: 'Close',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }
}

/// Opens the [StuckExitSheet] for [rideId] — the one-tap, driver-initiated
/// escape. Deliberately opened BY the driver (SF-04 bans only auto-present).
Future<void> showStuckExitSheet(BuildContext context, {required String rideId}) {
  final colors = context.hoppin.colors;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    elevation: 0,
    backgroundColor: Colors.transparent,
    barrierColor: colors.scrim,
    builder: (_) => StuckExitSheet(rideId: rideId),
  );
}
