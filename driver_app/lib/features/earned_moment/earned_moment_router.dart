import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import 'earned_moment_builder.dart';
import 'earned_moment_state.dart';

/// ALL earned-moment navigation lives in this file (riblet rule, DOCS/05):
/// the attach entry point below and the done → collapse-and-go-home block
/// inside [EarnedMomentRouterListener]. The sheet NEVER self-inserts —
/// only the trip runner's router calls [attachEarnedMoment].
Future<void> attachEarnedMoment(
  BuildContext context, {
  required String rideId,
}) {
  // HopSheet chrome per convention: scrim barrier, transparent Material,
  // drawn ambient veil. Not dismissible — the timeline (or a tap-skip)
  // owns the collapse, so the demo beat can never be half-swiped away.
  return HopSheet.show<void>(
    context,
    isDismissible: false,
    builder: (_) => EarnedMomentRiblet(rideId: rideId),
  );
}

/// The riblet's navigation listener, wrapped around the view by
/// [EarnedMomentRiblet]: on the timeline reaching done, pop the sheet and
/// land back on the dashboard — where the tile absorbs the same number
/// (03-03 choreography). One-shot, prev-compare guarded.
class EarnedMomentRouterListener extends ConsumerWidget {
  const EarnedMomentRouterListener({
    required this.rideId,
    required this.child,
    super.key,
  });

  /// The family key this listener watches.
  final String rideId;

  /// The wrapped view subtree.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(earnedMomentInteractorProvider(rideId), (previous, next) {
      if (next.phase != EarnedPhase.done ||
          previous?.phase == EarnedPhase.done) {
        return;
      }
      Navigator.of(context).pop();
      context.go('/');
    });
    return child;
  }
}
