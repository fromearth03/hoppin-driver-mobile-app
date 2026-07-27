import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The ONE way anything in this app may hand a URL to the OS.
///
/// 🔴 IT EXISTS TO MAKE "THIS APP NEVER DIALS" ASSERTABLE.
///
/// A source grep can be defeated: by string concatenation, by a plugin that
/// dials without a URI, by a constant living in a shared package. This cannot.
/// Nothing reaches the OS except through here, and in test a recording fake
/// stands in its place, gets driven across every control on the call surface,
/// and is required to record ZERO launches.
///
/// With no masked-call bridge (#45), the only number the DRIVER app could ever
/// reach is the RIDER'S PERSONAL MOBILE — which this app must never even
/// possess. That is not a UX concern. It is safeguarding, and it is a locked
/// prohibition.
///
/// The dial scheme is deliberately never spelled literally in this file: the
/// phase gate greps `lib/` for it (through `stripDartComments`), and a docstring
/// explaining the prohibition must not be what trips the gate — three lanes in
/// this project have already been bitten by exactly that.
abstract interface class UrlLauncher {
  /// Opens [uri] in the platform handler. Answers whether it was handled.
  ///
  /// Implementations MUST NOT be given a telephone URI carrying a rider's
  /// personal number — no masked proxy exists to produce a safe one (#45).
  Future<bool> launch(Uri uri);
}

/// The current live gateway: it launches nothing.
///
/// Not a placeholder to be filled in casually — it is the honest live shape.
/// The call surface has NO URL to launch (voice is on disclosed seam #45), so a
/// no-op that answers `false` tells the truth. When the OT-16 external-nav
/// hand-off (15-03's business, not this lane's) needs a real launcher, a
/// concrete `url_launcher`-backed implementation slots in behind this interface
/// — and it will be the ONLY file in `lib/` permitted to import the plugin, the
/// same isolation contract `maplibre_gl` carries.
class NoopUrlLauncher implements UrlLauncher {
  /// Creates the no-op live gateway.
  const NoopUrlLauncher();

  @override
  Future<bool> launch(Uri uri) async => false;
}

/// Exposes the active [UrlLauncher]. Defaults to [NoopUrlLauncher] — the honest
/// live target. Tests override it with a recording fake so that "the app never
/// dials" is asserted rather than assumed.
final urlLauncherProvider = Provider<UrlLauncher>(
  (ref) => const NoopUrlLauncher(),
);
