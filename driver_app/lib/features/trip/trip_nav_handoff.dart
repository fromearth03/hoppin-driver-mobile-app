import 'package:flutter_riverpod/flutter_riverpod.dart';

/// External turn-by-turn nav hand-off (OT-16) — through the ONE gateway.
///
/// External nav always launches through [urlLauncherProvider]; NEVER a raw
/// launch. The recorder in tests only sees what goes through the gateway, and a
/// raw launch is a hole in the guarantee.
///
/// On ANDROID this hand-off is SAFE (D1/A-03): the foreground service keeps the
/// heartbeat alive while the driver is in Google Maps. On web it was the
/// cruellest failure mode in the product — the tab backgrounds, location dies,
/// presence lapses, and the driver is dropped from dispatch while literally
/// driving to the pickup. D1 deleted the web target. No scary warning is
/// needed. Do not add one.
///
/// LANE NOTE (15-03): 15-02 owns `features/comms/**` and its own
/// `urlLauncherProvider`; that lane has not landed in this tree. Rather than
/// reach across the lane boundary (or ship a raw launch), this file carries a
/// LOCAL gateway of the same shape and the same honest live default. When
/// 15-02's gateway lands, 15-05 can converge the two — the call sites here move
/// unchanged.
abstract interface class UrlLauncher {
  /// Opens [uri] in the platform handler; answers whether it was handled.
  Future<bool> launch(Uri uri);
}

/// The current live gateway: it launches nothing.
///
/// `url_launcher` is not in the driver manifest, and only ONE file in `lib/`
/// may ever import the plugin (the same isolation contract `maplibre_gl` and
/// `firebase_` carry). Until that concrete launcher slots in behind this
/// interface, the honest live shape is a no-op that answers `false` — never a
/// raw launch pointed at a URL nobody recorded.
class NoopUrlLauncher implements UrlLauncher {
  /// Creates the no-op live gateway.
  const NoopUrlLauncher();

  @override
  Future<bool> launch(Uri uri) async => false;
}

/// Exposes the active [UrlLauncher]. Defaults to [NoopUrlLauncher]. Tests
/// override it with a recording fake so that the nav hand-off is asserted to go
/// through the gateway rather than a raw launch.
final urlLauncherProvider = Provider<UrlLauncher>(
  (ref) => const NoopUrlLauncher(),
);

/// Builds the cross-platform Google Maps directions URL for [destLat],[destLng].
///
/// The universal `https://www.google.com/maps/dir/?api=1&destination=…` form
/// hands off to the Google Maps app when installed and the web map otherwise —
/// one URL, every platform, no scheme sniffing.
Uri buildNavHandoffUrl({required double destLat, required double destLng}) {
  return Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': '$destLat,$destLng',
    'travelmode': 'driving',
  });
}

/// Hands the driver off to external turn-by-turn nav for the pickup/dropoff at
/// [destLat],[destLng] — through the gateway, never a raw launch.
Future<bool> launchNavHandoff(
  Ref ref, {
  required double destLat,
  required double destLng,
}) {
  final url = buildNavHandoffUrl(destLat: destLat, destLng: destLng);
  return ref.read(urlLauncherProvider).launch(url);
}

/// The UI's door onto [launchNavHandoff]: a widget holds a `WidgetRef`, not the
/// `Ref` the hand-off takes, so the Navigate control reads THIS provider and
/// calls the returned function. It routes through `launchNavHandoff` — the same
/// single gateway path — so there is exactly one launch site, still recorded.
final navHandoffProvider =
    Provider<Future<bool> Function({required double destLat, required double destLng})>(
  (ref) => ({required double destLat, required double destLng}) =>
      launchNavHandoff(ref, destLat: destLat, destLng: destLng),
);
