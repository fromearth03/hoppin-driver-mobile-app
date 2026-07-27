import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'rider_rating_interactor.dart';
import 'rider_rating_state.dart';

/// Assembly point of the rider-rating riblet-lite (DOCS/05): declares the
/// interactor's provider so the sheet and the gate both import the builder,
/// never each other. Family-keyed by the ride id, auto-disposed with the sheet.
final riderRatingInteractorProvider = NotifierProvider.autoDispose
    .family<RiderRatingInteractor, RiderRatingState, String>(
  RiderRatingInteractor.new,
);
