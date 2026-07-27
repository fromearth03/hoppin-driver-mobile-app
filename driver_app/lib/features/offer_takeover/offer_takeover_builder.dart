import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

import 'offer_takeover_interactor.dart';
import 'offer_takeover_router.dart';
import 'offer_takeover_state.dart';
import 'offer_takeover_view.dart';

/// Assembly point of the offer takeover riblet (DOCS/05): declares the
/// interactor's provider so the view and the router both import the
/// builder, never each other. Family-keyed by the offer itself (freezed
/// value equality), autoDispose — a takeover dies with its route.
final offerTakeoverInteractorProvider = NotifierProvider.autoDispose
    .family<OfferTakeoverInteractor, OfferTakeoverState, RideOffer>(
  OfferTakeoverInteractor.new,
);

/// The riblet's public entry widget — what the '/offer' route builds: the
/// router's navigation listener wrapped around the takeover view.
class OfferTakeoverRiblet extends ConsumerWidget {
  const OfferTakeoverRiblet({required this.offer, super.key});

  /// The offer this takeover instance presents.
  final RideOffer offer;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      OfferTakeoverRouterListener(
        offer: offer,
        child: OfferTakeoverView(offer: offer),
      );
}
