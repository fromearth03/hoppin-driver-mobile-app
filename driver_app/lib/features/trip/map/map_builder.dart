import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'map_interactor.dart';
import 'map_state.dart';

/// Assembly point of the driver map riblet (DOCS/05): an EMBEDDED child of
/// the trip runner — router-free by design (the map never navigates; the
/// runner's existing routers own every transition). The view file's
/// `DriverTripMap` is the riblet's entry widget; the runner view mounts it
/// full-bleed behind the morphing card.
///
/// Family-keyed by rideId, autoDispose — the map dies with its runner.
final tripMapInteractorProvider = NotifierProvider.autoDispose
    .family<MapInteractor, MapState, String>(
  MapInteractor.new,
);

/// Test seam: widget tests override this with a non-null sentinel so HopMap
/// suppresses the MapLibreMap platform view (no tile HTTP under flutter_test).
/// Production leaves it null and HopMap renders the real map.
///
/// Deliberately `dynamic`/Object?: the seam must stay import-free of
/// maplibre_gl in driver app code (the HopMap isolation gate).
final mapTileProvider = Provider<dynamic>((_) => null);
