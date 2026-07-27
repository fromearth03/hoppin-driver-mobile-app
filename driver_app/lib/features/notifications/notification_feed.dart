import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'driver_fcm_gateway.dart';

/// One notification the driver's client actually SAW arrive.
///
/// Deliberately NOT called `Notification` (that name is taken by Flutter) and
/// deliberately not persisted — see [driverNotificationFeedProvider].
@immutable
class DriverAppNotification {
  /// Creates a session notification.
  const DriverAppNotification({
    required this.id,
    required this.title,
    required this.receivedAt,
    this.body,
    this.read = false,
    this.rideId,
  });

  /// Builds one from a push. The id is LOCAL — the backend issues none, because
  /// there is no notification record endpoint (#68).
  factory DriverAppNotification.fromPush(
    DriverPushMessage m, {
    required String id,
  }) =>
      DriverAppNotification(
        id: id,
        title: m.title ?? 'Hoppin',
        body: m.body,
        receivedAt: m.sentAt ?? DateTime.now(),
        rideId: m.rideId,
      );

  /// Session-local identity.
  final String id;

  /// The headline shown on the card.
  final String title;

  /// The supporting line.
  final String? body;

  /// When this client saw it.
  final DateTime receivedAt;

  /// Local read state. There is no server read-state to sync with (#68).
  final bool read;

  /// The trip this is about, when it is about one.
  final String? rideId;

  /// Returns a copy with [read] flipped.
  DriverAppNotification copyWith({bool? read}) => DriverAppNotification(
        id: id,
        title: title,
        body: body,
        receivedAt: receivedAt,
        read: read ?? this.read,
        rideId: rideId,
      );
}

/// The driver's notification feed.
///
/// SESSION-LOCAL BY NECESSITY. There is no `GET /me/notifications` (#68), so the
/// only notifications this client can HONESTLY show are the ones it saw arrive.
/// It is fed by:
///
///   (a) `DriverFcmGateway.onMessage()` — real pushes. **Empty today**: the
///       backend has no FCM credentials (#15/#16), so it cannot send.
///   (b) local driver-lifecycle events (an offer arriving, a document status
///       change surfacing on a poll) — which is what makes the centre non-empty
///       at all today.
///
/// 🔴 NOT PERSISTED. A relaunch empties it, and that is CORRECT — a local store
/// pretending to be server history is exactly the fake-as-live the no-holes rule
/// forbids, and it would diverge permanently from the server the day the history
/// endpoint ships.
final driverNotificationFeedProvider =
    NotifierProvider<DriverNotificationFeed, List<DriverAppNotification>>(
  DriverNotificationFeed.new,
);

/// The unread count that a bell badge would read from.
///
/// 🔴 A **REAL** count over the real feed. Over the live no-op gateway it is
/// `0`, and `HopTopBar` hides the badge at 0. **There is no constant anywhere.**
/// A hardcoded `notificationCount: 2` shipped a permanent fake unread badge on
/// every rider screen once, and Wave 0 deleted it — a badge over a handler that
/// cannot fire is a promise the platform cannot keep.
final unreadDriverNotificationCountProvider = Provider<int>((ref) {
  return ref.watch(driverNotificationFeedProvider).where((n) => !n.read).length;
});

/// The session store behind [driverNotificationFeedProvider].
class DriverNotificationFeed extends Notifier<List<DriverAppNotification>> {
  /// The live feed — starts empty and listens to the gateway.
  DriverNotificationFeed() : _seed = null;

  /// A pre-seeded feed. TEST/DEMO composition only — it deliberately does NOT
  /// subscribe to the gateway, so nothing arrives behind a test's back.
  DriverNotificationFeed.seeded(List<DriverAppNotification> seed)
      : _seed = seed;

  final List<DriverAppNotification>? _seed;
  int _counter = 0;

  @override
  List<DriverAppNotification> build() {
    final seed = _seed;
    if (seed != null) return List<DriverAppNotification>.unmodifiable(seed);

    // Foreground pushes land here. Empty on the live no-op default (today),
    // which is why the centre's cold start renders the #68 rung rather than a
    // list — and why the unread count is an honest 0.
    final sub = ref.watch(driverFcmGatewayProvider).onMessage().listen(add);
    ref.onDispose(sub.cancel);

    return const <DriverAppNotification>[];
  }

  /// Records a push that arrived. Newest first.
  void add(DriverPushMessage m) {
    final n = DriverAppNotification.fromPush(m, id: 'local-${_counter++}');
    state = <DriverAppNotification>[n, ...state];
  }

  /// Records a local driver-lifecycle event — an offer arriving, a document
  /// status change seen on a poll. This is what makes the centre non-empty
  /// today, while delivery is gated.
  void addLocal({
    required String title,
    String? body,
    String? rideId,
  }) {
    state = <DriverAppNotification>[
      DriverAppNotification(
        id: 'local-${_counter++}',
        title: title,
        body: body,
        receivedAt: DateTime.now(),
        rideId: rideId,
      ),
      ...state,
    ];
  }

  /// Marks every session notification read. Purely LOCAL read-state — it costs
  /// nothing and lies about nothing, so unlike "delete all" it stays enabled.
  void markAllRead() {
    state = <DriverAppNotification>[
      for (final n in state) n.read ? n : n.copyWith(read: true),
    ];
  }

  /// Removes one session notification by [id]. Session-local only — there is no
  /// server record to delete (#68), so this is the one per-item action that is
  /// honest to enable.
  void dismiss(String id) {
    state = <DriverAppNotification>[
      for (final n in state)
        if (n.id != id) n,
    ];
  }
}
