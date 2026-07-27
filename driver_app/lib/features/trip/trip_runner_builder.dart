import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'trip_runner_interactor.dart';
import 'trip_runner_router.dart';
import 'trip_runner_state.dart';
import 'trip_runner_view.dart';

/// Assembly point of the trip runner riblet (DOCS/05): declares the
/// interactor's provider so the view and the router both import the
/// builder, never each other. Family-keyed by rideId, autoDispose — a
/// runner dies with its route.
final tripRunnerInteractorProvider = NotifierProvider.autoDispose
    .family<TripRunnerInteractor, TripRunnerState, String>(
  TripRunnerInteractor.new,
);

/// The riblet's public entry widget — what the /trip/:id route builds:
/// the router's navigation listener wrapped around the morphing card view.
class TripRunnerRiblet extends ConsumerWidget {
  const TripRunnerRiblet({required this.rideId, super.key});

  /// The ride this runner instance is bound to.
  final String rideId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => TripRunnerRouterListener(
        rideId: rideId,
        child: TripRunnerView(rideId: rideId),
      );
}
