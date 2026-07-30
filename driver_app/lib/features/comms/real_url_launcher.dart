import 'package:url_launcher/url_launcher.dart';

import '../trip/trip_nav_handoff.dart' as nav;
import 'url_launcher_gateway.dart' as comms;

/// The ONE concrete [UrlLauncher] — the only file in `lib/` that imports
/// `url_launcher` (the same isolation contract `geolocator` / `firebase_` carry,
/// enforced by the phase-gate grep). It satisfies BOTH lane interfaces
/// (`features/comms` and `features/trip`), which are structurally identical, so a
/// single class wires every launch site — Stripe payout onboarding, force-update,
/// and the in-trip Navigate hand-off — to the real OS handler, opening in an
/// external application (the browser, or the Maps app).
///
/// Safeguarding (#45) stays enforced even with a real launcher: telephony schemes
/// are refused outright, so "the driver app never dials" remains structurally
/// true — the launcher itself cannot place a call.
class RealUrlLauncher implements comms.UrlLauncher, nav.UrlLauncher {
  const RealUrlLauncher();

  @override
  Future<bool> launch(Uri uri) {
    if (uri.scheme == 'tel' || uri.scheme == 'sms' || uri.scheme == 'callto') {
      return Future<bool>.value(false);
    }
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
