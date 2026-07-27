import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'earned_moment_interactor.dart';
import 'earned_moment_router.dart';
import 'earned_moment_state.dart';
import 'earned_moment_view.dart';

/// Assembly point of the earned-moment riblet (DOCS/05): declares the
/// interactor's provider so the view and the router both import the
/// builder, never each other. Family-keyed by rideId, autoDispose —
/// the moment dies with its sheet.
///
/// KEYED BY THE RIDE, NOT BY THE PAYOUT. The payout is decoration and may be
/// null forever; a family key that is null-on-live is a sheet that cannot open
/// on live, and the sheet is the completed trip's exit.
final earnedMomentInteractorProvider = NotifierProvider.autoDispose
    .family<EarnedMomentInteractor, EarnedMomentState, String>(
  EarnedMomentInteractor.new,
);

/// The riblet's public entry widget — what [attachEarnedMoment] presents:
/// the router's collapse listener wrapped around the sheet view.
class EarnedMomentRiblet extends ConsumerWidget {
  const EarnedMomentRiblet({required this.rideId, super.key});

  /// The completed ride this moment closes out.
  final String rideId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => EarnedMomentRouterListener(
        rideId: rideId,
        child: EarnedMomentView(rideId: rideId),
      );
}
