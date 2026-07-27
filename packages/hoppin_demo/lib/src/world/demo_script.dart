/// Seed-derived schedule for the world's virtual counterpart.
///
/// Every delay is a pure function of the world seed — two runs with the same
/// seed schedule every scripted beat at exactly the same instant, so
/// determinism (DEMO-04) holds by construction rather than by careful timing.
///
/// The rider composition auto-runs a virtual DRIVER (accepts the request,
/// drives over, arrives, starts, completes); the driver composition auto-runs
/// a virtual RIDER (a request lands shortly after going online, and a
/// declined offer is re-dispatched). Same state machine — different script.
class DemoScript {
  /// Derives every beat from [seed]. With the default seed 42:
  /// dispatch 3000ms + accept 1200ms = 4200ms match, offer arrival 5000ms,
  /// re-offer 4200ms, arrive-hold release 2500ms, trip start 4000ms,
  /// post-complete 3000ms.
  DemoScript.fromSeed(int seed)
      : dispatchDelayMs = 2400 + (seed % 5) * 300,
        virtualDriverAcceptMs = 1200,
        offerArrivalDelayMs = 4600 + (seed % 4) * 200,
        reofferDelayMs = 3800 + (seed % 4) * 200,
        virtualArriveHoldMs = 2200 + (seed % 4) * 150,
        virtualStartDelayMs = 3600 + (seed % 4) * 200;

  /// The dispatch "searching" beat before the virtual driver sees the
  /// request.
  final int dispatchDelayMs;

  /// The virtual driver's decision beat before accepting the dispatch.
  final int virtualDriverAcceptMs;

  /// Request-to-ride-row delay: the row appears in history already accepted.
  ///
  /// Spans 3600-4800ms across all seeds — always inside the locked 3-6s
  /// matching window, and always past at least one 3s poll tick of the
  /// booking controller's id-diff loop.
  int get matchDelayMs => dispatchDelayMs + virtualDriverAcceptMs;

  /// How long after goOnline the scripted incoming request lands (~5s).
  final int offerArrivalDelayMs;

  /// How long after a decline the same trip is re-offered with a fresh
  /// offer id (~4s).
  final int reofferDelayMs;

  /// Driver-to-pickup ETA in real seconds. Counts down from here and floors
  /// at the calm "Arriving now" hold.
  int get etaTotalSeconds => 120;

  /// Rider scenario only: the virtual driver taps Arrived this long after
  /// the ETA floors (~2.5s). The driver scenario holds forever — only the
  /// presenter's tap releases it.
  final int virtualArriveHoldMs;

  /// Rider scenario only: the virtual driver starts the trip this long
  /// after arriving (~4s).
  final int virtualStartDelayMs;

  /// The in-trip segment — inside the locked 60-90s window.
  int get inTripSeconds => 75;

  /// Breathing room on the completed screen before the world returns to
  /// idle, ready for the next booking.
  int get postCompleteMs => 3000;
}
